import Foundation
import Domain
import AppNetwork
import SharedModels

public final class LiveMessagingService: MessagingRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration
    
    public init(apiClient: APIClientProtocol, configuration: APIConfiguration = .current) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }
    
    public func getConversations(searchQuery: String?) async throws -> APIResponse<[ConversationListItemDTO]> {
        let endpoint = MessagingEndpoint.getConversations(searchQuery: searchQuery, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<[ConversationListItemDTO]>.self)
    }
    
    public func createConversation(_ request: CreateConversationRequest) async throws -> APIResponse<ConversationDTO> {
        let endpoint = MessagingEndpoint.createConversation(payload: request, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<ConversationDTO>.self)
    }
    
    public func getConversation(id: UUID) async throws -> APIResponse<ConversationDTO> {
        let endpoint = MessagingEndpoint.getConversation(id: id, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<ConversationDTO>.self)
    }

    public func updateConversation(id: UUID, request: UpdateConversationRequest) async throws -> APIResponse<ConversationDTO> {
        let endpoint = MessagingEndpoint.updateConversation(id: id, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<ConversationDTO>.self)
    }

    public func archiveConversation(id: UUID) async throws -> APIResponse<ConversationDTO> {
        let endpoint = MessagingEndpoint.archiveConversation(id: id, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<ConversationDTO>.self)
    }

    public func leaveConversation(id: UUID) async throws -> APIResponse<EmptyResponse> {
        let endpoint = MessagingEndpoint.leaveConversation(id: id, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
    }

    public func addMembers(conversationId: UUID, request: AddConversationMembersRequest) async throws -> APIResponse<ConversationDTO> {
        let endpoint = MessagingEndpoint.addMembers(conversationId: conversationId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<ConversationDTO>.self)
    }

    public func removeMember(conversationId: UUID, memberId: UUID) async throws -> APIResponse<ConversationDTO> {
        let endpoint = MessagingEndpoint.removeMember(conversationId: conversationId, memberId: memberId, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<ConversationDTO>.self)
    }

    public func updatePreferences(conversationId: UUID, request: UpdateConversationMemberPreferencesRequest) async throws -> APIResponse<ConversationMemberDTO> {
        let endpoint = MessagingEndpoint.updatePreferences(conversationId: conversationId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<ConversationMemberDTO>.self)
    }
    
    public func getMessages(conversationId: UUID, cursor: UUID?, limit: Int) async throws -> APIResponse<[MessageDTO]> {
        let endpoint = MessagingEndpoint.getMessages(conversationId: conversationId, cursor: cursor, limit: limit, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<[MessageDTO]>.self)
    }

    public func getThread(messageId: UUID) async throws -> APIResponse<ThreadMessageBundleDTO> {
        let endpoint = MessagingEndpoint.getThread(messageId: messageId, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<ThreadMessageBundleDTO>.self)
    }
    
    public func sendMessage(conversationId: UUID, request: SendMessageRequest) async throws -> APIResponse<MessageDTO> {
        let endpoint = MessagingEndpoint.sendMessage(conversationId: conversationId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<MessageDTO>.self)
    }
    
    public func markRead(conversationId: UUID, request: MarkReadRequest) async throws -> APIResponse<EmptyResponse> {
        let endpoint = MessagingEndpoint.markRead(conversationId: conversationId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
    }
    
    public func editMessage(messageId: UUID, request: EditMessageRequest) async throws -> APIResponse<MessageDTO> {
        let endpoint = MessagingEndpoint.editMessage(messageId: messageId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<MessageDTO>.self)
    }
    
    public func deleteMessage(messageId: UUID) async throws -> APIResponse<EmptyResponse> {
        let endpoint = MessagingEndpoint.deleteMessage(messageId: messageId, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
    }
    
    public func sendTypingIndicator(conversationId: UUID, request: TypingIndicatorRequest) async throws -> APIResponse<EmptyResponse> {
        let endpoint = MessagingEndpoint.sendTypingIndicator(conversationId: conversationId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
    }

    public func updateMemberRole(conversationId: UUID, memberId: UUID, request: UpdateChannelMemberRoleRequest) async throws -> APIResponse<ConversationMemberDTO> {
        let endpoint = MessagingEndpoint.updateMemberRole(conversationId: conversationId, memberId: memberId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<ConversationMemberDTO>.self)
    }

    public func approveMember(conversationId: UUID, memberId: UUID) async throws -> APIResponse<ConversationMemberDTO> {
        let endpoint = MessagingEndpoint.approveMember(conversationId: conversationId, memberId: memberId, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<ConversationMemberDTO>.self)
    }

    // MARK: - Phase 3

    public func addReaction(messageId: UUID, emoji: String) async throws -> APIResponse<MessageDTO> {
        let endpoint = MessagingEndpoint.addReaction(messageId: messageId, payload: ReactionRequest(emoji: emoji), configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<MessageDTO>.self)
    }

    public func removeReaction(messageId: UUID, emoji: String) async throws -> APIResponse<MessageDTO> {
        let endpoint = MessagingEndpoint.removeReaction(messageId: messageId, emoji: emoji, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<MessageDTO>.self)
    }

    public func pinMessage(messageId: UUID) async throws -> APIResponse<MessageDTO> {
        let endpoint = MessagingEndpoint.pinMessage(messageId: messageId, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<MessageDTO>.self)
    }

    public func unpinMessage(messageId: UUID) async throws -> APIResponse<MessageDTO> {
        let endpoint = MessagingEndpoint.unpinMessage(messageId: messageId, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<MessageDTO>.self)
    }

    public func listPins(conversationId: UUID) async throws -> APIResponse<[MessageDTO]> {
        let endpoint = MessagingEndpoint.listPins(conversationId: conversationId, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<[MessageDTO]>.self)
    }

    public func bookmarkMessage(messageId: UUID) async throws -> APIResponse<MessageDTO> {
        let endpoint = MessagingEndpoint.bookmarkMessage(messageId: messageId, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<MessageDTO>.self)
    }

    public func unbookmarkMessage(messageId: UUID) async throws -> APIResponse<MessageDTO> {
        let endpoint = MessagingEndpoint.unbookmarkMessage(messageId: messageId, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<MessageDTO>.self)
    }

    public func listBookmarks() async throws -> APIResponse<[BookmarkDTO]> {
        let endpoint = MessagingEndpoint.listBookmarks(configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<[BookmarkDTO]>.self)
    }

    public func convertMessageToTask(messageId: UUID, request: ConvertMessageToTaskRequest) async throws -> APIResponse<ConvertMessageToTaskResponse> {
        let endpoint = MessagingEndpoint.convertToTask(messageId: messageId, payload: request, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<ConvertMessageToTaskResponse>.self)
    }

    public func globalSearch(q: String?, from: String?, `in`: String?, after: String?) async throws -> APIResponse<[MessageSearchResultDTO]> {
        let endpoint = MessagingEndpoint.globalSearch(q: q, from: from, `in`: `in`, after: after, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<[MessageSearchResultDTO]>.self)
    }
}

public final class LivePresenceService: PresenceRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration

    public init(apiClient: APIClientProtocol, configuration: APIConfiguration = .current) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }

    public func heartbeat(state: PresenceState?) async throws -> APIResponse<UserPresenceDTO> {
        let endpoint = PresenceEndpoint.heartbeat(payload: PresenceHeartbeatRequest(state: state), configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<UserPresenceDTO>.self)
    }

    public func setCustomStatus(_ request: SetCustomStatusRequest) async throws -> APIResponse<UserPresenceDTO> {
        let endpoint = PresenceEndpoint.setStatus(payload: request, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<UserPresenceDTO>.self)
    }

    public func clearCustomStatus() async throws -> APIResponse<UserPresenceDTO> {
        let endpoint = PresenceEndpoint.clearStatus(configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<UserPresenceDTO>.self)
    }

    public func getMyPresence() async throws -> APIResponse<UserPresenceDTO> {
        let endpoint = PresenceEndpoint.getMyPresence(configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<UserPresenceDTO>.self)
    }

    public func getUserPresence(userId: UUID) async throws -> APIResponse<UserPresenceDTO> {
        let endpoint = PresenceEndpoint.getUserPresence(userId: userId, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<UserPresenceDTO>.self)
    }

    public func getBulkPresence(userIds: [UUID]) async throws -> APIResponse<BulkPresenceResponse> {
        let endpoint = PresenceEndpoint.getBulkPresence(userIds: userIds, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<BulkPresenceResponse>.self)
    }
}
