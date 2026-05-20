import Foundation
import Combine
import Domain
import AppNetwork
import SharedModels

/// One-per-active-meeting store. Owns the in-flight join state, participant list,
/// host waiting queue, and the realtime subscription to `meeting:<id>`.
///
/// Heartbeats every 30 s while in_meeting/waiting so the server can detect drops.
@MainActor
public final class MeetingSessionStore: ObservableObject {
    public static let heartbeatInterval: TimeInterval = 30

    @Published public private(set) var meeting: MeetingDTO?
    @Published public private(set) var ticket: MeetingJoinTicketDTO?
    @Published public private(set) var notes: MeetingNotesDTO?
    @Published public private(set) var summary: MeetingSummaryDTO?
    @Published public var lastError: Error?

    public let meetingId: UUID
    private let currentUserId: UUID
    private let repository: MeetingRepositoryProtocol
    private let realtimeProvider: RealTimeProvider?

    private var heartbeatTask: Task<Void, Never>?
    private var listenerId: UUID?

    public init(
        meetingId: UUID,
        currentUserId: UUID,
        repository: MeetingRepositoryProtocol,
        realtimeProvider: RealTimeProvider? = nil
    ) {
        self.meetingId = meetingId
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
            let response = try await repository.getMeeting(id: meetingId)
            if let dto = response.data {
                meeting = dto
                MeetingsStore.shared.ingest(dto)
            }
        } catch {
            lastError = error
        }
    }

    public func loadNotes() async {
        do {
            let response = try await repository.getNotes(meetingId: meetingId)
            notes = response.data
        } catch {
            lastError = error
        }
    }

    public func loadSummary() async {
        do {
            let response = try await repository.getSummary(meetingId: meetingId)
            summary = response.data
        } catch {
            // Summary may not exist yet — non-fatal.
        }
    }

    // MARK: - Realtime

    public func subscribeRealtime() async {
        guard let realtimeProvider else { return }
        await realtimeProvider.subscribe(channels: ["meeting:\(meetingId.uuidString)"])
        listenerId = realtimeProvider.addEventListener { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
    }

    public func unsubscribeRealtime() async {
        guard let realtimeProvider else { return }
        if let listenerId { realtimeProvider.removeEventListener(listenerId) }
        listenerId = nil
        await realtimeProvider.unsubscribe(channels: ["meeting:\(meetingId.uuidString)"])
    }

    private func handle(_ event: RealTimeProvider.ServerEvent) {
        guard event.entityId == meetingId || event.payload?["meetingId"] == meetingId.uuidString else { return }
        // Any meeting.* event invalidates our cached view; just refetch.
        if event.type.hasPrefix("meeting.notes_updated") {
            Task { await loadNotes() }
            return
        }
        if event.type.hasPrefix("meeting.summary_ready") {
            Task { await loadSummary() }
            return
        }
        Task { await refresh() }
    }

    // MARK: - Lifecycle actions

    public func join() async {
        do {
            let response = try await repository.joinMeeting(id: meetingId)
            ticket = response.data
            await refresh()
            await subscribeRealtime()
            startHeartbeat()
        } catch {
            lastError = error
        }
    }

    public func leave() async {
        stopHeartbeat()
        await unsubscribeRealtime()
        do { _ = try await repository.leaveMeeting(id: meetingId) }
        catch { lastError = error }
        await refresh()
    }

    public func start() async {
        do {
            let response = try await repository.startMeeting(id: meetingId)
            if let dto = response.data {
                meeting = dto
                MeetingsStore.shared.ingest(dto)
            }
        } catch {
            lastError = error
        }
    }

    public func end() async {
        stopHeartbeat()
        await unsubscribeRealtime()
        do {
            let response = try await repository.endMeeting(id: meetingId)
            if let dto = response.data {
                meeting = dto
                MeetingsStore.shared.ingest(dto)
            }
        } catch {
            lastError = error
        }
    }

    public func admit(participantId: UUID) async {
        do {
            let response = try await repository.admit(meetingId: meetingId, participantId: participantId)
            if let dto = response.data { meeting = dto }
        } catch { lastError = error }
    }

    public func deny(participantId: UUID) async {
        do {
            let response = try await repository.deny(meetingId: meetingId, participantId: participantId)
            if let dto = response.data { meeting = dto }
        } catch { lastError = error }
    }

    public func addParticipants(memberIds: [UUID], guestEmails: [String]?) async {
        do {
            let response = try await repository.addParticipants(
                meetingId: meetingId,
                request: AddMeetingParticipantsRequest(memberIds: memberIds, guestEmails: guestEmails)
            )
            if let dto = response.data { meeting = dto }
        } catch { lastError = error }
    }

    public func removeParticipant(_ participantId: UUID) async {
        do {
            let response = try await repository.removeParticipant(meetingId: meetingId, participantId: participantId)
            if let dto = response.data { meeting = dto }
        } catch { lastError = error }
    }

    public func changeRole(participantId: UUID, to role: MeetingRole) async {
        do {
            let response = try await repository.changeRole(
                meetingId: meetingId,
                participantId: participantId,
                request: ChangeMeetingRoleRequest(role: role)
            )
            if let dto = response.data { meeting = dto }
        } catch { lastError = error }
    }

    // MARK: - Notes

    public func saveNotes(body: String) async {
        guard let current = notes else {
            // Load + retry with current version.
            await loadNotes()
            guard let loaded = notes else { return }
            await persistNotes(body: body, expectedVersion: loaded.version)
            return
        }
        await persistNotes(body: body, expectedVersion: current.version)
    }

    private func persistNotes(body: String, expectedVersion: Int) async {
        do {
            let response = try await repository.updateNotes(
                meetingId: meetingId,
                request: UpdateMeetingNotesRequest(body: body, expectedVersion: expectedVersion)
            )
            notes = response.data
        } catch {
            lastError = error
            // On conflict, refresh and bubble error for the UI to retry.
            await loadNotes()
        }
    }

    // MARK: - Summary

    public func generateSummary(regenerate: Bool = false) async {
        do {
            let response = try await repository.generateSummary(
                meetingId: meetingId,
                request: GenerateMeetingSummaryRequest(regenerate: regenerate)
            )
            summary = response.data
        } catch { lastError = error }
    }

    public func addActionItem(_ text: String, assigneeUserId: UUID? = nil, dueAt: Date? = nil, createTaskInListId: UUID? = nil) async {
        do {
            let response = try await repository.addActionItem(
                meetingId: meetingId,
                request: CreateMeetingActionItemRequest(
                    text: text,
                    assigneeUserId: assigneeUserId,
                    dueAt: dueAt,
                    createTaskInListId: createTaskInListId
                )
            )
            summary = response.data
        } catch { lastError = error }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        guard heartbeatTask == nil else { return }
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sendHeartbeat()
                try? await Task.sleep(nanoseconds: UInt64(MeetingSessionStore.heartbeatInterval * 1_000_000_000))
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func sendHeartbeat() async {
        do { _ = try await repository.heartbeat(meetingId: meetingId) }
        catch { /* transient — next tick will retry */ }
    }
}
