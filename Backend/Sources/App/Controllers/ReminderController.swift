import Fluent
import SharedModels
import Vapor

/// Phase 4 (Productivity): user reminders. Standalone or bound to a source
/// entity (message/task/meeting). Dispatch (status transitions to "fired")
/// is handled by `ProductivityRunner`.
struct ReminderController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let me = routes.grouped("me")
        me.get("reminders", use: list)
        me.post("reminders", use: create)

        let reminders = routes.grouped("reminders")
        reminders.put(":reminderID", use: update)
        reminders.post(":reminderID", "snooze", use: snooze)
        reminders.post(":reminderID", "dismiss", use: dismiss)
        reminders.delete(":reminderID", use: deleteOne)

        // Convenience: bind a reminder to a specific message
        let messages = routes.grouped("messages")
        messages.post(":messageID", "remind", use: createForMessage)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<[ReminderDTO]> {
        let ctx = try req.orgContext
        let statusFilter: String? = try? req.query.get(String.self, at: "status")

        var q = ReminderModel.query(on: req.db)
            .filter(\.$user.$id == ctx.userId)
            .filter(\.$organization.$id == ctx.orgId)
        if let statusFilter { q = q.filter(\.$status == statusFilter) }

        let rows = try await q.sort(\.$remindAt, .ascending).limit(200).all()
        return .success(rows.map(Self.toDTO))
    }

    @Sendable
    func create(req: Request) async throws -> APIResponse<ReminderDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(CreateReminderRequest.self)

        let body = payload.body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, body.count <= 500 else {
            throw Abort(.badRequest, reason: "Body is required and must be 500 chars or fewer.")
        }
        guard payload.remindAt > Date().addingTimeInterval(-30) else {
            throw Abort(.badRequest, reason: "Reminder time must be in the future.")
        }

        let row = ReminderModel(
            userId: ctx.userId,
            orgId: ctx.orgId,
            body: body,
            remindAt: payload.remindAt,
            status: "pending",
            sourceType: payload.sourceType?.rawValue,
            sourceId: payload.sourceId
        )
        try await row.save(on: req.db)
        broadcast(req: req, userId: ctx.userId, orgId: ctx.orgId, row: row, type: "reminder.created")
        return .success(Self.toDTO(row))
    }

    @Sendable
    func createForMessage(req: Request) async throws -> APIResponse<ReminderDTO> {
        let ctx = try req.orgContext
        let messageID = try req.parameters.require("messageID", as: UUID.self)
        let payload = try req.content.decode(CreateMessageReminderRequest.self)

        guard let message = try await MessageModel.query(on: req.db)
            .filter(\.$id == messageID)
            .with(\.$sender)
            .first() else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        try await DraftController.requireConversationMembership(
            conversationId: message.$conversation.id,
            userId: ctx.userId,
            on: req.db
        )
        guard payload.remindAt > Date().addingTimeInterval(-30) else {
            throw Abort(.badRequest, reason: "Reminder time must be in the future.")
        }

        let preview = payload.body?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? String("Reminder: \(message.sender.displayName): \(message.body)".prefix(280))

        let row = ReminderModel(
            userId: ctx.userId,
            orgId: ctx.orgId,
            body: preview,
            remindAt: payload.remindAt,
            status: "pending",
            sourceType: "message",
            sourceId: messageID
        )
        try await row.save(on: req.db)
        broadcast(req: req, userId: ctx.userId, orgId: ctx.orgId, row: row, type: "reminder.created")
        return .success(Self.toDTO(row))
    }

    @Sendable
    func update(req: Request) async throws -> APIResponse<ReminderDTO> {
        let ctx = try req.orgContext
        let reminderID = try req.parameters.require("reminderID", as: UUID.self)
        let payload = try req.content.decode(UpdateReminderRequest.self)

        let row = try await Self.requireOwned(reminderID: reminderID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        if let body = payload.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
            row.body = body
        }
        if let when = payload.remindAt {
            guard when > Date().addingTimeInterval(-30) else {
                throw Abort(.badRequest, reason: "Reminder time must be in the future.")
            }
            row.remindAt = when
            if row.status == "fired" || row.status == "snoozed" {
                row.status = "pending"
                row.firedAt = nil
            }
        }
        try await row.save(on: req.db)
        broadcast(req: req, userId: ctx.userId, orgId: ctx.orgId, row: row, type: "reminder.updated")
        return .success(Self.toDTO(row))
    }

    @Sendable
    func snooze(req: Request) async throws -> APIResponse<ReminderDTO> {
        let ctx = try req.orgContext
        let reminderID = try req.parameters.require("reminderID", as: UUID.self)
        let payload = try req.content.decode(SnoozeReminderRequest.self)
        guard payload.minutes > 0, payload.minutes <= 7 * 24 * 60 else {
            throw Abort(.badRequest, reason: "Snooze must be between 1 minute and 7 days.")
        }

        let row = try await Self.requireOwned(reminderID: reminderID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        row.remindAt = Date().addingTimeInterval(TimeInterval(payload.minutes * 60))
        row.status = "pending"
        row.firedAt = nil
        try await row.save(on: req.db)
        broadcast(req: req, userId: ctx.userId, orgId: ctx.orgId, row: row, type: "reminder.snoozed")
        return .success(Self.toDTO(row))
    }

    @Sendable
    func dismiss(req: Request) async throws -> APIResponse<ReminderDTO> {
        let ctx = try req.orgContext
        let reminderID = try req.parameters.require("reminderID", as: UUID.self)
        let row = try await Self.requireOwned(reminderID: reminderID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        row.status = "dismissed"
        try await row.save(on: req.db)
        broadcast(req: req, userId: ctx.userId, orgId: ctx.orgId, row: row, type: "reminder.dismissed")
        return .success(Self.toDTO(row))
    }

    @Sendable
    func deleteOne(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let reminderID = try req.parameters.require("reminderID", as: UUID.self)
        let row = try await Self.requireOwned(reminderID: reminderID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        try await row.delete(on: req.db)
        return .success(EmptyResponse())
    }

    // MARK: - Helpers

    private func broadcast(req: Request, userId: UUID, orgId: UUID, row: ReminderModel, type: String) {
        guard let id = row.id else { return }
        var payload: [String: String] = [
            "reminderId": id.uuidString,
            "status": row.status
        ]
        if let st = row.sourceType { payload["sourceType"] = st }
        if let sid = row.sourceId { payload["sourceId"] = sid.uuidString }
        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: orgId,
            channels: ["user:\(userId.uuidString)"],
            type: type,
            entityId: id,
            payload: payload
        )
    }

    static func requireOwned(reminderID: UUID, userId: UUID, orgId: UUID, on db: Database) async throws -> ReminderModel {
        guard let row = try await ReminderModel.query(on: db)
            .filter(\.$id == reminderID)
            .filter(\.$user.$id == userId)
            .filter(\.$organization.$id == orgId)
            .first() else {
            throw Abort(.notFound, reason: "Reminder not found.")
        }
        return row
    }

    static func toDTO(_ row: ReminderModel) -> ReminderDTO {
        ReminderDTO(
            id: row.id ?? UUID(),
            userId: row.$user.id,
            orgId: row.$organization.id,
            body: row.body,
            remindAt: row.remindAt,
            status: ReminderStatus(rawValue: row.status) ?? .pending,
            sourceType: row.sourceType.flatMap(ReminderSourceType.init(rawValue:)),
            sourceId: row.sourceId,
            firedAt: row.firedAt,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
