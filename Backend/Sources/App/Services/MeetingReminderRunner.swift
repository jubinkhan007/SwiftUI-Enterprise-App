import Fluent
import NIOCore
import Vapor

/// Periodic background runner that emits "starting soon / starting now"
/// notifications and ends meetings that have run past their scheduled end.
///
/// Tick: every 60 s. Cheap to run; each tick scans a small ~1 hour window.
actor MeetingReminderRunner {
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
            initialDelay: .seconds(15),
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
        app.logger.info("MeetingReminderRunner started.")
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func tick() async {
        guard let app = application else { return }
        do {
            try await runOnce(on: app.db, app: app)
        } catch {
            app.logger.warning("MeetingReminderRunner tick failed: \(error)")
        }
    }

    /// Exposed for testing.
    func runOnce(on db: Database, app: Application) async throws {
        let now = Date()

        // 1. Auto-end meetings that overran by > 5 min and were never explicitly ended.
        let staleCutoff = now.addingTimeInterval(-5 * 60)
        let overrunning = try await MeetingModel.query(on: db)
            .filter(\.$status == "in_progress")
            .filter(\.$scheduledEndAt < staleCutoff)
            .all()
        for meeting in overrunning {
            meeting.status = "ended"
            meeting.endedAt = now
            try await meeting.save(on: db)
            if let chatId = meeting.$meetingChatConversation.id,
               let chat = try await ConversationModel.find(chatId, on: db) {
                chat.isArchived = true
                try await chat.save(on: db)
            }
            if let mid = try? meeting.requireID() {
                RealtimeBroadcaster.broadcast(
                    app: app,
                    orgId: meeting.$organization.id,
                    channels: ["meeting:\(mid.uuidString)"],
                    type: "meeting.ended",
                    entityId: mid,
                    payload: ["meetingId": mid.uuidString, "status": "ended", "reason": "auto"]
                )
            }
        }

        // 2. "Starting soon" — meetings starting in 15–16 min (one minute window so we fire once per meeting).
        try await emitReminders(
            on: db,
            app: app,
            now: now,
            windowStart: now.addingTimeInterval(15 * 60),
            windowEnd: now.addingTimeInterval(16 * 60),
            type: "meeting.starting_soon"
        )

        // 3. "Starting now" — meetings starting within the next minute.
        try await emitReminders(
            on: db,
            app: app,
            now: now,
            windowStart: now,
            windowEnd: now.addingTimeInterval(60),
            type: "meeting.starting_now"
        )
    }

    private func emitReminders(
        on db: Database,
        app: Application,
        now: Date,
        windowStart: Date,
        windowEnd: Date,
        type: String
    ) async throws {
        let meetings = try await MeetingModel.query(on: db)
            .filter(\.$status == "scheduled")
            .filter(\.$scheduledStartAt >= windowStart)
            .filter(\.$scheduledStartAt < windowEnd)
            .with(\.$host)
            .all()
        for meeting in meetings {
            guard let mid = try? meeting.requireID() else { continue }

            let participants = try await MeetingParticipantModel.query(on: db)
                .filter(\.$meeting.$id == mid)
                .filter(\.$inviteStatus ~~ ["accepted", "tentative"])
                .all()
            for p in participants {
                guard let uid = p.$user.id else { continue }
                if uid == meeting.$host.id { continue }
                let payload = ["meetingId": mid.uuidString, "title": meeting.title]
                let payloadJson = try? String(
                    data: JSONSerialization.data(withJSONObject: payload, options: []),
                    encoding: .utf8
                )
                let row = NotificationModel(
                    userId: uid,
                    orgId: meeting.$organization.id,
                    actorUserId: meeting.$host.id,
                    entityType: "meeting",
                    entityId: mid,
                    type: type,
                    payloadJson: payloadJson
                )
                do { try await row.save(on: db) }
                catch { /* dedup or transient — skip */ }
            }
        }
    }
}

// MARK: - Application storage

extension Application {
    private struct MeetingReminderRunnerKey: StorageKey {
        typealias Value = MeetingReminderRunner
    }

    var meetingReminderRunner: MeetingReminderRunner {
        get {
            if let existing = storage[MeetingReminderRunnerKey.self] {
                return existing
            }
            let runner = MeetingReminderRunner(application: self)
            storage[MeetingReminderRunnerKey.self] = runner
            return runner
        }
        set {
            storage[MeetingReminderRunnerKey.self] = newValue
        }
    }
}
