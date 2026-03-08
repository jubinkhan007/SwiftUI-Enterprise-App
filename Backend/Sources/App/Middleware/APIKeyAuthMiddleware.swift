import Fluent
import SharedModels
import Vapor

struct APIKeyAuthMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let raw = req.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing authorization token.")
        }

        guard raw.hasPrefix("eap_") else {
            throw Abort(.unauthorized, reason: "Invalid API key.")
        }

        // Expected format: eap_<UUID>.<SECRET>
        let withoutPrefix = raw.dropFirst(4)
        let parts = withoutPrefix.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let keyId = UUID(uuidString: String(parts[0])) else {
            throw Abort(.unauthorized, reason: "Malformed API key.")
        }
        let secret = String(parts[1])
        guard !secret.isEmpty else {
            throw Abort(.unauthorized, reason: "Malformed API key.")
        }

        guard let key = try await APIKeyModel.query(on: req.db)
            .filter(\.$id == keyId)
            .filter(\.$isRevoked == false)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid API key.")
        }

        if let expiresAt = key.expiresAt, expiresAt <= Date() {
            throw Abort(.unauthorized, reason: "API key expired.")
        }

        guard (try? Bcrypt.verify(secret, created: key.keyHash)) == true else {
            throw Abort(.unauthorized, reason: "Invalid API key.")
        }

        let scopes = Set(key.scopes)
        req.storage[AuthContextKey.self] = AuthContext(
            method: .apiKey,
            userId: key.$createdBy.id,
            role: nil,
            orgId: key.$organization.id,
            apiKeyId: key.id,
            apiKeyScopes: scopes
        )

        // Update last-used timestamp (best-effort).
        key.lastUsedAt = Date()
        try? await key.save(on: req.db)

        // Enforce scopes (authorization) for API-key requests.
        try enforceScopes(req: req, scopes: scopes)

        return try await next.respond(to: req)
    }

    private struct ScopeRequirement {
        let anyOf: Set<APIKeyScope>
    }

    private func enforceScopes(req: Request, scopes: Set<String>) throws {
        if scopes.contains(APIKeyScope.admin.rawValue) { return }

        guard let requirement = requiredScopes(for: req) else {
            throw Abort(.forbidden, reason: "API key is not allowed to access this endpoint.")
        }

        let hasAny = requirement.anyOf.contains { scopes.contains($0.rawValue) }
        guard hasAny else {
            throw Abort(.forbidden, reason: "API key missing required scope.")
        }
    }

    private func requiredScopes(for req: Request) -> ScopeRequirement? {
        let path = req.url.path
        let method = req.method

        if path.hasPrefix("/api/api-keys") {
            return ScopeRequirement(anyOf: [.apiKeysManage])
        }
        if path.hasPrefix("/api/webhooks") {
            return ScopeRequirement(anyOf: [.webhooksManage])
        }

        if path.hasPrefix("/api/tasks") {
            if method == .GET || method == .HEAD {
                return ScopeRequirement(anyOf: [.tasksRead])
            }
            return ScopeRequirement(anyOf: [.tasksWrite])
        }

        if path.hasPrefix("/api/hierarchy") || path.hasPrefix("/api/workflow") {
            return ScopeRequirement(anyOf: [.tasksRead])
        }

        if path.hasPrefix("/api/attachments") {
            if method == .GET || method == .HEAD {
                return ScopeRequirement(anyOf: [.tasksRead])
            }
            return ScopeRequirement(anyOf: [.tasksWrite])
        }

        return nil
    }
}
