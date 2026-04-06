import Foundation
import Domain
import AppNetwork
import SharedModels

public final class LiveNotificationService: NotificationRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let apiConfiguration: APIConfiguration
    
    public init(apiClient: APIClientProtocol, configuration: APIConfiguration = .current) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }
    
    public func getNotifications(unreadOnly: Bool) async throws -> APIResponse<[NotificationDTO]> {
        let endpoint = NotificationEndpoint.getNotifications(unreadOnly: unreadOnly, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<[NotificationDTO]>.self)
    }
    
    public func markRead(id: UUID) async throws -> APIResponse<NotificationDTO> {
        let endpoint = NotificationEndpoint.markRead(id: id, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<NotificationDTO>.self)
    }
}
