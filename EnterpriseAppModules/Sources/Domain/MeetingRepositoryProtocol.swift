import Foundation
import SharedModels

public struct MeetingListQuery: Sendable, Hashable {
    public let scope: String?
    public let conversationId: UUID?
    public let hostId: UUID?
    public let status: String?
    public let search: String?
    public let from: Date?
    public let to: Date?

    public init(
        scope: String? = "upcoming",
        conversationId: UUID? = nil,
        hostId: UUID? = nil,
        status: String? = nil,
        search: String? = nil,
        from: Date? = nil,
        to: Date? = nil
    ) {
        self.scope = scope
        self.conversationId = conversationId
        self.hostId = hostId
        self.status = status
        self.search = search
        self.from = from
        self.to = to
    }
}

public protocol MeetingRepositoryProtocol: Sendable {
    func createMeeting(_ request: CreateMeetingRequest) async throws -> APIResponse<MeetingDTO>
    func listMeetings(query: MeetingListQuery) async throws -> APIResponse<[MeetingListItemDTO]>
    func getMeeting(id: UUID) async throws -> APIResponse<MeetingDTO>
    func updateMeeting(id: UUID, request: UpdateMeetingRequest) async throws -> APIResponse<MeetingDTO>
    func cancelMeeting(id: UUID, request: CancelMeetingRequest) async throws -> APIResponse<MeetingDTO>

    func startMeeting(id: UUID) async throws -> APIResponse<MeetingDTO>
    func endMeeting(id: UUID) async throws -> APIResponse<MeetingDTO>
    func joinMeeting(id: UUID) async throws -> APIResponse<MeetingJoinTicketDTO>
    func leaveMeeting(id: UUID) async throws -> APIResponse<EmptyResponse>
    func heartbeat(meetingId: UUID) async throws -> APIResponse<EmptyResponse>

    func addParticipants(meetingId: UUID, request: AddMeetingParticipantsRequest) async throws -> APIResponse<MeetingDTO>
    func removeParticipant(meetingId: UUID, participantId: UUID) async throws -> APIResponse<MeetingDTO>
    func changeRole(meetingId: UUID, participantId: UUID, request: ChangeMeetingRoleRequest) async throws -> APIResponse<MeetingDTO>
    func rsvp(meetingId: UUID, request: MeetingRSVPRequest) async throws -> APIResponse<MeetingDTO>
    func admit(meetingId: UUID, participantId: UUID) async throws -> APIResponse<MeetingDTO>
    func deny(meetingId: UUID, participantId: UUID) async throws -> APIResponse<MeetingDTO>

    func getNotes(meetingId: UUID) async throws -> APIResponse<MeetingNotesDTO>
    func updateNotes(meetingId: UUID, request: UpdateMeetingNotesRequest) async throws -> APIResponse<MeetingNotesDTO>

    func getSummary(meetingId: UUID) async throws -> APIResponse<MeetingSummaryDTO>
    func generateSummary(meetingId: UUID, request: GenerateMeetingSummaryRequest) async throws -> APIResponse<MeetingSummaryDTO>
    func addActionItem(meetingId: UUID, request: CreateMeetingActionItemRequest) async throws -> APIResponse<MeetingSummaryDTO>

    func resolveJoinCode(_ joinCode: String, token: String) async throws -> APIResponse<MeetingShareLinkDTO>
}
