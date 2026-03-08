import Fluent
import SharedModels
import Vapor

struct WebhookController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let webhooks = routes.grouped("webhooks")
        webhooks.get(use: list)
        webhooks.post(use: create)
        webhooks.delete(":webhookID", use: delete)
        webhooks.post(":webhookID", "test", use: test)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<[WebhookSubscriptionDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.orgSettings)

        let subs = try await WebhookSubscriptionModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .sort(\.$createdAt, .descending)
            .all()

        return .success(subs.map { $0.toDTO() })
    }

    @Sendable
    func create(req: Request) async throws -> APIResponse<WebhookSubscriptionDTO> {
        let ctx = try req.orgContext
        try req.requirePermission(.orgSettings)

        let payload = try req.content.decode(CreateWebhookSubscriptionRequest.self)

        let url = payload.targetUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard url.hasPrefix("http://") || url.hasPrefix("https://") else {
            throw Abort(.badRequest, reason: "Webhook URL must start with http:// or https://")
        }

        let events = payload.events.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !events.isEmpty else {
            throw Abort(.badRequest, reason: "At least one event is required.")
        }
        guard events.count <= 50 else {
            throw Abort(.badRequest, reason: "Too many events.")
        }

        let secret = (payload.secret?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? WebhookSigning.randomSecret()

        let model = WebhookSubscriptionModel(
            orgId: ctx.orgId,
            targetUrl: url,
            secret: secret,
            events: events,
            isActive: true,
            failureCount: 0
        )
        try await model.save(on: req.db)

        return .success(model.toDTO())
    }

    @Sendable
    func delete(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        try req.requirePermission(.orgSettings)

        guard let id = req.parameters.get("webhookID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Missing webhookID.")
        }

        guard let sub = try await WebhookSubscriptionModel.query(on: req.db)
            .filter(\.$id == id)
            .filter(\.$organization.$id == ctx.orgId)
            .first()
        else {
            throw Abort(.notFound, reason: "Webhook not found.")
        }

        try await sub.delete(on: req.db)
        return .success(EmptyResponse())
    }

    @Sendable
    func test(req: Request) async throws -> APIResponse<WebhookTestResponse> {
        let ctx = try req.orgContext
        try req.requirePermission(.orgSettings)

        guard let id = req.parameters.get("webhookID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Missing webhookID.")
        }

        guard let sub = try await WebhookSubscriptionModel.query(on: req.db)
            .filter(\.$id == id)
            .filter(\.$organization.$id == ctx.orgId)
            .first()
        else {
            throw Abort(.notFound, reason: "Webhook not found.")
        }

        struct TestData: Content {
            let message: String
        }

        let now = Date()
        let timestampHeader = WebhookSigning.timestampString(for: now)
        let envelope = WebhookDispatcher.Envelope(event: "webhook.test", timestamp: now, data: TestData(message: "ok"))

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(envelope)
        let signature = WebhookSigning.signature(secret: sub.secret, timestamp: timestampHeader, body: body)

        do {
            let response = try await req.client.post(URI(string: sub.targetUrl)) { out in
                out.headers.contentType = .json
                out.headers.replaceOrAdd(name: "X-Webhook-Timestamp", value: timestampHeader)
                out.headers.replaceOrAdd(name: "X-Webhook-Signature", value: "sha256=\(signature)")
                out.body = .init(data: body)
            }

            let ok = response.status.code >= 200 && response.status.code < 300
            return .success(WebhookTestResponse(delivered: ok, statusCode: Int(response.status.code)))
        } catch {
            return .success(WebhookTestResponse(delivered: false, statusCode: nil))
        }
    }
}

