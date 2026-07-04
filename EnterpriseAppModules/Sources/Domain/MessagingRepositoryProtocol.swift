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

    // Phase 3
    func addReaction(messageId: UUID, emoji: String) async throws -> APIResponse<MessageDTO>
    func removeReaction(messageId: UUID, emoji: String) async throws -> APIResponse<MessageDTO>
    func pinMessage(messageId: UUID) async throws -> APIResponse<MessageDTO>
    func unpinMessage(messageId: UUID) async throws -> APIResponse<MessageDTO>
    func listPins(conversationId: UUID) async throws -> APIResponse<[MessageDTO]>
    func bookmarkMessage(messageId: UUID) async throws -> APIResponse<MessageDTO>
    func unbookmarkMessage(messageId: UUID) async throws -> APIResponse<MessageDTO>
    func listBookmarks() async throws -> APIResponse<[BookmarkDTO]>
    func convertMessageToTask(messageId: UUID, request: ConvertMessageToTaskRequest) async throws -> APIResponse<ConvertMessageToTaskResponse>
    func globalSearch(q: String?, from: String?, `in`: String?, after: String?) async throws -> APIResponse<[MessageSearchResultDTO]>
}

public protocol PresenceRepositoryProtocol: Sendable {
    func heartbeat(state: PresenceState?) async throws -> APIResponse<UserPresenceDTO>
    func setCustomStatus(_ request: SetCustomStatusRequest) async throws -> APIResponse<UserPresenceDTO>
    func clearCustomStatus() async throws -> APIResponse<UserPresenceDTO>
    func getMyPresence() async throws -> APIResponse<UserPresenceDTO>
    func getUserPresence(userId: UUID) async throws -> APIResponse<UserPresenceDTO>
    func getBulkPresence(userIds: [UUID]) async throws -> APIResponse<BulkPresenceResponse>
}
