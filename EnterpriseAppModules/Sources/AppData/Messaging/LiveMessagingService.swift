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
}
