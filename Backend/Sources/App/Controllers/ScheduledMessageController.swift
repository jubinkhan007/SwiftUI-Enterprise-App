import Fluent
import SharedModels
import Vapor

/// Phase 4 (Productivity): scheduled send. The actual dispatch happens in
/// `ProductivityRunner`; this controller only manages the queue.
struct ScheduledMessageController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let conversations = routes.grouped("conversations")
        conversations.post(":conversationID", "scheduled-messages", use: create)

        let me = routes.grouped("me")
        me.get("scheduled-messages", use: listMine)

        let scheduled = routes.grouped("scheduled-messages")
        scheduled.put(":scheduledID", use: update)
        scheduled.delete(":scheduledID", use: cancel)
        scheduled.post(":scheduledID", "send-now", use: sendNow)
    }

    @Sendable
    func create(req: Request) async throws -> APIResponse<ScheduledMessageDTO> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let payload = try req.content.decode(CreateScheduledMessageRequest.self)

        try await DraftController.requireConversationMembership(conversationId: conversationID, userId: ctx.userId, on: req.db)

        let body = payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { throw Abort(.badRequest, reason: "Message body cannot be empty.") }
        guard payload.scheduledFor > Date().addingTimeInterval(-30) else {
            throw Abort(.badRequest, reason: "Scheduled time must be in the future.")
        }

        let row = ScheduledMessageModel(
            userId: ctx.userId,
            orgId: ctx.orgId,
            conversationId: conversationID,
            parentId: payload.parentId,
            body: body,
            messageType: payload.messageType ?? "text",
            scheduledFor: payload.scheduledFor
        )
        try await row.save(on: req.db)

        broadcastUserEvent(req: req, userId: ctx.userId, orgId: ctx.orgId, row: row, type: "scheduled_message.created")
        return .success(Self.toDTO(row))
    }

    @Sendable
    func listMine(req: Request) async throws -> APIResponse<[ScheduledMessageDTO]> {
        let ctx = try req.orgContext
        let statusFilter: String? = try? req.query.get(String.self, at: "status")

        var q = ScheduledMessageModel.query(on: req.db)
            .filter(\.$user.$id == ctx.userId)
            .filter(\.$organization.$id == ctx.orgId)
        if let statusFilter { q = q.filter(\.$status == statusFilter) }

        let rows = try await q.sort(\.$scheduledFor, .ascending).limit(200).all()
        return .success(rows.map(Self.toDTO))
    }

    @Sendable
    func update(req: Request) async throws -> APIResponse<ScheduledMessageDTO> {
        let ctx = try req.orgContext
        let scheduledID = try req.parameters.require("scheduledID", as: UUID.self)
        let payload = try req.content.decode(UpdateScheduledMessageRequest.self)

        let row = try await Self.requireOwned(scheduledID: scheduledID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        guard row.status == "scheduled" else {
            throw Abort(.badRequest, reason: "Only scheduled messages can be edited.")
        }
        if let body = payload.body {
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw Abort(.badRequest, reason: "Body cannot be empty.") }
            row.body = trimmed
        }
        if let when = payload.scheduledFor {
            guard when > Date().addingTimeInterval(-30) else {
                throw Abort(.badRequest, reason: "Scheduled time must be in the future.")
            }
            row.scheduledFor = when
        }
        try await row.save(on: req.db)
        broadcastUserEvent(req: req, userId: ctx.userId, orgId: ctx.orgId, row: row, type: "scheduled_message.updated")
        return .success(Self.toDTO(row))
    }

    @Sendable
    func cancel(req: Request) async throws -> APIResponse<ScheduledMessageDTO> {
        let ctx = try req.orgContext
        let scheduledID = try req.parameters.require("scheduledID", as: UUID.self)
        let row = try await Self.requireOwned(scheduledID: scheduledID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        guard row.status == "scheduled" else {
            return .success(Self.toDTO(row))
        }
        row.status = "cancelled"
        try await row.save(on: req.db)
        broadcastUserEvent(req: req, userId: ctx.userId, orgId: ctx.orgId, row: row, type: "scheduled_message.cancelled")
        return .success(Self.toDTO(row))
    }

    @Sendable
    func sendNow(req: Request) async throws -> APIResponse<ScheduledMessageDTO> {
        let ctx = try req.orgContext
        let scheduledID = try req.parameters.require("scheduledID", as: UUID.self)
        let row = try await Self.requireOwned(scheduledID: scheduledID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        guard row.status == "scheduled" else {
            throw Abort(.badRequest, reason: "This message has already been dispatched or cancelled.")
        }

        // Force the runner pattern: flip status to sending, dispatch, then mark sent.
        row.status = "sending"
        try await row.save(on: req.db)

        do {
            let messageID = try await ProductivityRunner.dispatchScheduled(row: row, app: req.application, db: req.db)
            row.sentMessageId = messageID
            row.status = "sent"
            try await row.save(on: req.db)
            broadcastUserEvent(req: req, userId: ctx.userId, orgId: ctx.orgId, row: row, type: "scheduled_message.sent")
        } catch {
            row.status = "failed"
            row.error = String(describing: error)
            try? await row.save(on: req.db)
            broadcastUserEvent(req: req, userId: ctx.userId, orgId: ctx.orgId, row: row, type: "scheduled_message.failed")
            throw error
        }
        return .success(Self.toDTO(row))
    }

    // MARK: - Helpers

    private func broadcastUserEvent(req: Request, userId: UUID, orgId: UUID, row: ScheduledMessageModel, type: String) {
        guard let id = row.id else { return }
        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: orgId,
            channels: ["user:\(userId.uuidString)"],
            type: type,
            entityId: id,
            payload: [
                "scheduledMessageId": id.uuidString,
                "conversationId": row.$conversation.id.uuidString,
                "status": row.status
            ]
        )
    }

    static func requireOwned(scheduledID: UUID, userId: UUID, orgId: UUID, on db: Database) async throws -> ScheduledMessageModel {
        guard let row = try await ScheduledMessageModel.query(on: db)
            .filter(\.$id == scheduledID)
            .filter(\.$user.$id == userId)
            .filter(\.$organization.$id == orgId)
            .first() else {
            throw Abort(.notFound, reason: "Scheduled message not found.")
        }
        return row
    }

    static func toDTO(_ row: ScheduledMessageModel) -> ScheduledMessageDTO {
        ScheduledMessageDTO(
            id: row.id ?? UUID(),
            userId: row.$user.id,
            orgId: row.$organization.id,
            conversationId: row.$conversation.id,
            parentId: row.$parent.id,
            body: row.body,
            messageType: row.messageType,
            scheduledFor: row.scheduledFor,
            status: ScheduledMessageStatus(rawValue: row.status) ?? .scheduled,
            sentMessageId: row.sentMessageId,
            error: row.error,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }
}
