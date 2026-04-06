import Foundation
import SharedModels

public protocol MessagingRepositoryProtocol: Sendable {
    func getConversations(searchQuery: String?) async throws -> APIResponse<[ConversationListItemDTO]>
    func createConversation(_ request: CreateConversationRequest) async throws -> APIResponse<ConversationDTO>
    func getConversation(id: UUID) async throws -> APIResponse<ConversationDTO>
    func getMessages(conversationId: UUID, cursor: UUID?, limit: Int) async throws -> APIResponse<[MessageDTO]>
    func sendMessage(conversationId: UUID, request: SendMessageRequest) async throws -> APIResponse<MessageDTO>
    func markRead(conversationId: UUID, request: MarkReadRequest) async throws -> APIResponse<EmptyResponse>
    func editMessage(messageId: UUID, request: EditMessageRequest) async throws -> APIResponse<MessageDTO>
    func deleteMessage(messageId: UUID) async throws -> APIResponse<EmptyResponse>
    func sendTypingIndicator(conversationId: UUID, request: TypingIndicatorRequest) async throws -> APIResponse<EmptyResponse>
}
