import Vapor
import Fluent
import SharedModels

/// Aggregates project metrics daily to track historical trends (e.g. for burndown charts).
public struct DailyStatsAggregator {
    fileprivate static var utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return cal
    }()

    private static func fallbackCategory(for legacy: TaskStatus) -> WorkflowStatusCategory {
        switch legacy {
        case .todo: return .backlog
        case .inProgress, .inReview: return .active
        case .done: return .completed
        case .cancelled: return .cancelled
        }
    }
    
    /// Generates and saves daily stats for a given project and date.
    public static func aggregate(for projectId: UUID, date: Date, db: Database, logger: Logger) async throws {
        let startOfDay = utcCalendar.startOfDay(for: date)
        guard let nextDay = utcCalendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw Abort(.internalServerError, reason: "Failed to compute date range.")
        }
        
        // Fetch all lists for the project
        let lists = try await TaskListModel.query(on: db).filter(\.$project.$id == projectId).all()
        let listIds = lists.compactMap { $0.id }

        // Fetch statuses for the project so analytics remain stable under custom workflow renames.
        let statuses = try await CustomStatusModel.query(on: db)
            .filter(\.$project.$id == projectId)
            .all()
        var categoryByStatusId: [UUID: WorkflowStatusCategory] = [:]
        categoryByStatusId.reserveCapacity(statuses.count)
        for s in statuses {
            if let id = s.id {
                categoryByStatusId[id] = s.category
            }
        }
        
        // Fetch all tasks
        let tasks = try await TaskItemModel.query(on: db)
            .filter(\.$list.$id ~~ listIds)
            .all()
            
        var completedPoints: Double = 0
        var remainingPoints: Double = 0
        var completedTasks: Int = 0
        var createdTasks: Int = 0
        
        for task in tasks {
            guard let createdAt = task.createdAt, createdAt < nextDay else { continue }
            createdTasks += 1

            let storyPoints = Double(task.storyPoints ?? 0)
            let category: WorkflowStatusCategory = {
                if let sid = task.$customStatus.id, let cat = categoryByStatusId[sid] { return cat }
                return fallbackCategory(for: task.status)
            }()

            // Cancelled work is treated as removed scope: it does not contribute to completed/remaining points.
            if category == .cancelled {
                continue
            }

            if let completedAt = task.completedAt, completedAt < nextDay {
                completedTasks += 1
                completedPoints += storyPoints
            } else {
                remainingPoints += storyPoints
            }
        }
        
        // Check if there's already an entry for this day
        let existing = try await ProjectDailyStatsModel.query(on: db)
            .filter(\.$project.$id == projectId)
            .filter(\.$date == startOfDay)
            .first()
            
        if let existing {
            existing.completedPoints = completedPoints
            existing.remainingPoints = remainingPoints
            existing.completedTasks = completedTasks
            existing.createdTasks = createdTasks
            try await existing.save(on: db)
            logger.info("Updated existing stats for project \(projectId) on \(startOfDay)")
        } else {
            let stats = ProjectDailyStatsModel(
                projectId: projectId,
                date: startOfDay,
                remainingPoints: remainingPoints,
                completedPoints: completedPoints,
                completedTasks: completedTasks,
                createdTasks: createdTasks
            )
            try await stats.save(on: db)
            logger.info("Created new stats for project \(projectId) on \(startOfDay)")
        }
    }

    /// Aggregates daily stats for every day in the range `[from, toExclusive)`, with both endpoints UTC-normalized.
    public static func aggregateRange(for projectId: UUID, from: Date, to: Date, db: Database, logger: Logger, maxDays: Int = 366) async throws {
        let start = utcCalendar.startOfDay(for: from)
        let endExclusive = utcCalendar.startOfDay(for: to)
        guard start < endExclusive else { return }

        var days = 0
        var cursor = start
        while cursor < endExclusive {
            days += 1
            if days > maxDays {
                throw Abort(.badRequest, reason: "Date range too large (max \(maxDays) days).")
            }
            try await aggregate(for: projectId, date: cursor, db: db, logger: logger)
            guard let next = utcCalendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
    }

    /// Ensures stats exist for the given range. If `recompute` is true, recomputes every day in range.
    public static func ensureAggregated(for projectId: UUID, from: Date, to: Date, recompute: Bool, db: Database, logger: Logger, maxDays: Int = 366) async throws {
        let start = utcCalendar.startOfDay(for: from)
        let endExclusive = utcCalendar.startOfDay(for: to)
        guard start < endExclusive else { return }

        var days = 0
        var existingByDay: Set<Date> = []
        if !recompute {
            let rows = try await ProjectDailyStatsModel.query(on: db)
                .filter(\.$project.$id == projectId)
                .filter(\.$date >= start)
                .filter(\.$date < endExclusive)
                .all()
            existingByDay = Set(rows.map { utcCalendar.startOfDay(for: $0.date) })
        }

        var cursor = start
        while cursor < endExclusive {
            days += 1
            if days > maxDays {
                throw Abort(.badRequest, reason: "Date range too large (max \(maxDays) days).")
            }
            if recompute || !existingByDay.contains(cursor) {
                try await aggregate(for: projectId, date: cursor, db: db, logger: logger)
            }
            guard let next = utcCalendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
    }
}

/// A Vapor Command to run the aggregation manually or via CRON.
public struct AggregateStatsCommand: AsyncCommand {
    public struct Signature: CommandSignature {
        @Option(name: "days", short: "d", help: "Number of days to (re)compute ending today (UTC). Defaults to 1.")
        var days: Int?

        @Option(name: "project", short: "p", help: "Optional project UUID to aggregate; otherwise aggregates all projects.")
        var project: UUID?

        public init() {}
    }

    public var help: String {
        "Aggregates daily project statistics for burndown charts."
    }

    public func run(using context: CommandContext, signature: Signature) async throws {
        let app = context.application
        let db = app.db
        let logger = app.logger
        
        logger.info("Starting Daily Stats Aggregation...")
        
        let projects: [ProjectModel]
        if let projectId = signature.project {
            projects = try await ProjectModel.query(on: db).filter(\.$id == projectId).all()
        } else {
            projects = try await ProjectModel.query(on: db).all()
        }

        let days = max(1, signature.days ?? 1)
        let now = Date()
        let endDay = DailyStatsAggregator.utcCalendar.startOfDay(for: now)
        guard let endExclusive = DailyStatsAggregator.utcCalendar.date(byAdding: .day, value: 1, to: endDay),
              let start = DailyStatsAggregator.utcCalendar.date(byAdding: .day, value: -(days - 1), to: endDay)
        else {
            throw Abort(.internalServerError, reason: "Failed to compute date range.")
        }
        
        for project in projects {
            guard let id = project.id else { continue }
            do {
                try await DailyStatsAggregator.aggregateRange(for: id, from: start, to: endExclusive, db: db, logger: logger, maxDays: max(366, days))
            } catch {
                logger.error("Failed to aggregate stats for project \(id): \(error)")
            }
        }
        
        logger.info("Daily Stats Aggregation Complete.")
    }
}
