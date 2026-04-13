import Foundation
import SharedModels

public protocol MessagingRepositoryProtocol: Sendable {
    func getConversations(searchQuery: String?) async throws -> APIResponse<[ConversationListItemDTO]>
    func createConversation(_ request: CreateConversationRequest) async throws -> APIResponse<ConversationDTO>
    func getConversation(id: UUID) async throws -> APIResponse<ConversationDTO>
    func updateConversation(id: UUID, request: UpdateConversationRequest) async throws -> APIResponse<ConversationDTO>
    func archiveConversation(id: UUID) async throws -> APIResponse<ConversationDTO>
    func leaveConversation(id: UUID) async throws -> APIResponse<EmptyResponse>
    func addMembers(conversationId: UUID, request: AddConversationMembersRequest) async throws -> APIResponse<ConversationDTO>
    func removeMember(conversationId: UUID, memberId: UUID) async throws -> APIResponse<ConversationDTO>
    func updatePreferences(conversationId: UUID, request: UpdateConversationMemberPreferencesRequest) async throws -> APIResponse<ConversationMemberDTO>
    func getMessages(conversationId: UUID, cursor: UUID?, limit: Int) async throws -> APIResponse<[MessageDTO]>
    func getThread(messageId: UUID) async throws -> APIResponse<ThreadMessageBundleDTO>
    func sendMessage(conversationId: UUID, request: SendMessageRequest) async throws -> APIResponse<MessageDTO>
    func markRead(conversationId: UUID, request: MarkReadRequest) async throws -> APIResponse<EmptyResponse>
    func editMessage(messageId: UUID, request: EditMessageRequest) async throws -> APIResponse<MessageDTO>
    func deleteMessage(messageId: UUID) async throws -> APIResponse<EmptyResponse>
    func sendTypingIndicator(conversationId: UUID, request: TypingIndicatorRequest) async throws -> APIResponse<EmptyResponse>
    func updateMemberRole(conversationId: UUID, memberId: UUID, request: UpdateChannelMemberRoleRequest) async throws -> APIResponse<ConversationMemberDTO>
    func approveMember(conversationId: UUID, memberId: UUID) async throws -> APIResponse<ConversationMemberDTO>
}
