import Foundation
import SharedModels
import AppNetwork
import Domain

public final class IntegrationRepository: Domain.IntegrationRepositoryProtocol {
    private let apiClient: APIClient
    private let configuration: APIConfiguration
    
    public init(apiClient: APIClient, configuration: APIConfiguration = .current) {
        self.apiClient = apiClient
        self.configuration = configuration
    }
    
    public func listAPIKeys() async throws -> [APIKeyDTO] {
        let endpoint = IntegrationEndpoint.getAPIKeys(configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[APIKeyDTO]>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func createAPIKey(payload: CreateAPIKeyRequest) async throws -> CreateAPIKeyResponse {
        let endpoint = IntegrationEndpoint.createAPIKey(payload, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<CreateAPIKeyResponse>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func revokeAPIKey(id: UUID) async throws {
        let endpoint = IntegrationEndpoint.revokeAPIKey(id, configuration: configuration)
        _ = try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
    }
    
    public func listWebhooks() async throws -> [WebhookSubscriptionDTO] {
        let endpoint = IntegrationEndpoint.getWebhooks(configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[WebhookSubscriptionDTO]>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func createWebhook(payload: CreateWebhookSubscriptionRequest) async throws -> WebhookSubscriptionDTO {
        let endpoint = IntegrationEndpoint.createWebhook(payload, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<WebhookSubscriptionDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func updateWebhook(id: UUID, request: UpdateWebhookSubscriptionRequest) async throws -> WebhookSubscriptionDTO {
        let endpoint = IntegrationEndpoint.updateWebhook(id, request, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<WebhookSubscriptionDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }

    public func deleteWebhook(id: UUID) async throws {
        let endpoint = IntegrationEndpoint.deleteWebhook(id, configuration: configuration)
        _ = try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
    }
    
    public func testWebhook(id: UUID) async throws -> WebhookTestResponse {
        let endpoint = IntegrationEndpoint.testWebhook(id, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<WebhookTestResponse>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
}
