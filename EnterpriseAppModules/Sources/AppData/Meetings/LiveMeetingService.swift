import Foundation
import Domain
import AppNetwork
import SharedModels

public final class LiveMeetingService: MeetingRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration

    public init(apiClient: APIClientProtocol, configuration: APIConfiguration = .current) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }

    public func createMeeting(_ request: CreateMeetingRequest) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.createMeeting(payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func listMeetings(query: MeetingListQuery) async throws -> APIResponse<[MeetingListItemDTO]> {
        let ep = MeetingEndpoint.listMeetings(
            scope: query.scope,
            conversationId: query.conversationId,
            hostId: query.hostId,
            status: query.status,
            search: query.search,
            from: query.from,
            to: query.to,
            configuration: apiConfiguration
        )
        return try await apiClient.request(ep, responseType: APIResponse<[MeetingListItemDTO]>.self)
    }

    public func getMeeting(id: UUID) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.getMeeting(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func updateMeeting(id: UUID, request: UpdateMeetingRequest) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.updateMeeting(id: id, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func cancelMeeting(id: UUID, request: CancelMeetingRequest) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.cancelMeeting(id: id, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func startMeeting(id: UUID) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.startMeeting(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func endMeeting(id: UUID) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.endMeeting(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func joinMeeting(id: UUID) async throws -> APIResponse<MeetingJoinTicketDTO> {
        let ep = MeetingEndpoint.joinMeeting(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingJoinTicketDTO>.self)
    }

    public func leaveMeeting(id: UUID) async throws -> APIResponse<EmptyResponse> {
        let ep = MeetingEndpoint.leaveMeeting(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<EmptyResponse>.self)
    }

    public func heartbeat(meetingId: UUID) async throws -> APIResponse<EmptyResponse> {
        let ep = MeetingEndpoint.heartbeat(id: meetingId, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<EmptyResponse>.self)
    }

    public func addParticipants(meetingId: UUID, request: AddMeetingParticipantsRequest) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.addParticipants(id: meetingId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func removeParticipant(meetingId: UUID, participantId: UUID) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.removeParticipant(id: meetingId, participantId: participantId, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func changeRole(meetingId: UUID, participantId: UUID, request: ChangeMeetingRoleRequest) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.changeRole(id: meetingId, participantId: participantId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func rsvp(meetingId: UUID, request: MeetingRSVPRequest) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.rsvp(id: meetingId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func admit(meetingId: UUID, participantId: UUID) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.admit(id: meetingId, participantId: participantId, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func deny(meetingId: UUID, participantId: UUID) async throws -> APIResponse<MeetingDTO> {
        let ep = MeetingEndpoint.deny(id: meetingId, participantId: participantId, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingDTO>.self)
    }

    public func getNotes(meetingId: UUID) async throws -> APIResponse<MeetingNotesDTO> {
        let ep = MeetingEndpoint.getNotes(id: meetingId, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingNotesDTO>.self)
    }

    public func updateNotes(meetingId: UUID, request: UpdateMeetingNotesRequest) async throws -> APIResponse<MeetingNotesDTO> {
        let ep = MeetingEndpoint.updateNotes(id: meetingId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingNotesDTO>.self)
    }

    public func getSummary(meetingId: UUID) async throws -> APIResponse<MeetingSummaryDTO> {
        let ep = MeetingEndpoint.getSummary(id: meetingId, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingSummaryDTO>.self)
    }

    public func generateSummary(meetingId: UUID, request: GenerateMeetingSummaryRequest) async throws -> APIResponse<MeetingSummaryDTO> {
        let ep = MeetingEndpoint.generateSummary(id: meetingId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingSummaryDTO>.self)
    }

    public func addActionItem(meetingId: UUID, request: CreateMeetingActionItemRequest) async throws -> APIResponse<MeetingSummaryDTO> {
        let ep = MeetingEndpoint.addActionItem(id: meetingId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingSummaryDTO>.self)
    }

    public func resolveJoinCode(_ joinCode: String, token: String) async throws -> APIResponse<MeetingShareLinkDTO> {
        let ep = MeetingEndpoint.byJoinCode(joinCode: joinCode, token: token, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<MeetingShareLinkDTO>.self)
    }
}
