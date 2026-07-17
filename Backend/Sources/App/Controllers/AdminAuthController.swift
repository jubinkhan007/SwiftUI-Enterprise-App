import Fluent
import JWT
import SharedModels
import Vapor

// MARK: - Admin auth DTOs (backend-local)

struct AdminOrgSummary: Content {
    let id: UUID
    let name: String
    let slug: String
    let role: UserRole
}

struct AdminMeResponse: Content {
    let user: UserDTO
    let isSuperAdmin: Bool
    /// Organizations where the user is admin/owner — drives the org-admin portal selector.
    let adminOrgs: [AdminOrgSummary]
}

/// Web admin panel authentication: HttpOnly cookie sessions with a short-lived
/// access token and a sliding refresh token (plan §5). Separate from the mobile
/// Bearer flow in `AuthController` so cookie handling stays isolated.
struct AdminAuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let admin = routes.grouped("admin")
        let auth = admin.grouped("auth")
        // Public
        auth.post("login", use: login)
        auth.post("refresh", use: refresh)
        auth.post("logout", use: logout)
        // Authenticated
        let secured = auth.grouped(CookieAuthMiddleware())
        secured.get("me", use: me)
    }

    // MARK: - POST /api/admin/auth/login

    @Sendable
    func login(req: Request) async throws -> Response {
        let payload = try req.content.decode(LoginRequest.self)

        guard let user = try await UserModel.query(on: req.db)
            .filter(\.$email == payload.email.lowercased())
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }
        guard try Bcrypt.verify(payload.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }

        // Bootstrap super-admins from the SUPER_ADMIN_EMAILS env allowlist.
        try await promoteIfAllowlisted(user, on: req)

        guard let userId = user.id else {
            throw Abort(.internalServerError, reason: "User record missing id.")
        }

        let ip = req.peerAddress?.ipAddress ?? "127.0.0.1"
        let ua = req.headers.first(name: .userAgent) ?? "Admin Portal"
        let expiresAt = Date().addingTimeInterval(AdminSession.refreshTTL)
        
        let session = UserSessionModel(
            userId: userId,
            deviceType: "Admin Portal",
            ipAddress: ip,
            userAgent: ua,
            expiresAt: expiresAt
        )
        try await session.save(on: req.db)
        let sessionId = try session.requireID()

        let body = try await buildMeResponse(for: user, on: req)
        let response = try await body.encodeResponse(for: req)
        let access = try AdminSession.sign(userId: userId, role: user.role.rawValue, kind: "access", sessionId: sessionId, ttl: AdminSession.accessTTL, on: req)
        let refresh = try AdminSession.sign(userId: userId, role: user.role.rawValue, kind: "refresh", sessionId: sessionId, ttl: AdminSession.refreshTTL, on: req)
        AdminSession.attachCookies(to: response, access: access, refresh: refresh, on: req)
        return response
    }

    // MARK: - POST /api/admin/auth/refresh

    @Sendable
    func refresh(req: Request) async throws -> Response {
        guard let raw = req.cookies[AdminSession.refreshCookieName]?.string, !raw.isEmpty else {
            throw Abort(.unauthorized, reason: "No refresh session.")
        }
        let payload: AdminTokenPayload
        do {
            payload = try req.jwt.verify(raw, as: AdminTokenPayload.self)
        } catch {
            throw Abort(.unauthorized, reason: "Refresh session expired.")
        }
        guard payload.kind == "refresh", let userId = payload.userId,
              let user = try await UserModel.find(userId, on: req.db)
        else {
            throw Abort(.unauthorized, reason: "Invalid refresh session.")
        }

        if let oldSessionId = payload.sessionId {
            guard let session = try await UserSessionModel.find(oldSessionId, on: req.db),
                  !session.isRevoked,
                  session.expiresAt > Date() else {
                throw Abort(.unauthorized, reason: "Session has been terminated.")
            }
            session.expiresAt = Date().addingTimeInterval(AdminSession.refreshTTL)
            try await session.save(on: req.db)
        }

        let body = try await buildMeResponse(for: user, on: req)
        let response = try await body.encodeResponse(for: req)
        // Slide the session: re-issue both tokens.
        let access = try AdminSession.sign(userId: userId, role: user.role.rawValue, kind: "access", sessionId: payload.sessionId, ttl: AdminSession.accessTTL, on: req)
        let newRefresh = try AdminSession.sign(userId: userId, role: user.role.rawValue, kind: "refresh", sessionId: payload.sessionId, ttl: AdminSession.refreshTTL, on: req)
        AdminSession.attachCookies(to: response, access: access, refresh: newRefresh, on: req)
        return response
    }

    // MARK: - POST /api/admin/auth/logout

    @Sendable
    func logout(req: Request) async throws -> Response {
        let response = try await APIResponse<EmptyResponse>.empty().encodeResponse(for: req)
        AdminSession.clearCookies(on: response, req: req)
        return response
    }

    // MARK: - GET /api/admin/auth/me

    @Sendable
    func me(req: Request) async throws -> APIResponse<AdminMeResponse> {
        let auth = try req.authContext
        guard let user = try await UserModel.find(auth.userId, on: req.db) else {
            throw Abort(.unauthorized, reason: "User not found.")
        }
        return .success(try await buildMeResponse(for: user, on: req))
    }

    // MARK: - Helpers

    private func buildMeResponse(for user: UserModel, on req: Request) async throws -> AdminMeResponse {
        guard let userId = user.id else {
            throw Abort(.internalServerError, reason: "User record missing id.")
        }
        let memberships = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$user.$id == userId)
            .filter(\.$role ~~ [UserRole.admin, UserRole.owner])
            .with(\.$organization)
            .all()
        let adminOrgs = memberships.map {
            AdminOrgSummary(id: $0.$organization.id, name: $0.organization.name, slug: $0.organization.slug, role: $0.role)
        }
        return AdminMeResponse(user: user.toDTO(), isSuperAdmin: user.isSuperAdmin, adminOrgs: adminOrgs)
    }

    private func promoteIfAllowlisted(_ user: UserModel, on req: Request) async throws {
        guard !user.isSuperAdmin else { return }
        let raw = Environment.get("SUPER_ADMIN_EMAILS") ?? ""
        let allow = raw.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        }
        if allow.contains(user.email.lowercased()) {
            user.isSuperAdmin = true
            try await user.save(on: req.db)
            req.logger.notice("Promoted \(user.email) to super-admin via SUPER_ADMIN_EMAILS allowlist.")
        }
    }
}
