import Foundation
import SharedModels

/// Abstraction over the SFU client (LiveKit, Agora, or stub). The app speaks
/// `CallManagerProtocol`; sub-phase 4-B's media plane swap is a single
/// `CallManagerFactory.make(provider:)` change with no call-site churn.
@MainActor
public protocol CallManagerProtocol: AnyObject {
    /// Local participant state (mic / camera / screen-share).
    var localAudioMuted: Bool { get }
    var localVideoMuted: Bool { get }
    var isScreenSharing: Bool { get }

    /// Remote participants currently in the room.
    var remoteParticipants: [RemoteCallParticipant] { get }
    /// SFU connection state.
    var connectionState: CallConnectionState { get }
    /// Active speaker user id (server-derived if SDK supports; nil otherwise).
    var activeSpeakerUserId: UUID? { get }

    /// Subscribers receive every state change. Caller is responsible for retain cycles.
    func addStateObserver(_ handler: @escaping () -> Void) -> UUID
    func removeStateObserver(_ id: UUID)

    func connect(token: CallTokenDTO) async throws
    func disconnect() async

    func setAudioMuted(_ muted: Bool) async
    func setVideoMuted(_ muted: Bool) async

    /// Returns true if screen share started successfully.
    func startScreenShare() async -> Bool
    func stopScreenShare() async

    /// Send a data-channel admin message (host controls). Returns true if delivered.
    func sendAdminEvent(_ event: CallAdminEventRequest) async -> Bool

    /// Switch active media source quality tier for a remote participant (Simulcast).
    func setSubscribedQuality(_ tier: CallVideoQuality, for userId: UUID) async
}

public enum CallConnectionState: String, Sendable, Hashable {
    case idle, connecting, connected, reconnecting, disconnected, failed
}

public enum CallVideoQuality: String, Sendable, Hashable, CaseIterable {
    case low, medium, high
    /// Simulcast spec from the plan: 180p / 360p / 720p.
    public var label: String {
        switch self {
        case .low: return "180p"
        case .medium: return "360p"
        case .high: return "720p"
        }
    }
}

public struct RemoteCallParticipant: Identifiable, Hashable, Sendable {
    public let id: UUID                 // user id
    public let displayName: String
    public let isAudioMuted: Bool
    public let isVideoMuted: Bool
    public let isScreenSharing: Bool
    public let isSpeaking: Bool

    public init(
        id: UUID,
        displayName: String,
        isAudioMuted: Bool = false,
        isVideoMuted: Bool = false,
        isScreenSharing: Bool = false,
        isSpeaking: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.isAudioMuted = isAudioMuted
        self.isVideoMuted = isVideoMuted
        self.isScreenSharing = isScreenSharing
        self.isSpeaking = isSpeaking
    }
}

// MARK: - Factory

@MainActor
public enum CallManagerFactory {
    /// Picks the right provider based on the token DTO.
    /// - `internal` / dev tokens → `StubCallProvider` (UI works, no real media).
    /// - `livekit` real tokens → `LiveKitCallProvider` (only if the SDK is linked
    ///   in this build via the `LiveKit` Swift package).
    public static func make(for token: CallTokenDTO) -> CallManagerProtocol {
        if token.token.hasPrefix("dev_") {
            return StubCallProvider()
        }
        switch token.provider {
        case .livekit:
            #if canImport(LiveKit)
            return LiveKitCallProvider()
            #else
            return StubCallProvider()
            #endif
        case .agora, .internal:
            return StubCallProvider()
        }
    }
}
