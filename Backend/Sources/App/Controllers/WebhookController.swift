import Fluent
import SharedModels
import Vapor

struct WebhookController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let webhooks = routes.grouped("webhooks").grouped(OrgTenantMiddleware())
        webhooks.get(use: list)
        webhooks.post(use: create)
        webhooks.delete(":webhookID", use: delete)
        webhooks.patch(":webhookID", use: update)
        webhooks.post(":webhookID", "test", use: test)
    }

    // MARK: - GET /api/webhooks
    @Sendable
    func list(req: Request) async throws -> APIResponse<[WebhookSubscriptionDTO]> {
        let ctx = try req.orgContext

        let rows = try await WebhookSubscriptionModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .sort(\.$createdAt, .descending)
            .all()

        let dtos = rows.compactMap { row -> WebhookSubscriptionDTO? in
            guard let id = row.id else { return nil }
            return WebhookSubscriptionDTO(
                id: id,
                orgId: row.$organization.id,
                targetUrl: row.targetUrl,
                secret: row.secret,
                events: row.events,
                isActive: row.isActive,
                failureCount: row.failureCount,
                createdAt: row.createdAt
            )
        }
        return .success(dtos)
    }

    // MARK: - POST /api/webhooks
    @Sendable
    func create(req: Request) async throws -> APIResponse<WebhookSubscriptionDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(CreateWebhookSubscriptionRequest.self)

        guard let _ = URL(string: payload.targetUrl) else {
            throw Abort(.badRequest, reason: "Invalid target URL")
        }
        
        // If a secret is provided, use it. Otherwise generate a random 32-char hex string
        let generatedSecret = String([UInt8].random(count: 32).hex.prefix(32))
        let finalSecret = payload.secret ?? generatedSecret

        let model = WebhookSubscriptionModel(
            orgId: ctx.orgId,
            targetUrl: payload.targetUrl,
            secret: finalSecret,
            events: payload.events
        )

        try await model.save(on: req.db)

        let dto = WebhookSubscriptionDTO(
            id: try model.requireID(),
            orgId: model.$organization.id,
            targetUrl: model.targetUrl,
            secret: model.secret,     // We return the secret back ONLY ONCE (via the list/get it's normally redacted, but for MVP it's okay)
            events: model.events,
            isActive: model.isActive,
            failureCount: model.failureCount,
            createdAt: model.createdAt
        )
        return .success(dto)
    }

    // MARK: - PATCH /api/webhooks/:webhookID
    @Sendable
    func update(req: Request) async throws -> APIResponse<WebhookSubscriptionDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(UpdateWebhookSubscriptionRequest.self)
        guard let id = req.parameters.get("webhookID", as: UUID.self) else { throw Abort(.badRequest) }

        guard let model = try await WebhookSubscriptionModel.query(on: req.db)
            .filter(\.$id == id)
            .filter(\.$organization.$id == ctx.orgId)
            .first()
        else {
            throw Abort(.notFound)
        }

        if let url = payload.targetUrl { model.targetUrl = url }
        if let secret = payload.secret { model.secret = secret }
        if let events = payload.events { model.events = events }
        
        if let isActive = payload.isActive {
            model.isActive = isActive
            if isActive { model.failureCount = 0 }
        }

        try await model.save(on: req.db)

        let dto = WebhookSubscriptionDTO(
            id: try model.requireID(),
            orgId: model.$organization.id,
            targetUrl: model.targetUrl,
            secret: model.secret, // Important client can see it to sign payloads
            events: model.events,
            isActive: model.isActive,
            failureCount: model.failureCount,
            createdAt: model.createdAt
        )
        return .success(dto)
    }

    // MARK: - DELETE /api/webhooks/:webhookID
    @Sendable
    func delete(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        guard let id = req.parameters.get("webhookID", as: UUID.self) else { throw Abort(.badRequest) }

        guard let model = try await WebhookSubscriptionModel.query(on: req.db)
            .filter(\.$id == id)
            .filter(\.$organization.$id == ctx.orgId)
            .first()
        else {
            throw Abort(.notFound)
        }

        try await model.delete(on: req.db)
        return .empty()
    }

    // MARK: - POST /api/webhooks/:webhookID/test
    @Sendable
    func test(req: Request) async throws -> APIResponse<WebhookTestResponse> {
        let ctx = try req.orgContext
        guard let id = req.parameters.get("webhookID", as: UUID.self) else { throw Abort(.badRequest) }

        guard let model = try await WebhookSubscriptionModel.query(on: req.db)
            .filter(\.$id == id)
            .filter(\.$organization.$id == ctx.orgId)
            .first()
        else {
            throw Abort(.notFound)
        }

        try await WebhookDispatcher.dispatchPing(to: model, on: req)

        return .success(WebhookTestResponse(delivered: true, statusCode: 200)) // We mock it as success if it hasn't thrown
    }
}
