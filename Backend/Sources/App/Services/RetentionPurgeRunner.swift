import Fluent
import NIOCore
import Vapor

/// Periodic background runner that enforces per-organization message retention.
///
/// Tick: every hour. For each organization with `retention_days` set, permanently
/// deletes messages whose `created_at` is older than the retention window. Orgs
/// with `retention_days == nil` retain messages indefinitely.
actor RetentionPurgeRunner {
    static let tickInterval: TimeInterval = 60 * 60  // hourly

    private weak var application: Application?
    private var task: RepeatedTask?

    init(application: Application) {
        self.application = application
    }

    func start() {
        guard let app = application else { return }
        guard task == nil else { return }
        task = app.eventLoopGroup.next().scheduleRepeatedAsyncTask(
            initialDelay: .seconds(120),
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
        app.logger.info("RetentionPurgeRunner started.")
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func tick() async {
        guard let app = application else { return }
        do {
            try await purge(app: app, db: app.db)
        } catch {
            app.logger.warning("RetentionPurgeRunner tick failed: \(error)")
        }
    }

    /// Purges expired messages for every org with a retention policy.
    /// Returns the total number of messages deleted (used by the on-demand endpoint).
    @discardableResult
    func purge(app: Application, db: Database) async throws -> Int {
        let orgs = try await OrganizationModel.query(on: db)
            .filter(\.$retentionDays != nil)
            .all()

        var totalDeleted = 0
        for org in orgs {
            guard let orgId = org.id, let days = org.retentionDays, days > 0 else { continue }
            let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)

            // Collect conversation ids for this org, then hard-delete old messages.
            let conversations = try await ConversationModel.query(on: db)
                .filter(\.$organization.$id == orgId)
                .all()
            let convIds = conversations.compactMap { $0.id }
            guard !convIds.isEmpty else { continue }

            let expired = try await MessageModel.query(on: db)
                .filter(\.$conversation.$id ~~ convIds)
                .filter(\.$createdAt < cutoff)
                .all()
            for message in expired {
                try await message.delete(force: true, on: db)
            }
            if !expired.isEmpty {
                totalDeleted += expired.count
                app.logger.info("RetentionPurge: deleted \(expired.count) messages for org \(orgId) (>\(days)d).")
            }
        }
        return totalDeleted
    }
}

// MARK: - Application storage

extension Application {
    private struct RetentionPurgeRunnerKey: StorageKey {
        typealias Value = RetentionPurgeRunner
    }

    var retentionPurgeRunner: RetentionPurgeRunner {
        if let existing = storage[RetentionPurgeRunnerKey.self] {
            return existing
        }
        let runner = RetentionPurgeRunner(application: self)
        storage[RetentionPurgeRunnerKey.self] = runner
        return runner
    }
}
