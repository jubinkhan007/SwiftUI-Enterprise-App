import Fluent
import SharedModels
import Vapor

/// Read-only notification inbox for the authenticated user within the active org.
struct NotificationController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let notifications = routes.grouped("notifications").grouped(OrgTenantMiddleware())
        notifications.get(use: list)
        notifications.post(":notificationID", "read", use: markRead)
    }

    // MARK: - GET /api/notifications

    @Sendable
    func list(req: Request) async throws -> APIResponse<[NotificationDTO]> {
        let ctx = try req.orgContext
        let unreadOnly = ((try? req.query.get(Bool.self, at: "unread")) ?? false)

        var query = NotificationModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$user.$id == ctx.userId)
            .sort(\.$createdAt, .descending)

        if unreadOnly {
            query = query.filter(\.$readAt == nil)
        }

        let rows = try await query.limit(50).all()
        let dtos = rows.compactMap { row -> NotificationDTO? in
            guard let id = row.id else { return nil }
            return NotificationDTO(
                id: id,
                userId: row.$user.id,
                orgId: row.$organization.id,
                actorUserId: row.actorUserId,
                entityType: row.entityType,
                entityId: row.entityId,
                type: row.type,
                payloadJson: row.payloadJson,
                readAt: row.readAt,
                createdAt: row.createdAt
            )
        }
        return .success(dtos)
    }

    // MARK: - POST /api/notifications/:notificationID/read

    @Sendable
    func markRead(req: Request) async throws -> APIResponse<NotificationDTO> {
        let ctx = try req.orgContext
        guard let id = req.parameters.get("notificationID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid notification ID.")
        }

        guard let row = try await NotificationModel.query(on: req.db)
            .filter(\.$id == id)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$user.$id == ctx.userId)
            .first()
        else {
            throw Abort(.notFound, reason: "Notification not found.")
        }

        row.readAt = Date()
        try await row.save(on: req.db)

        let dto = NotificationDTO(
            id: try row.requireID(),
            userId: row.$user.id,
            orgId: row.$organization.id,
            actorUserId: row.actorUserId,
            entityType: row.entityType,
            entityId: row.entityId,
            type: row.type,
            payloadJson: row.payloadJson,
            readAt: row.readAt,
            createdAt: row.createdAt
        )
        return .success(dto)
    }
}

