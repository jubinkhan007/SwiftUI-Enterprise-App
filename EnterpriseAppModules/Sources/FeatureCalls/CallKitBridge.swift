import Foundation
import Domain
import SharedModels
#if os(iOS) && canImport(CallKit) && canImport(PushKit)
import CallKit
import PushKit
#endif

/// Bridges PushKit VoIP pushes → CallKit `CXProvider` so the device shows the
/// native incoming-call UI even when the app is suspended. Registration of
/// the VoIP device token is forwarded to the backend via `CallRepositoryProtocol`.
///
/// Setup required:
///   1. Enable "Background Modes" → "Voice over IP" and "Remote notifications".
///   2. Register a VoIP push services certificate in your Apple developer
///      account and configure your APNs HTTP/2 client server-side (NOT yet
///      wired in this codebase — backend only persists the device token).
///   3. Initialize the bridge in the AppDelegate / App.init:
///         `CallKitBridge.shared.start(repository:)`
///   4. On incoming VoIP push, the OS will deliver the payload to
///      `pushRegistry(_:didReceiveIncomingPushWith:for:)`. Use the
///      `callSessionId` in the payload to fetch the call and connect.
@MainActor
public final class CallKitBridge: NSObject {
    public static let shared = CallKitBridge()

    private var repository: CallRepositoryProtocol?
    public private(set) var lastVoIPToken: String?

    #if os(iOS) && canImport(CallKit) && canImport(PushKit)
    private let pushRegistry = PKPushRegistry(queue: .main)
    private let cxProvider: CXProvider = {
        let config = CXProviderConfiguration()
        config.supportedHandleTypes = [.generic]
        config.supportsVideo = true
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        return CXProvider(configuration: config)
    }()
    private let callController = CXCallController()
    #endif

    public func start(repository: CallRepositoryProtocol) {
        self.repository = repository
        #if os(iOS) && canImport(CallKit) && canImport(PushKit)
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
        cxProvider.setDelegate(self, queue: .main)
        #endif
    }

    /// Report an outgoing call so the OS knows to keep the audio session alive
    /// and to publish to other devices via CallKit Recents.
    public func reportOutgoing(callId: UUID, calleeDisplayName: String) {
        #if os(iOS) && canImport(CallKit) && canImport(PushKit)
        let handle = CXHandle(type: .generic, value: calleeDisplayName)
        let start = CXStartCallAction(call: callId, handle: handle)
        start.isVideo = true
        let transaction = CXTransaction(action: start)
        callController.request(transaction) { _ in }
        #endif
    }

    /// Show the native ringing UI for an incoming call.
    public func reportIncoming(callId: UUID, callerDisplayName: String, hasVideo: Bool, completion: @escaping @Sendable (Error?) -> Void) {
        #if os(iOS) && canImport(CallKit) && canImport(PushKit)
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerDisplayName)
        update.hasVideo = hasVideo
        update.supportsHolding = false
        update.supportsGrouping = false
        cxProvider.reportNewIncomingCall(with: callId, update: update, completion: completion)
        #else
        completion(nil)
        #endif
    }

    /// End a known call from the app side (user tapped hang-up in our UI).
    public func endCall(_ callId: UUID) {
        #if os(iOS) && canImport(CallKit) && canImport(PushKit)
        let end = CXEndCallAction(call: callId)
        let transaction = CXTransaction(action: end)
        callController.request(transaction) { _ in }
        #endif
    }
}

#if os(iOS) && canImport(CallKit) && canImport(PushKit)
extension CallKitBridge: PKPushRegistryDelegate {
    nonisolated public func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType
    ) {
        guard type == .voIP else { return }
        let tokenString = pushCredentials.token.map { String(format: "%02hhx", $0) }.joined()
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        #if DEBUG
        let env = "sandbox"
        #else
        let env = "production"
        #endif
        Task { @MainActor [weak self] in
            self?.lastVoIPToken = tokenString
            guard let repo = self?.repository else { return }
            let request = RegisterVoIPTokenRequest(deviceToken: tokenString, bundleId: bundleId, environment: env)
            _ = try? await repo.registerVoIPToken(request)
        }
    }

    nonisolated public func pushRegistry(
        _ registry: PKPushRegistry,
        didInvalidatePushTokenFor type: PKPushType
    ) {
        Task { @MainActor [weak self] in
            guard let token = self?.lastVoIPToken else { return }
            _ = try? await self?.repository?.deleteVoIPToken(token)
            self?.lastVoIPToken = nil
        }
    }

    nonisolated public func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        // Required for iOS 13+ — we MUST report a new incoming call via CallKit
        // before `completion()` is called or the process will be killed.
        let payloadDict = payload.dictionaryPayload
        let callIdStr = (payloadDict["callSessionId"] as? String) ?? ""
        let caller = (payloadDict["callerDisplayName"] as? String) ?? "Incoming call"
        let hasVideo = (payloadDict["hasVideo"] as? Bool) ?? true
        let callId = UUID(uuidString: callIdStr) ?? UUID()
        Task { @MainActor [weak self] in
            self?.reportIncoming(callId: callId, callerDisplayName: caller, hasVideo: hasVideo) { _ in
                completion()
            }
        }
    }
}

extension CallKitBridge: CXProviderDelegate {
    nonisolated public func providerDidReset(_ provider: CXProvider) {}

    nonisolated public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // The host app should observe this to bring up the InCallView for `action.callUUID`
        // and call `store.acceptIncoming()`. We mark fulfilled so iOS knows we handled it.
        action.fulfill()
    }

    nonisolated public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
    }

    nonisolated public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        action.fulfill()
    }
}
#endif
