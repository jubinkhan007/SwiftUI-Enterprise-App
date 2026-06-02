import Foundation
import SharedModels

public protocol CallRepositoryProtocol: Sendable {
    func initiateCall(_ request: InitiateCallRequest) async throws -> APIResponse<CallJoinTicketDTO>
    func getCall(id: UUID) async throws -> APIResponse<CallSessionDTO>
    func acceptCall(id: UUID) async throws -> APIResponse<CallJoinTicketDTO>
    func declineCall(id: UUID) async throws -> APIResponse<EmptyResponse>
    func endCall(id: UUID) async throws -> APIResponse<CallSessionDTO>
    func leaveCall(id: UUID) async throws -> APIResponse<EmptyResponse>
    func updateMyState(callId: UUID, request: UpdateParticipantStateRequest) async throws -> APIResponse<CallParticipantDTO>
    func adminAction(callId: UUID, request: CallAdminEventRequest) async throws -> APIResponse<CallSessionDTO>
    func refreshToken(callId: UUID) async throws -> APIResponse<CallTokenDTO>
    func createRecord(callId: UUID, request: CreateCallRecordRequest) async throws -> APIResponse<CallRecordDTO>

    func registerVoIPToken(_ request: RegisterVoIPTokenRequest) async throws -> APIResponse<EmptyResponse>
    func deleteVoIPToken(_ token: String) async throws -> APIResponse<EmptyResponse>
}
