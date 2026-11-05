import Fluent
import Vapor
import SharedModels

/// Controller managing user login session listing and revocation.
struct UserSessionController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // Registered in routes.swift directly
    }

    // MARK: - Client Handlers

    @Sendable
    func listMySessions(req: Request) async throws -> APIResponse<[UserSessionDTO]> {
        let auth = try req.authContext
        let sessions = try await UserSessionModel.query(on: req.db)
            .filter(\.$user.$id == auth.userId)
            .filter(\.$isRevoked == false)
            .filter(\.$expiresAt > Date())
            .sort(\.$createdAt, .descending)
            .all()

        let dtos = sessions.map { $0.toDTO() }
        return .success(dtos)
    }

    @Sendable
    func revokeMySession(req: Request) async throws -> APIResponse<EmptyResponse> {
        let auth = try req.authContext
        let sessionID = try req.parameters.require("sessionID", as: UUID.self)

        guard let session = try await UserSessionModel.query(on: req.db)
            .filter(\.$id == sessionID)
            .filter(\.$user.$id == auth.userId)
            .first() else {
            throw Abort(.notFound, reason: "Session not found.")
        }

        session.isRevoked = true
        try await session.save(on: req.db)

        // Record in organization audit logs if an X-Org-Id header is present or for the user's memberships.
        await logSessionRevocation(req: req, actorId: auth.userId, session: session, details: "Revoked session (\(session.deviceType), \(session.ipAddress))")

        return .success(EmptyResponse())
    }

    // MARK: - Admin Handlers

    @Sendable
    func listUserSessions(req: Request) async throws -> APIResponse<[UserSessionDTO]> {
        let userID = try req.parameters.require("userID", as: UUID.self)
        let sessions = try await UserSessionModel.query(on: req.db)
            .filter(\.$user.$id == userID)
            .sort(\.$createdAt, .descending)
            .all()

        let dtos = sessions.map { $0.toDTO() }
        return .success(dtos)
    }

    @Sendable
    func forceRevokeSession(req: Request) async throws -> APIResponse<EmptyResponse> {
        let sessionID = try req.parameters.require("sessionID", as: UUID.self)
        guard let session = try await UserSessionModel.find(sessionID, on: req.db) else {
            throw Abort(.notFound, reason: "Session not found.")
        }

        session.isRevoked = true
        try await session.save(on: req.db)

        let actorId = (try? req.authContext.userId) ?? session.$user.id
        await logSessionRevocation(req: req, actorId: actorId, session: session, details: "Admin force-revoked session (\(session.deviceType), \(session.ipAddress))")

        return .success(EmptyResponse())
    }

    private func logSessionRevocation(req: Request, actorId: UUID, session: UserSessionModel, details: String) async {
        let sessionId = session.id
        if let headerOrg = req.headers.first(name: "X-Org-Id"),
           let orgId = UUID(uuidString: headerOrg) {
            _ = try? await AuditLogModel.log(
                on: req.db,
                orgId: orgId,
                userId: actorId,
                userEmail: "",
                action: "session.revoked",
                resourceType: "session",
                resourceId: sessionId,
                details: details,
                app: req.application
            )
            return
        }
        let memberships = (try? await OrganizationMemberModel.query(on: req.db)
            .filter(\.$user.$id == session.$user.id)
            .all()) ?? []
        for m in memberships {
            _ = try? await AuditLogModel.log(
                on: req.db,
                orgId: m.$organization.id,
                userId: actorId,
                userEmail: "",
                action: "session.revoked",
                resourceType: "session",
                resourceId: sessionId,
                details: details,
                app: req.application
            )
        }
    }
}

// MARK: - Model Mapping Helper
extension UserSessionModel {
    func toDTO() -> UserSessionDTO {
        UserSessionDTO(
            id: id ?? UUID(),
            userId: $user.id,
            deviceType: deviceType,
            ipAddress: ipAddress,
            userAgent: userAgent,
            isRevoked: isRevoked,
            expiresAt: expiresAt,
            createdAt: createdAt
        )
    }
}
