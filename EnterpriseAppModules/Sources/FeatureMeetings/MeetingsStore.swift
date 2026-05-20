import Foundation
import Combine
import Domain
import SharedModels

/// Singleton store for the meetings list/detail cache. Optimistic RSVP/cancel
/// with rollback on error, matching the pattern used in `MessageInteractionStore`.
@MainActor
public final class MeetingsStore: ObservableObject {
    public static let shared = MeetingsStore()

    @Published public private(set) var upcoming: [MeetingListItemDTO] = []
    @Published public private(set) var past: [MeetingListItemDTO] = []
    @Published public private(set) var today: [MeetingListItemDTO] = []
    @Published public private(set) var byId: [UUID: MeetingDTO] = [:]
    @Published public var lastError: Error?
    @Published public var isLoading: Bool = false

    private var repository: MeetingRepositoryProtocol?
    private var currentUserId: UUID?

    private init() {}

    public func configure(repository: MeetingRepositoryProtocol, currentUserId: UUID) {
        self.repository = repository
        self.currentUserId = currentUserId
    }

    // MARK: - List

    public func loadUpcoming() async {
        await load(scope: "upcoming") { [weak self] items in self?.upcoming = items }
    }

    public func loadToday() async {
        await load(scope: "today") { [weak self] items in self?.today = items }
    }

    public func loadPast() async {
        await load(scope: "past") { [weak self] items in self?.past = items }
    }

    private func load(scope: String, assign: @escaping ([MeetingListItemDTO]) -> Void) async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await repository.listMeetings(query: MeetingListQuery(scope: scope))
            assign(response.data ?? [])
        } catch {
            lastError = error
        }
    }

    // MARK: - Detail

    @discardableResult
    public func refreshDetail(_ id: UUID) async -> MeetingDTO? {
        guard let repository else { return nil }
        do {
            let response = try await repository.getMeeting(id: id)
            if let dto = response.data {
                byId[id] = dto
                ingestListProjection(dto)
                return dto
            }
        } catch {
            lastError = error
        }
        return nil
    }

    public func ingest(_ dto: MeetingDTO) {
        byId[dto.id] = dto
        ingestListProjection(dto)
    }

    private func ingestListProjection(_ dto: MeetingDTO) {
        let item = MeetingListItemDTO(
            id: dto.id,
            title: dto.title,
            scheduledStartAt: dto.scheduledStartAt,
            scheduledEndAt: dto.scheduledEndAt,
            timezone: dto.timezone,
            status: dto.status,
            hostId: dto.hostId,
            hostDisplayName: dto.hostDisplayName,
            participantCount: dto.participants.count,
            myInviteStatus: dto.myParticipant?.inviteStatus,
            myRole: dto.myParticipant?.role,
            waitingCount: dto.waitingCount
        )
        upcoming = upcoming.map { $0.id == item.id ? item : $0 }
        today = today.map { $0.id == item.id ? item : $0 }
        past = past.map { $0.id == item.id ? item : $0 }
    }

    // MARK: - Mutations

    @discardableResult
    public func create(_ request: CreateMeetingRequest) async -> MeetingDTO? {
        guard let repository else { return nil }
        do {
            let response = try await repository.createMeeting(request)
            if let dto = response.data {
                byId[dto.id] = dto
                if Calendar.current.isDateInToday(dto.scheduledStartAt) {
                    today.insert(asListItem(dto), at: 0)
                } else if dto.scheduledStartAt > Date() {
                    upcoming.insert(asListItem(dto), at: 0)
                }
                return dto
            }
        } catch {
            lastError = error
        }
        return nil
    }

    @discardableResult
    public func cancel(_ id: UUID, reason: String? = nil) async -> MeetingDTO? {
        guard let repository else { return nil }

        let previous = byId[id]
        if var rolling = previous {
            rolling = MeetingDTO(
                id: rolling.id, orgId: rolling.orgId,
                conversationId: rolling.conversationId,
                meetingChatConversationId: rolling.meetingChatConversationId,
                title: rolling.title, description: rolling.description, agenda: rolling.agenda,
                scheduledStartAt: rolling.scheduledStartAt, scheduledEndAt: rolling.scheduledEndAt,
                timezone: rolling.timezone, status: .cancelled,
                startedAt: rolling.startedAt, endedAt: rolling.endedAt,
                cancelledAt: Date(), cancelReason: reason,
                hostId: rolling.hostId, hostDisplayName: rolling.hostDisplayName,
                requiresWaitingRoom: rolling.requiresWaitingRoom, allowGuests: rolling.allowGuests,
                joinCode: rolling.joinCode, shareUrl: rolling.shareUrl, icsUrl: rolling.icsUrl,
                provider: rolling.provider, recurrence: rolling.recurrence,
                parentMeetingId: rolling.parentMeetingId,
                participants: rolling.participants, myParticipant: rolling.myParticipant,
                waitingCount: rolling.waitingCount,
                createdBy: rolling.createdBy, createdAt: rolling.createdAt, updatedAt: rolling.updatedAt
            )
            byId[id] = rolling
        }

        do {
            let response = try await repository.cancelMeeting(id: id, request: CancelMeetingRequest(reason: reason))
            if let dto = response.data {
                byId[id] = dto
                upcoming.removeAll { $0.id == id }
                today.removeAll { $0.id == id }
                return dto
            }
        } catch {
            if let previous { byId[id] = previous }
            lastError = error
        }
        return nil
    }

    @discardableResult
    public func rsvp(_ id: UUID, status: MeetingInviteStatus) async -> MeetingDTO? {
        guard let repository else { return nil }

        let previous = byId[id]
        if let prev = previous, let mine = prev.myParticipant {
            let updatedMine = MeetingParticipantDTO(
                id: mine.id, meetingId: mine.meetingId,
                userId: mine.userId, guestEmail: mine.guestEmail, guestName: mine.guestName,
                displayName: mine.displayName, role: mine.role,
                inviteStatus: status, joinState: mine.joinState,
                waitingSinceAt: mine.waitingSinceAt, joinedAt: mine.joinedAt,
                leftAt: mine.leftAt, lastStateChangedAt: Date()
            )
            byId[id] = withMyParticipant(prev, mine: updatedMine)
        }

        do {
            let response = try await repository.rsvp(meetingId: id, request: MeetingRSVPRequest(status: status))
            if let dto = response.data {
                byId[id] = dto
                ingestListProjection(dto)
                return dto
            }
        } catch {
            if let previous { byId[id] = previous }
            lastError = error
        }
        return nil
    }

    private func asListItem(_ dto: MeetingDTO) -> MeetingListItemDTO {
        MeetingListItemDTO(
            id: dto.id, title: dto.title,
            scheduledStartAt: dto.scheduledStartAt, scheduledEndAt: dto.scheduledEndAt,
            timezone: dto.timezone, status: dto.status,
            hostId: dto.hostId, hostDisplayName: dto.hostDisplayName,
            participantCount: dto.participants.count,
            myInviteStatus: dto.myParticipant?.inviteStatus,
            myRole: dto.myParticipant?.role,
            waitingCount: dto.waitingCount
        )
    }

    private func withMyParticipant(_ dto: MeetingDTO, mine: MeetingParticipantDTO) -> MeetingDTO {
        var updatedParticipants = dto.participants
        if let idx = updatedParticipants.firstIndex(where: { $0.id == mine.id }) {
            updatedParticipants[idx] = mine
        }
        return MeetingDTO(
            id: dto.id, orgId: dto.orgId,
            conversationId: dto.conversationId,
            meetingChatConversationId: dto.meetingChatConversationId,
            title: dto.title, description: dto.description, agenda: dto.agenda,
            scheduledStartAt: dto.scheduledStartAt, scheduledEndAt: dto.scheduledEndAt,
            timezone: dto.timezone, status: dto.status,
            startedAt: dto.startedAt, endedAt: dto.endedAt,
            cancelledAt: dto.cancelledAt, cancelReason: dto.cancelReason,
            hostId: dto.hostId, hostDisplayName: dto.hostDisplayName,
            requiresWaitingRoom: dto.requiresWaitingRoom, allowGuests: dto.allowGuests,
            joinCode: dto.joinCode, shareUrl: dto.shareUrl, icsUrl: dto.icsUrl,
            provider: dto.provider, recurrence: dto.recurrence,
            parentMeetingId: dto.parentMeetingId,
            participants: updatedParticipants, myParticipant: mine,
            waitingCount: dto.waitingCount,
            createdBy: dto.createdBy, createdAt: dto.createdAt, updatedAt: dto.updatedAt
        )
    }
}
