import Fluent
import JWT
import SharedModels
import Vapor

// MARK: - Admin token payload

/// JWT payload used for the web admin panel's HttpOnly cookie session.
/// `kind` distinguishes short-lived access tokens from sliding refresh tokens so
/// one can never be substituted for the other.
struct AdminTokenPayload: JWTPayload {
    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var role: String
    /// "access" or "refresh"
    var kind: String

    var userId: UUID? { UUID(uuidString: subject.value) }

    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}

// MARK: - Session helper

/// Issues admin access/refresh JWTs and writes them as hardened cookies.
enum AdminSession {
    static let accessCookieName = "admin_access"
    static let refreshCookieName = "admin_refresh"

    /// 15-minute access token (plan §5.2).
    static let accessTTL: TimeInterval = 15 * 60
    /// 7-day sliding refresh token.
    static let refreshTTL: TimeInterval = 7 * 24 * 60 * 60

    static func sign(userId: UUID, role: String, kind: String, ttl: TimeInterval, on req: Request) throws -> String {
        let payload = AdminTokenPayload(
            subject: .init(value: userId.uuidString),
            expiration: .init(value: Date().addingTimeInterval(ttl)),
            role: role,
            kind: kind
        )
        return try req.jwt.sign(payload)
    }

    /// Attaches `admin_access` and `admin_refresh` HttpOnly cookies to the response.
    static func attachCookies(to response: Response, access: String, refresh: String, on req: Request) {
        let secure = req.application.environment == .production
        response.cookies[accessCookieName] = HTTPCookies.Value(
            string: access,
            expires: Date().addingTimeInterval(accessTTL),
            maxAge: Int(accessTTL),
            isSecure: secure,
            isHTTPOnly: true,
            sameSite: .strict
        )
        response.cookies[refreshCookieName] = HTTPCookies.Value(
            string: refresh,
            expires: Date().addingTimeInterval(refreshTTL),
            maxAge: Int(refreshTTL),
            isSecure: secure,
            isHTTPOnly: true,
            sameSite: .strict
        )
    }

    /// Expires both cookies (logout).
    static func clearCookies(on response: Response, req: Request) {
        let secure = req.application.environment == .production
        for name in [accessCookieName, refreshCookieName] {
            response.cookies[name] = HTTPCookies.Value(
                string: "",
                expires: Date(timeIntervalSince1970: 0),
                maxAge: 0,
                isSecure: secure,
                isHTTPOnly: true,
                sameSite: .strict
            )
        }
    }
}

// MARK: - Cookie auth middleware

/// Authenticates web-admin requests via the `admin_access` HttpOnly cookie.
/// Falls back to a Bearer token so the same routes remain testable with curl.
struct CookieAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let rawToken: String?
        if let cookie = request.cookies[AdminSession.accessCookieName]?.string, !cookie.isEmpty {
            rawToken = cookie
        } else {
            rawToken = request.headers.bearerAuthorization?.token
        }

        guard let token = rawToken else {
            throw Abort(.unauthorized, reason: "Not authenticated.")
        }

        let payload: AdminTokenPayload
        do {
            payload = try request.jwt.verify(token, as: AdminTokenPayload.self)
        } catch {
            throw Abort(.unauthorized, reason: "Invalid or expired session.")
        }
        guard payload.kind == "access", let userId = payload.userId else {
            throw Abort(.unauthorized, reason: "Invalid session token.")
        }

        request.storage[AuthContextKey.self] = AuthContext(
            method: .jwt,
            userId: userId,
            role: payload.role,
            orgId: nil,
            apiKeyId: nil,
            apiKeyScopes: []
        )
        return try await next.respond(to: request)
    }
}

// MARK: - Super-admin guard

/// Allows the request only if the authenticated user has the platform super-admin flag.
/// Re-reads the flag from the database so a revoked super-admin loses access immediately.
struct SuperAdminMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let auth = try request.authContext
        guard let user = try await UserModel.find(auth.userId, on: request.db) else {
            throw Abort(.unauthorized, reason: "User not found.")
        }
        guard user.isSuperAdmin else {
            throw Abort(.forbidden, reason: "Super-admin access required.")
        }
        request.storage[SuperAdminUserKey.self] = user
        return try await next.respond(to: request)
    }
}

struct SuperAdminUserKey: StorageKey {
    typealias Value = UserModel
}

// MARK: - Org-admin guard

/// Requires the resolved `orgContext` role to be `admin` or `owner`.
/// Must be applied AFTER `OrgTenantMiddleware`.
struct RequireOrgAdminMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let ctx = try request.orgContext
        guard ctx.role == .admin || ctx.role == .owner else {
            throw Abort(.forbidden, reason: "Organization admin access required.")
        }
        return try await next.respond(to: request)
    }
}
