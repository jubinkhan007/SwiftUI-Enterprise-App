import Fluent
import SharedModels
import Vapor

/// Read-only notification inbox for the authenticated user within the active org.
struct NotificationController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let notifications = routes.grouped("notifications").grouped(OrgTenantMiddleware())
        notifications.get(use: list)
        notifications.get("unread-count", use: getUnreadCount)
        notifications.post("mark-all-read", use: markAllRead)
        notifications.post("read-all", use: markAllRead)
        notifications.post(":notificationID", "read", use: markRead)
    }

    // MARK: - GET /api/notifications

    @Sendable
    func list(req: Request) async throws -> APIResponse<[NotificationDTO]> {
        let ctx = try req.orgContext
        let unreadOnly = ((try? req.query.get(Bool.self, at: "unread")) ?? false)
        let category = try? req.query.get(String.self, at: "category")
        let type = try? req.query.get(String.self, at: "type")

        var query = NotificationModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$user.$id == ctx.userId)
            .sort(\.$createdAt, .descending)

        if unreadOnly {
            query = query.filter(\.$readAt == nil)
        }

        if let cat = category?.lowercased(), !cat.isEmpty, cat != "all" {
            switch cat {
            case "mentions":
                query = query.filter(\.$type ~~ ["mention", "comment.mention", "message.mention"])
            case "assignments":
                query = query.filter(\.$type ~~ ["task.assigned", "assign", "assignment"])
            case "updates":
                query = query.filter(\.$type ~~ ["task.status_changed", "task.updated", "update", "status"])
            case "messages":
                query = query.filter(\.$type ~~ ["message.received", "chat.message", "message"])
            case "meetings":
                query = query.filter(\.$type ~~ ["meeting.invite", "meeting.started", "call.incoming"])
            default:
                break
            }
        } else if let t = type, !t.isEmpty {
            query = query.filter(\.$type == t)
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

    // MARK: - GET /api/notifications/unread-count

    @Sendable
    func getUnreadCount(req: Request) async throws -> APIResponse<NotificationUnreadCountDTO> {
        let ctx = try req.orgContext
        let total = try await NotificationModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$user.$id == ctx.userId)
            .count()
        let unread = try await NotificationModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$user.$id == ctx.userId)
            .filter(\.$readAt == nil)
            .count()
        return .success(NotificationUnreadCountDTO(count: total, unread: unread))
    }

    // MARK: - POST /api/notifications/mark-all-read

    @Sendable
    func markAllRead(req: Request) async throws -> APIResponse<NotificationBatchReadResponse> {
        let ctx = try req.orgContext
        let unreadRows = try await NotificationModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$user.$id == ctx.userId)
            .filter(\.$readAt == nil)
            .all()

        let now = Date()
        for row in unreadRows {
            row.readAt = now
            try await row.save(on: req.db)
        }

        return .success(NotificationBatchReadResponse(markedCount: unreadRows.count, success: true))
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


