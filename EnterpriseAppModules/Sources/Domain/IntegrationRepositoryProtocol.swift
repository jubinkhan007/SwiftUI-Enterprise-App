import Foundation
import SharedModels

public protocol IntegrationRepositoryProtocol: Sendable {
    func listAPIKeys() async throws -> [APIKeyDTO]
    func createAPIKey(payload: CreateAPIKeyRequest) async throws -> CreateAPIKeyResponse
    func rotateAPIKey(id: UUID) async throws -> CreateAPIKeyResponse
    func revokeAPIKey(id: UUID) async throws

    func listWebhooks() async throws -> [WebhookSubscriptionDTO]
    func createWebhook(payload: CreateWebhookSubscriptionRequest) async throws -> WebhookSubscriptionDTO
    func updateWebhook(id: UUID, request: UpdateWebhookSubscriptionRequest) async throws -> WebhookSubscriptionDTO
    func deleteWebhook(id: UUID) async throws
    func testWebhook(id: UUID) async throws -> WebhookTestResponse
}

public extension IntegrationRepositoryProtocol {
    func rotateAPIKey(id: UUID) async throws -> CreateAPIKeyResponse {
        let keys = try await listAPIKeys()
        let existing = keys.first(where: { $0.id == id })
        try await revokeAPIKey(id: id)
        return try await createAPIKey(
            payload: CreateAPIKeyRequest(
                name: existing?.name ?? "Rotated Key",
                scopes: existing?.scopes ?? [.tasksRead, .tasksWrite],
                expiresAt: existing?.expiresAt
            )
        )
    }

    func updateWebhook(id: UUID, request: UpdateWebhookSubscriptionRequest) async throws -> WebhookSubscriptionDTO {
        let hooks = try await listWebhooks()
        guard let existing = hooks.first(where: { $0.id == id }) else {
            throw NSError(domain: "IntegrationRepositoryProtocol", code: 404)
        }
        return WebhookSubscriptionDTO(
            id: existing.id,
            orgId: existing.orgId,
            targetUrl: request.targetUrl ?? existing.targetUrl,
            secret: request.secret ?? existing.secret,
            events: request.events ?? existing.events,
            isActive: request.isActive ?? existing.isActive,
            failureCount: existing.failureCount,
            createdAt: existing.createdAt
        )
    }
}

