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
        return .success(EmptyResponse())
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
