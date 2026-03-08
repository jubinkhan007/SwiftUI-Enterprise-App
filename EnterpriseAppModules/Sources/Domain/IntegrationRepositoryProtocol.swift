import Foundation
import SharedModels

public protocol IntegrationRepositoryProtocol: Sendable {
    func listAPIKeys() async throws -> [APIKeyDTO]
    func createAPIKey(payload: CreateAPIKeyRequest) async throws -> CreateAPIKeyResponse
    func revokeAPIKey(id: UUID) async throws

    func listWebhooks() async throws -> [WebhookSubscriptionDTO]
    func createWebhook(payload: CreateWebhookSubscriptionRequest) async throws -> WebhookSubscriptionDTO
    func deleteWebhook(id: UUID) async throws
    func testWebhook(id: UUID) async throws -> WebhookTestResponse
}

