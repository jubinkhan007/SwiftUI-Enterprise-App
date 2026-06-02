import Foundation
import SharedModels

#if canImport(LiveKit)
import LiveKit

/// Real LiveKit-backed call manager. Only compiled when the
/// `livekit-client-swift` SPM dependency is linked. See
/// `LIVEKIT_DEPLOYMENT.md` for setup instructions.
///
/// This file is intentionally a thin skeleton — the call-site contract (the
/// `CallManagerProtocol`) is the stable surface. Wire each capability through
/// when adopting the SDK:
///   1. Construct `Room()` in `init`.
///   2. In `connect(token:)` call `room.connect(url, token, options)`.
///   3. Bridge `RoomDelegate` callbacks into `remoteParticipants` / `notify()`.
///   4. Implement `setSubscribedQuality` via `track.set(preferredQuality:)`.
///   5. Wire screen share to the App-Group broadcast extension's video source.
@MainActor
public final class LiveKitCallProvider: CallManagerProtocol {
    public private(set) var localAudioMuted: Bool = false
    public private(set) var localVideoMuted: Bool = true
    public private(set) var isScreenSharing: Bool = false
    public private(set) var remoteParticipants: [RemoteCallParticipant] = []
    public private(set) var connectionState: CallConnectionState = .idle
    public private(set) var activeSpeakerUserId: UUID? = nil

    private var observers: [UUID: () -> Void] = [:]
    private var room: Room?

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
        guard let urlString = token.url, let url = URL(string: urlString) else {
            throw NSError(domain: "LiveKitCallProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing LiveKit URL on token."])
        }
        connectionState = .connecting
        notify()

        let room = Room()
        self.room = room
        // Concrete connect call differs per SDK version; refer to LiveKit Swift docs.
        try await room.connect(url: url.absoluteString, token: token.token)

        connectionState = .connected
        notify()
    }

    public func disconnect() async {
        await room?.disconnect()
        room = nil
        connectionState = .disconnected
        remoteParticipants = []
        notify()
    }

    public func setAudioMuted(_ muted: Bool) async {
        localAudioMuted = muted
        try? await room?.localParticipant.setMicrophone(enabled: !muted)
        notify()
    }

    public func setVideoMuted(_ muted: Bool) async {
        localVideoMuted = muted
        try? await room?.localParticipant.setCamera(enabled: !muted)
        notify()
    }

    public func startScreenShare() async -> Bool {
        do {
            try await room?.localParticipant.setScreenShare(enabled: true)
            isScreenSharing = true
            notify()
            return true
        } catch {
            return false
        }
    }

    public func stopScreenShare() async {
        try? await room?.localParticipant.setScreenShare(enabled: false)
        isScreenSharing = false
        notify()
    }

    public func sendAdminEvent(_ event: CallAdminEventRequest) async -> Bool {
        guard let data = try? JSONEncoder().encode(event) else { return false }
        do {
            try await room?.localParticipant.publish(data: data, options: .init(reliable: true))
            return true
        } catch {
            return false
        }
    }

    public func setSubscribedQuality(_ tier: CallVideoQuality, for userId: UUID) async {
        // Refer to LiveKit's RemoteTrackPublication.set(preferredQuality:) API.
        // Intentionally left as a no-op skeleton — wire when adopting SDK.
    }

    private func notify() {
        for handler in observers.values { handler() }
    }
}
#endif
