import Foundation
import SharedModels
import AppNetwork
import Domain

public protocol IntegrationRepositoryProtocol: Sendable {
    func getAPIKeys() async throws -> [APIKeyDTO]
    func createAPIKey(_ request: CreateAPIKeyRequest) async throws -> CreateAPIKeyResponse
    func revokeAPIKey(id: UUID) async throws
    
    func getWebhooks() async throws -> [WebhookSubscriptionDTO]
    func createWebhook(_ request: CreateWebhookRequest) async throws -> WebhookSubscriptionDTO
    func updateWebhook(id: UUID, request: UpdateWebhookRequest) async throws -> WebhookSubscriptionDTO
    func deleteWebhook(id: UUID) async throws
    func testWebhook(id: UUID) async throws
}

public final class IntegrationRepository: IntegrationRepositoryProtocol {
    private let apiClient: APIClient
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    public func getAPIKeys() async throws -> [APIKeyDTO] {
        let endpoint = IntegrationEndpoint.getAPIKeys
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[APIKeyDTO]>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func createAPIKey(_ request: CreateAPIKeyRequest) async throws -> CreateAPIKeyResponse {
        let endpoint = IntegrationEndpoint.createAPIKey(request)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<CreateAPIKeyResponse>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func revokeAPIKey(id: UUID) async throws {
        let endpoint = IntegrationEndpoint.revokeAPIKey(id)
        _ = try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
    }
    
    public func getWebhooks() async throws -> [WebhookSubscriptionDTO] {
        let endpoint = IntegrationEndpoint.getWebhooks
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[WebhookSubscriptionDTO]>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func createWebhook(_ request: CreateWebhookRequest) async throws -> WebhookSubscriptionDTO {
        let endpoint = IntegrationEndpoint.createWebhook(request)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<WebhookSubscriptionDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func updateWebhook(id: UUID, request: UpdateWebhookRequest) async throws -> WebhookSubscriptionDTO {
        let endpoint = IntegrationEndpoint.updateWebhook(id, request)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<WebhookSubscriptionDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func deleteWebhook(id: UUID) async throws {
        let endpoint = IntegrationEndpoint.deleteWebhook(id)
        _ = try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
    }
    
    public func testWebhook(id: UUID) async throws {
        let endpoint = IntegrationEndpoint.testWebhook(id)
        _ = try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
    }
}
