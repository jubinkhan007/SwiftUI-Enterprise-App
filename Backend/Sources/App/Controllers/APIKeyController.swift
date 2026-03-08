import Fluent
import SharedModels
import Vapor

struct APIKeyController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let keys = routes.grouped("apikeys")
        keys.get(use: list)
        keys.post(use: create)
        keys.delete(":keyID", use: revoke)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<[APIKeyDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.orgSettings)

        let keys = try await APIKeyModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .sort(\.$createdAt, .descending)
            .all()

        return .success(keys.map { $0.toDTO() })
    }

    @Sendable
    func create(req: Request) async throws -> APIResponse<CreateAPIKeyResponse> {
        let ctx = try req.orgContext
        try req.requirePermission(.orgSettings)

        let payload = try req.content.decode(CreateAPIKeyRequest.self)
        let name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw Abort(.badRequest, reason: "API key name is required.")
        }

        let (rawKey, prefix) = Self.generateKey()
        let keyHash = try Bcrypt.hash(rawKey)

        let model = APIKeyModel(
            orgId: ctx.orgId,
            userId: ctx.userId,
            name: name,
            keyHash: keyHash,
            keyPrefix: prefix,
            scopes: payload.scopes.map(\.rawValue),
            expiresAt: payload.expiresAt,
            isRevoked: false
        )
        try await model.save(on: req.db)

        return .success(CreateAPIKeyResponse(rawKey: rawKey, apiKey: model.toDTO()))
    }

    @Sendable
    func revoke(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        try req.requirePermission(.orgSettings)

        guard let id = req.parameters.get("keyID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Missing keyID.")
        }

        guard let key = try await APIKeyModel.query(on: req.db)
            .filter(\.$id == id)
            .filter(\.$organization.$id == ctx.orgId)
            .first()
        else {
            throw Abort(.notFound, reason: "API key not found.")
        }

        key.isRevoked = true
        try await key.save(on: req.db)

        return .success(EmptyResponse())
    }

    private static func generateKey() -> (rawKey: String, prefix: String) {
        let prefix = randomString(length: 8)
        let secret = randomString(length: 32)
        return ("eap_\(prefix)_\(secret)", prefix)
    }

    private static func randomString(length: Int) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var result = String()
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(alphabet.randomElement()!)
        }
        return result
    }
}

