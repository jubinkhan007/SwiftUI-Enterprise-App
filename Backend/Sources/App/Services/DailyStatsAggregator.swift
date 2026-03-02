import Vapor
import Fluent
import SharedModels

/// Aggregates project metrics daily to track historical trends (e.g. for burndown charts).
public struct DailyStatsAggregator {
    
    /// Generates and saves daily stats for a given project and date.
    public static func aggregate(for projectId: UUID, date: Date, db: Database, logger: Logger) async throws {
        // Strip time to just get the date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Fetch all lists for the project
        let lists = try await TaskListModel.query(on: db).filter(\.$project.$id == projectId).all()
        let listIds = lists.compactMap { $0.id }
        
        // Fetch all tasks
        let tasks = try await TaskItemModel.query(on: db)
            .filter(\.$list.$id ~~ listIds)
            .all()
            
        var completedPoints: Double = 0
        var remainingPoints: Double = 0
        var completedTasks: Int = 0
        
        for task in tasks {
            // Task creation is not directly tied to the point calculation here unless we want to track points created
            if task.status == .done || task.status == .cancelled {
                if let completedAt = task.completedAt, completedAt <= date {
                    completedTasks += 1
                    completedPoints += Double(task.storyPoints ?? 0)
                }
            } else {
                // If it's not done/cancelled or if it was done AFTER this date (for retro-active aggregation)
                if let createdAt = task.createdAt, createdAt <= date {
                    if task.completedAt == nil || task.completedAt! > date {
                        remainingPoints += Double(task.storyPoints ?? 0)
                    } else {
                        // It was completed today or earlier
                        completedTasks += 1
                        completedPoints += Double(task.storyPoints ?? 0)
                    }
                }
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
            existing.createdTasks = tasks.count // roughly total created up to that point
            try await existing.save(on: db)
            logger.info("Updated existing stats for project \(projectId) on \(startOfDay)")
        } else {
            let stats = ProjectDailyStatsModel(
                projectId: projectId,
                date: startOfDay,
                remainingPoints: remainingPoints,
                completedPoints: completedPoints,
                completedTasks: completedTasks,
                createdTasks: tasks.count
            )
            try await stats.save(on: db)
            logger.info("Created new stats for project \(projectId) on \(startOfDay)")
        }
    }
}

/// A Vapor Command to run the aggregation manually or via CRON.
public struct AggregateStatsCommand: AsyncCommand {
    public struct Signature: CommandSignature {
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
        
        let projects = try await ProjectModel.query(on: db).all()
        let now = Date()
        
        for project in projects {
            guard let id = project.id else { continue }
            do {
                try await DailyStatsAggregator.aggregate(for: id, date: now, db: db, logger: logger)
            } catch {
                logger.error("Failed to aggregate stats for project \(id): \(error)")
            }
        }
        
        logger.info("Daily Stats Aggregation Complete.")
    }
}
