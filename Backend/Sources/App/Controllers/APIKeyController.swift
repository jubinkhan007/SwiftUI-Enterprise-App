import Vapor
import Fluent
import Crypto
import SharedModels

struct APIKeyController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let keys = routes.grouped("api-keys").grouped(OrgTenantMiddleware())
        keys.get(use: list)
        keys.post(use: create)
        keys.delete(":keyID", use: revoke)
    }

    // MARK: - GET /api/api-keys
    @Sendable
    func list(req: Request) async throws -> APIResponse<[APIKeyDTO]> {
        let ctx = try req.orgContext
        let rows = try await APIKeyModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$isRevoked == false)
            .sort(\.$createdAt, .descending)
            .all()

        let dtos = rows.compactMap { row -> APIKeyDTO? in
            guard let id = row.id else { return nil }
            return APIKeyDTO(
                id: id,
                orgId: row.$organization.id,
                userId: row.$createdBy.id,
                name: row.name,
                keyPrefix: row.keyPrefix,
                scopes: row.scopes.compactMap { APIKeyScope(rawValue: $0) },
                lastUsedAt: row.lastUsedAt,
                expiresAt: row.expiresAt,
                isRevoked: row.isRevoked,
                createdAt: row.createdAt
            )
        }
        return .success(dtos)
    }

    // MARK: - POST /api/api-keys
    @Sendable
    func create(req: Request) async throws -> APIResponse<CreateAPIKeyResponse> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(CreateAPIKeyRequest.self)
        
        let keyId = UUID()
        let rawSecret = [UInt8].random(count: 32).hex
        let fullRawKey = "eap_\(keyId.uuidString).\(rawSecret)"
        
        let hashedSecret = try Bcrypt.hash(rawSecret)
        let prefix = String(rawSecret.prefix(8))

        let model = APIKeyModel(
            id: keyId,
            orgId: ctx.orgId,
            createdById: ctx.userId,
            name: payload.name,
            keyHash: hashedSecret,
            keyPrefix: prefix,
            scopes: payload.scopes.map { $0.rawValue },
            expiresAt: payload.expiresAt
        )

        try await model.save(on: req.db)

        let dto = APIKeyDTO(
            id: keyId,
            orgId: model.$organization.id,
            userId: model.$createdBy.id,
            name: model.name,
            keyPrefix: model.keyPrefix,
            scopes: payload.scopes,
            lastUsedAt: model.lastUsedAt,
            expiresAt: model.expiresAt,
            isRevoked: model.isRevoked,
            createdAt: model.createdAt
        )
        
        let responsePayload = CreateAPIKeyResponse(rawKey: fullRawKey, apiKey: dto)
        return .success(responsePayload)
    }

    // MARK: - DELETE /api/api-keys/:keyID
    @Sendable
    func revoke(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        guard let id = req.parameters.get("keyID", as: UUID.self) else { throw Abort(.badRequest) }

        guard let model = try await APIKeyModel.query(on: req.db)
            .filter(\.$id == id)
            .filter(\.$organization.$id == ctx.orgId)
            .first()
        else {
            throw Abort(.notFound)
        }

        model.isRevoked = true
        try await model.save(on: req.db)

        return .empty()
    }
}
