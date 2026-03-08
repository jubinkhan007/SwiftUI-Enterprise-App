import Foundation
import AppNetwork
import Domain
import SharedModels

public final class IntegrationRepository: IntegrationRepositoryProtocol {
    private let apiClient: APIClient
    private let apiConfiguration: APIConfiguration

    public init(apiClient: APIClient, configuration: APIConfiguration = .localVapor) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }

    public func listAPIKeys() async throws -> [APIKeyDTO] {
        let endpoint = IntegrationEndpoint.listAPIKeys(configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[APIKeyDTO]>.self)
        return response.data ?? []
    }

    public func createAPIKey(payload: CreateAPIKeyRequest) async throws -> CreateAPIKeyResponse {
        let endpoint = IntegrationEndpoint.createAPIKey(payload: payload, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<CreateAPIKeyResponse>.self)
        guard let data = response.data else { throw NetworkError.underlying("Failed to create API key") }
        return data
    }

    public func revokeAPIKey(id: UUID) async throws {
        let endpoint = IntegrationEndpoint.revokeAPIKey(id: id, configuration: apiConfiguration)
        _ = try await apiClient.request(endpoint, responseType: EmptyResponse.self)
    }

    public func listWebhooks() async throws -> [WebhookSubscriptionDTO] {
        let endpoint = IntegrationEndpoint.listWebhooks(configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[WebhookSubscriptionDTO]>.self)
        return response.data ?? []
    }

    public func createWebhook(payload: CreateWebhookSubscriptionRequest) async throws -> WebhookSubscriptionDTO {
        let endpoint = IntegrationEndpoint.createWebhook(payload: payload, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<WebhookSubscriptionDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("Failed to create webhook") }
        return data
    }

    public func deleteWebhook(id: UUID) async throws {
        let endpoint = IntegrationEndpoint.deleteWebhook(id: id, configuration: apiConfiguration)
        _ = try await apiClient.request(endpoint, responseType: EmptyResponse.self)
    }

    public func testWebhook(id: UUID) async throws -> WebhookTestResponse {
        let endpoint = IntegrationEndpoint.testWebhook(id: id, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<WebhookTestResponse>.self)
        guard let data = response.data else { throw NetworkError.underlying("Failed to test webhook") }
        return data
    }
}

