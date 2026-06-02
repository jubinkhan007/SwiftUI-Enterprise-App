import Foundation
import Domain
import AppNetwork
import SharedModels

public final class LiveCallService: CallRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration

    public init(apiClient: APIClientProtocol, configuration: APIConfiguration = .current) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }

    public func initiateCall(_ request: InitiateCallRequest) async throws -> APIResponse<CallJoinTicketDTO> {
        let ep = CallEndpoint.initiate(payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<CallJoinTicketDTO>.self)
    }

    public func getCall(id: UUID) async throws -> APIResponse<CallSessionDTO> {
        let ep = CallEndpoint.show(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<CallSessionDTO>.self)
    }

    public func acceptCall(id: UUID) async throws -> APIResponse<CallJoinTicketDTO> {
        let ep = CallEndpoint.accept(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<CallJoinTicketDTO>.self)
    }

    public func declineCall(id: UUID) async throws -> APIResponse<EmptyResponse> {
        let ep = CallEndpoint.decline(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<EmptyResponse>.self)
    }

    public func endCall(id: UUID) async throws -> APIResponse<CallSessionDTO> {
        let ep = CallEndpoint.end(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<CallSessionDTO>.self)
    }

    public func leaveCall(id: UUID) async throws -> APIResponse<EmptyResponse> {
        let ep = CallEndpoint.leave(id: id, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<EmptyResponse>.self)
    }

    public func updateMyState(callId: UUID, request: UpdateParticipantStateRequest) async throws -> APIResponse<CallParticipantDTO> {
        let ep = CallEndpoint.updateMyState(id: callId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<CallParticipantDTO>.self)
    }

    public func adminAction(callId: UUID, request: CallAdminEventRequest) async throws -> APIResponse<CallSessionDTO> {
        let ep = CallEndpoint.adminAction(id: callId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<CallSessionDTO>.self)
    }

    public func refreshToken(callId: UUID) async throws -> APIResponse<CallTokenDTO> {
        let ep = CallEndpoint.refreshToken(id: callId, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<CallTokenDTO>.self)
    }

    public func createRecord(callId: UUID, request: CreateCallRecordRequest) async throws -> APIResponse<CallRecordDTO> {
        let ep = CallEndpoint.createRecord(id: callId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<CallRecordDTO>.self)
    }

    public func registerVoIPToken(_ request: RegisterVoIPTokenRequest) async throws -> APIResponse<EmptyResponse> {
        let ep = CallEndpoint.registerVoIP(payload: request, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<EmptyResponse>.self)
    }

    public func deleteVoIPToken(_ token: String) async throws -> APIResponse<EmptyResponse> {
        let ep = CallEndpoint.deleteVoIP(token: token, configuration: apiConfiguration)
        return try await apiClient.request(ep, responseType: APIResponse<EmptyResponse>.self)
    }
}
