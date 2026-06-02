import Foundation
import SharedModels

/// Placeholder call manager — UI works end-to-end, but no real media is captured
/// or rendered. Used when the LiveKit SDK isn't linked, or when the backend
/// issued a `dev_*` token (no LiveKit env vars set).
@MainActor
public final class StubCallProvider: CallManagerProtocol {
    public private(set) var localAudioMuted: Bool = false
    public private(set) var localVideoMuted: Bool = true
    public private(set) var isScreenSharing: Bool = false
    public private(set) var remoteParticipants: [RemoteCallParticipant] = []
    public private(set) var connectionState: CallConnectionState = .idle
    public private(set) var activeSpeakerUserId: UUID? = nil

    private var observers: [UUID: () -> Void] = [:]

    public init() {}

    public func addStateObserver(_ handler: @escaping () -> Void) -> UUID {
        let id = UUID()
        observers[id] = handler
        return id
    }

    public func removeStateObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    public func connect(token: CallTokenDTO) async throws {
        connectionState = .connecting
        notify()
        try? await Task.sleep(nanoseconds: 300_000_000)
        connectionState = .connected
        notify()
    }

    public func disconnect() async {
        connectionState = .disconnected
        remoteParticipants = []
        activeSpeakerUserId = nil
        notify()
    }

    public func setAudioMuted(_ muted: Bool) async {
        localAudioMuted = muted
        notify()
    }

    public func setVideoMuted(_ muted: Bool) async {
        localVideoMuted = muted
        notify()
    }

    public func startScreenShare() async -> Bool {
        // System-wide screen share requires the Broadcast Upload Extension; in the
        // stub we just flip the flag so UI can reflect the intent.
        isScreenSharing = true
        notify()
        return true
    }

    public func stopScreenShare() async {
        isScreenSharing = false
        notify()
    }

    public func sendAdminEvent(_ event: CallAdminEventRequest) async -> Bool {
        // Data channels aren't wired in the stub; backend admin endpoint handles
        // the persisted state. Return true so callers consider it dispatched.
        true
    }

    public func setSubscribedQuality(_ tier: CallVideoQuality, for userId: UUID) async {
        // No-op in the stub.
    }

    // MARK: - Test helpers (exposed for SwiftUI previews / tests)

    public func injectRemoteParticipant(_ p: RemoteCallParticipant) {
        if !remoteParticipants.contains(where: { $0.id == p.id }) {
            remoteParticipants.append(p)
            notify()
        }
    }

    private func notify() {
        for handler in observers.values { handler() }
    }
}
