import Vapor

/// Auth middleware that supports JWT Bearer tokens, org-bound API keys (`eap_...`),
/// and the web admin panel's HttpOnly `admin_access` session cookie.
///
/// A Bearer header always wins; the cookie is only consulted when no Bearer header is
/// present, so native clients and API-key integrations are unaffected. Cookie sessions are
/// `SameSite=Strict`, which is what keeps this safe against cross-site request forgery.
struct AnyAuthMiddleware: AsyncMiddleware {
    private let jwt = JWTAuthMiddleware()
    private let apiKey = APIKeyAuthMiddleware()
    private let cookie = CookieAuthMiddleware()

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        if let token = request.headers.bearerAuthorization?.token {
            if token.hasPrefix("eap_") {
                return try await apiKey.respond(to: request, chainingTo: next)
            }
            return try await jwt.respond(to: request, chainingTo: next)
        }

        if let session = request.cookies[AdminSession.accessCookieName]?.string, !session.isEmpty {
            return try await cookie.respond(to: request, chainingTo: next)
        }

        throw Abort(.unauthorized, reason: "Missing authorization token.")
    }
}
