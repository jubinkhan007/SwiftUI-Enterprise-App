import Fluent
import NIOCore
import SharedModels
import Vapor

/// Periodic background runner that dispatches scheduled messages and fires reminders.
///
/// Tick: every 60 s. Scans:
/// - `scheduled_messages WHERE status='scheduled' AND scheduled_for <= now`
///   → claim by setting status='sending', then dispatch via the same code path
///     as `MessageController.sendMessage` so notifications/mentions/realtime
///     all fire correctly.
/// - `reminders WHERE status='pending' AND remind_at <= now` → emit a
///   `NotificationModel(type='reminder.fired')` and set status='fired'.
actor ProductivityRunner {
    static let tickInterval: TimeInterval = 60

    private weak var application: Application?
    private var task: RepeatedTask?

    init(application: Application) {
        self.application = application
    }

    func start() {
        guard let app = application else { return }
        guard task == nil else { return }
        task = app.eventLoopGroup.next().scheduleRepeatedAsyncTask(
            initialDelay: .seconds(20),
            delay: .seconds(Int64(Self.tickInterval))
        ) { [weak self] _ in
            guard let self else {
                return app.eventLoopGroup.next().makeSucceededFuture(())
            }
            let promise = app.eventLoopGroup.next().makePromise(of: Void.self)
            Task {
                await self.tick()
                promise.succeed(())
            }
            return promise.futureResult
        }
        app.logger.info("ProductivityRunner started.")
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func tick() async {
        guard let app = application else { return }
        do {
            try await dispatchDueScheduledMessages(app: app, db: app.db)
            try await fireDueReminders(app: app, db: app.db)
        } catch {
            app.logger.warning("ProductivityRunner tick failed: \(error)")
        }
    }

    // MARK: - Scheduled messages

    func dispatchDueScheduledMessages(app: Application, db: Database) async throws {
        let now = Date()
        let due = try await ScheduledMessageModel.query(on: db)
            .filter(\.$status == "scheduled")
            .filter(\.$scheduledFor <= now)
            .limit(50)
            .all()

        for row in due {
            // Claim: only proceed if we successfully flip scheduled -> sending.
            let claimed = try await claimForSending(row: row, on: db)
            guard claimed else { continue }

            do {
                let messageId = try await Self.dispatchScheduled(row: row, app: app, db: db)
                row.sentMessageId = messageId
                row.status = "sent"
                try await row.save(on: db)
                broadcastUser(app: app, row: row, type: "scheduled_message.sent")
            } catch {
                row.status = "failed"
                row.error = String(describing: error)
                try? await row.save(on: db)
                broadcastUser(app: app, row: row, type: "scheduled_message.failed")
            }
        }
    }

    private func claimForSending(row: ScheduledMessageModel, on db: Database) async throws -> Bool {
        // Re-fetch and double-check status before flipping. SQLite has no row-locking
        // primitive, but the runner is single-process so this is sufficient.
        guard let fresh = try await ScheduledMessageModel.find(row.id, on: db),
              fresh.status == "scheduled" else {
            return false
        }
        fresh.status = "sending"
        try await fresh.save(on: db)
        // Mirror back onto the in-memory row.
        row.status = "sending"
        return true
    }

    /// Shared dispatch logic used by both the runner and the "send-now" endpoint.
    /// Returns the new message id on success.
    static func dispatchScheduled(row: ScheduledMessageModel, app: Application, db: Database) async throws -> UUID {
        // 1. Verify the user is still a member of the conversation.
        let isMember = try await ConversationMemberModel.query(on: db)
            .filter(\.$conversation.$id == row.$conversation.id)
            .filter(\.$user.$id == row.$user.id)
            .count() > 0
        guard isMember else {
            throw Abort(.forbidden, reason: "Sender is no longer a member of the conversation.")
        }

        // 2. Persist as a real MessageModel.
        let message = MessageModel(
            conversationId: row.$conversation.id,
            senderId: row.$user.id,
            body: row.body,
            messageType: row.messageType,
            parentId: row.$parent.id
        )
        try await message.save(on: db)

        // 3. Update conversation lastMessageAt + sender's read state.
        if let conv = try await ConversationModel.find(row.$conversation.id, on: db) {
            conv.lastMessageAt = message.createdAt ?? Date()
            try await conv.save(on: db)
        }
        if let membership = try await ConversationMemberModel.query(on: db)
            .filter(\.$conversation.$id == row.$conversation.id)
            .filter(\.$user.$id == row.$user.id)
            .first() {
            membership.lastReadAt = message.createdAt ?? Date()
            membership.lastReadMessageId = message.id
            membership.lastSeenAt = Date()
            try await membership.save(on: db)
        }

        // 4. Broadcast `message.new` to the conversation channel so recipients pick it up.
        guard let messageId = message.id else {
            throw Abort(.internalServerError, reason: "Saved message has no id.")
        }
        RealtimeBroadcaster.broadcast(
            app: app,
            orgId: row.$organization.id,
            channels: ["conversation:\(row.$conversation.id.uuidString)"],
            type: "message.new",
            entityId: messageId,
            payload: [
                "conversationId": row.$conversation.id.uuidString,
                "messageId": messageId.uuidString,
                "senderId": row.$user.id.uuidString,
                "parentId": row.$parent.id?.uuidString ?? "",
                "scheduledMessageId": (row.id?.uuidString ?? "")
            ]
        )

        return messageId
    }

    // MARK: - Reminders

    func fireDueReminders(app: Application, db: Database) async throws {
        let now = Date()
        let due = try await ReminderModel.query(on: db)
            .filter(\.$status == "pending")
            .filter(\.$remindAt <= now)
            .limit(100)
            .all()

        for row in due {
            guard let id = row.id else { continue }
            // Notification
            let payload: [String: String] = [
                "reminderId": id.uuidString,
                "body": row.body,
                "sourceType": row.sourceType ?? "",
                "sourceId": row.sourceId?.uuidString ?? ""
            ]
            let payloadJson = try? String(
                data: JSONSerialization.data(withJSONObject: payload, options: []),
                encoding: .utf8
            )
            let notification = NotificationModel(
                userId: row.$user.id,
                orgId: row.$organization.id,
                actorUserId: row.$user.id,  // self-emitted
                entityType: "reminder",
                entityId: id,
                type: "reminder.fired",
                payloadJson: payloadJson
            )
            do { try await notification.save(on: db) } catch { /* dedup */ }

            row.status = "fired"
            row.firedAt = now
            try? await row.save(on: db)

            RealtimeBroadcaster.broadcast(
                app: app,
                orgId: row.$organization.id,
                channels: ["user:\(row.$user.id.uuidString)"],
                type: "reminder.fired",
                entityId: id,
                payload: payload
            )
        }
    }

    // MARK: - Broadcast helper

    private func broadcastUser(app: Application, row: ScheduledMessageModel, type: String) {
        guard let id = row.id else { return }
        RealtimeBroadcaster.broadcast(
            app: app,
            orgId: row.$organization.id,
            channels: ["user:\(row.$user.id.uuidString)"],
            type: type,
            entityId: id,
            payload: [
                "scheduledMessageId": id.uuidString,
                "conversationId": row.$conversation.id.uuidString,
                "status": row.status,
                "sentMessageId": row.sentMessageId?.uuidString ?? "",
                "error": row.error ?? ""
            ]
        )
    }
}

// MARK: - Application storage

extension Application {
    private struct ProductivityRunnerKey: StorageKey {
        typealias Value = ProductivityRunner
    }

    var productivityRunner: ProductivityRunner {
        if let existing = storage[ProductivityRunnerKey.self] {
            return existing
        }
        let runner = ProductivityRunner(application: self)
        storage[ProductivityRunnerKey.self] = runner
        return runner
    }
}
