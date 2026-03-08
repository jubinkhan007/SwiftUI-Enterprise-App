import Vapor
import Fluent

/// Middleware that intercepts `Authorization: Bearer eap_xxxx` tokens, looks up the associated `APIKeyModel`,
/// verifies it isn't revoked or expired, and extracts the OrgId and UserId into the request.
struct APIKeyMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let bearer = request.headers.bearerAuthorization else {
            return try await next.respond(to: request)
        }

        let token = bearer.token
        // Check if it's an API Key (we prefix API Keys with eap_ for Enterprise App API)
        if token.hasPrefix("eap_") {
            try await authenticate(apiKey: token, req: request)
        }

        return try await next.respond(to: request)
    }

    private func authenticate(apiKey: String, req: Request) async throws {
        // Strip the prefix
        let rawKey = String(apiKey.dropFirst(4))
        
        // Find the API key by searching key_prefix if we encoded the ID inside the key,
        // or just brute force since this is MVP. For an enterprise app, the key usually contains the UUID + Secret.
        // Let's assume the key is `<UUID>.<SECRET>`.
        let components = rawKey.split(separator: ".", maxSplits: 1)
        guard components.count == 2, let keyId = UUID(uuidString: String(components[0])) else {
            throw Abort(.unauthorized, reason: "Malformed API key.")
        }
        let secret = String(components[1])

        guard let keyModel = try await APIKeyModel.query(on: req.db)
            .filter(\.$id == keyId)
            .with(\.$organization)
            .with(\.$createdBy)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid API key.")
        }

        if keyModel.isRevoked {
            throw Abort(.unauthorized, reason: "API key has been revoked.")
        }

        if let expiresAt = keyModel.expiresAt, expiresAt < Date() {
            throw Abort(.unauthorized, reason: "API key has expired.")
        }

        do {
            let isMatch = try Bcrypt.verify(secret, created: keyModel.keyHash)
            guard isMatch else { throw Abort(.unauthorized) }
        } catch {
            throw Abort(.unauthorized, reason: "Invalid API key.")
        }

        // Update last used at in background
        let db = req.db
        keyModel.lastUsedAt = Date()
        _ = keyModel.save(on: db).transform(to: ()) // Fire and forget

        // Authenticate the user manually.
        // We inject the API key's creator as the User, and the API key's Org as the org.
        let ctx = OrgContext(userId: keyModel.$createdBy.id, orgId: keyModel.$organization.id, permissions: [])
        req.storage.set(OrgContextStorageKey.self, to: ctx)
        req.auth.login(keyModel.createdBy) // Authenticate the underlying user model
        
        // Store the scopes to check later if needed
        req.storage.set(APIScopesStorageKey.self, to: keyModel.scopes)
    }
}

// Storage key for API Key Scopes
private struct APIScopesStorageKey: StorageKey {
    typealias Value = [String]
}

extension Request {
    /// Gets the API scopes if authenticated via an API Key.
    var apiScopes: [String]? {
        self.storage.get(APIScopesStorageKey.self)
    }
}
