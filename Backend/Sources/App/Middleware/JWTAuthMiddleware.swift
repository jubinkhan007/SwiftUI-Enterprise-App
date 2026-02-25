import JWT
import Vapor

/// JWT payload for authenticated requests.
struct JWTAuthPayload: JWTPayload {
    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var role: String

    /// The user's UUID, extracted from the subject claim.
    var userId: UUID? {
        UUID(uuidString: subject.value)
    }

    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}

/// Vapor middleware that authenticates requests via a Bearer JWT token.
struct JWTAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let token = request.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing authorization token.")
        }

        do {
            let payload = try request.jwt.verify(token, as: JWTAuthPayload.self)
            request.storage[UserPayloadKey.self] = payload
            return try await next.respond(to: request)
        } catch {
            request.logger.warning("JWT verification failed: \(String(describing: error))")
            throw Abort(.unauthorized, reason: "Invalid or expired token.")
        }
    }
}

// MARK: - Storage Key

/// Key for storing the authenticated JWT payload in `Request.storage`.
struct UserPayloadKey: StorageKey {
    typealias Value = JWTAuthPayload
}

extension Request {
    /// Access the authenticated user's JWT payload.
    var authPayload: JWTAuthPayload {
        get throws {
            guard let payload = storage[UserPayloadKey.self] else {
                throw Abort(.unauthorized, reason: "Not authenticated.")
            }
            return payload
        }
    }
}
