import Foundation
import Combine
import Domain
import AppNetwork
import SharedModels

/// One-per-active-call store. Owns:
/// - the server-side `CallSessionDTO`
/// - the SFU client via `CallManagerProtocol`
/// - the realtime subscription to `call:<id>`
/// - the 30s heartbeat used to detect drops
@MainActor
public final class CallSessionStore: ObservableObject {
    public static let heartbeatInterval: TimeInterval = 30

    @Published public private(set) var session: CallSessionDTO?
    @Published public private(set) var token: CallTokenDTO?
    @Published public private(set) var manager: (any CallManagerProtocol)?
    @Published public private(set) var managerState: ManagerStateSnapshot = .empty
    @Published public var lastError: Error?

    public struct ManagerStateSnapshot: Equatable, Sendable {
        public var connectionState: CallConnectionState
        public var localAudioMuted: Bool
        public var localVideoMuted: Bool
        public var isScreenSharing: Bool
        public var remoteParticipants: [RemoteCallParticipant]
        public var activeSpeakerUserId: UUID?

        public static let empty = ManagerStateSnapshot(
            connectionState: .idle,
            localAudioMuted: false,
            localVideoMuted: true,
            isScreenSharing: false,
            remoteParticipants: [],
            activeSpeakerUserId: nil
        )
    }

    public let callId: UUID
    private let currentUserId: UUID
    private let repository: CallRepositoryProtocol
    private let realtimeProvider: RealTimeProvider?

    private var managerObserverId: UUID?
    private var realtimeListenerId: UUID?
    private var heartbeatTask: Task<Void, Never>?

    public init(
        callId: UUID,
        currentUserId: UUID,
        repository: CallRepositoryProtocol,
        realtimeProvider: RealTimeProvider? = nil
    ) {
        self.callId = callId
        self.currentUserId = currentUserId
        self.repository = repository
        self.realtimeProvider = realtimeProvider
    }

    deinit {
        heartbeatTask?.cancel()
    }

    // MARK: - Loading

    public func refresh() async {
        do {
            let response = try await repository.getCall(id: callId)
            session = response.data
        } catch { lastError = error }
    }

    // MARK: - Lifecycle

    /// Accept the incoming call (gets a join ticket + connects via the manager).
    public func acceptIncoming() async {
        do {
            let response = try await repository.acceptCall(id: callId)
            await applyJoinTicket(response.data)
        } catch { lastError = error }
    }

    public func declineIncoming() async {
        do { _ = try await repository.declineCall(id: callId) }
        catch { lastError = error }
    }

    /// Apply a join ticket — already returned by `initiateCall` for outgoing calls.
    public func applyJoinTicket(_ ticket: CallJoinTicketDTO?) async {
        guard let ticket else { return }
        session = ticket.session
        token = ticket.token

        let manager = CallManagerFactory.make(for: ticket.token)
        self.manager = manager
        managerObserverId = manager.addStateObserver { [weak self] in
            Task { @MainActor [weak self] in self?.snapshotManager() }
        }
        do {
            try await manager.connect(token: ticket.token)
            snapshotManager()
            await subscribeRealtime()
            startHeartbeat()
        } catch {
            lastError = error
        }
    }

    public func endCall() async {
        stopHeartbeat()
        await unsubscribeRealtime()
        if let manager { await manager.disconnect() }
        do { _ = try await repository.endCall(id: callId) }
        catch { lastError = error }
        await refresh()
    }

    public func leaveCall() async {
        stopHeartbeat()
        await unsubscribeRealtime()
        if let manager { await manager.disconnect() }
        do { _ = try await repository.leaveCall(id: callId) }
        catch { lastError = error }
    }

    // MARK: - Local controls

    public func toggleAudioMute() async {
        guard let manager else { return }
        let next = !manager.localAudioMuted
        await manager.setAudioMuted(next)
        try? await pushMyState(audioMuted: next)
    }

    public func toggleVideoMute() async {
        guard let manager else { return }
        let next = !manager.localVideoMuted
        await manager.setVideoMuted(next)
        try? await pushMyState(videoMuted: next)
    }

    public func toggleScreenShare() async {
        guard let manager else { return }
        if manager.isScreenSharing {
            await manager.stopScreenShare()
            try? await pushMyState(screenSharing: false)
        } else {
            if await manager.startScreenShare() {
                try? await pushMyState(screenSharing: true)
            }
        }
    }

    /// Server-side state mirror so realtime peers see the change even before the
    /// SDK's signaling propagates.
    private func pushMyState(audioMuted: Bool? = nil, videoMuted: Bool? = nil, screenSharing: Bool? = nil) async throws {
        let request = UpdateParticipantStateRequest(
            isAudioMuted: audioMuted,
            isVideoMuted: videoMuted,
            isScreenSharing: screenSharing
        )
        _ = try await repository.updateMyState(callId: callId, request: request)
    }

    // MARK: - Admin

    public func adminAction(_ action: CallAdminAction, targetParticipantId: UUID? = nil) async {
        let request = CallAdminEventRequest(action: action, targetParticipantId: targetParticipantId)
        // Send via data channel (best-effort) + persist via REST (authoritative).
        if let manager { _ = await manager.sendAdminEvent(request) }
        do {
            let response = try await repository.adminAction(callId: callId, request: request)
            if let dto = response.data { session = dto }
        } catch { lastError = error }
    }

    // MARK: - Realtime

    public func subscribeRealtime() async {
        guard let realtimeProvider else { return }
        await realtimeProvider.subscribe(channels: ["call:\(callId.uuidString)"])
        realtimeListenerId = realtimeProvider.addEventListener { [weak self] event in
            Task { @MainActor [weak self] in self?.handle(event) }
        }
    }

    public func unsubscribeRealtime() async {
        guard let realtimeProvider else { return }
        if let id = realtimeListenerId { realtimeProvider.removeEventListener(id) }
        realtimeListenerId = nil
        await realtimeProvider.unsubscribe(channels: ["call:\(callId.uuidString)"])
    }

    private func handle(_ event: RealTimeProvider.ServerEvent) {
        guard event.type.hasPrefix("call.") else { return }
        guard event.entityId == callId || event.payload?["callSessionId"] == callId.uuidString else { return }
        Task { await refresh() }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        guard heartbeatTask == nil else { return }
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(CallSessionStore.heartbeatInterval * 1_000_000_000))
                guard let self else { return }
                if let token = self.token, token.expiresAt.timeIntervalSinceNow < 300 {
                    // Token nearly expired — refresh.
                    do {
                        let resp = try await self.repository.refreshToken(callId: self.callId)
                        if let t = resp.data { self.token = t }
                    } catch { /* will retry next tick */ }
                }
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    // MARK: - Snapshot

    private func snapshotManager() {
        guard let manager else { return }
        managerState = ManagerStateSnapshot(
            connectionState: manager.connectionState,
            localAudioMuted: manager.localAudioMuted,
            localVideoMuted: manager.localVideoMuted,
            isScreenSharing: manager.isScreenSharing,
            remoteParticipants: manager.remoteParticipants,
            activeSpeakerUserId: manager.activeSpeakerUserId
        )
    }
}
