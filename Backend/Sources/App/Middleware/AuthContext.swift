import Vapor

enum AuthMethod: Sendable {
    case jwt
    case apiKey
}

struct AuthContext: Sendable {
    let method: AuthMethod
    let userId: UUID
    let role: String?
    let orgId: UUID?
    let apiKeyId: UUID?
    let apiKeyScopes: Set<String>
}

struct AuthContextKey: StorageKey {
    typealias Value = AuthContext
}

extension Request {
    var authContext: AuthContext {
        get throws {
            guard let ctx = storage[AuthContextKey.self] else {
                throw Abort(.unauthorized, reason: "Not authenticated.")
            }
            return ctx
        }
    }
}

