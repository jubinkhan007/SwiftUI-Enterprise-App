import Foundation
import SharedModels

public protocol MessagingRepositoryProtocol: Sendable {
    func getConversations() async throws -> APIResponse<[ConversationListItemDTO]>
    func createConversation(_ request: CreateConversationRequest) async throws -> APIResponse<ConversationDTO>
    func getConversation(id: UUID) async throws -> APIResponse<ConversationDTO>
    func getMessages(conversationId: UUID, cursor: UUID?, limit: Int) async throws -> APIResponse<[MessageDTO]>
    func sendMessage(conversationId: UUID, request: SendMessageRequest) async throws -> APIResponse<MessageDTO>
    func markRead(conversationId: UUID, request: MarkReadRequest) async throws -> APIResponse<EmptyResponse>
}
