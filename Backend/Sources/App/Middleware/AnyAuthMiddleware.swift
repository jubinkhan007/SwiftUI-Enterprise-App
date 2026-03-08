import Vapor

/// Auth middleware that supports both JWT Bearer tokens and org-bound API keys (`eap_...`).
struct AnyAuthMiddleware: AsyncMiddleware {
    private let jwt = JWTAuthMiddleware()
    private let apiKey = APIKeyAuthMiddleware()

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let token = request.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing authorization token.")
        }

        if token.hasPrefix("eap_") {
            return try await apiKey.respond(to: request, chainingTo: next)
        }
        return try await jwt.respond(to: request, chainingTo: next)
    }
}

