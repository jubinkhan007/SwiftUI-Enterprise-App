import Fluent
import SharedModels
import Vapor

/// Step 2: Create standard per-project statuses and backfill `task_items.status_id` from legacy `status`.
struct BackfillTaskStatusIds: AsyncMigration {
    func prepare(on database: Database) async throws {
        let logger = database.logger

        let projects = try await ProjectModel.query(on: database).all()
        if projects.isEmpty {
            logger.info("No projects found. Skipping status_id backfill.")
            return
        }

        // Pre-create standard statuses for each project.
        for project in projects {
            guard let projectId = project.id else { continue }

            let existing = try await CustomStatusModel.query(on: database)
                .filter(\.$project.$id == projectId)
                .all()

            var existingByLegacy: [String: CustomStatusModel] = [:]
            for status in existing {
                if let legacy = status.legacyStatus {
                    existingByLegacy[legacy] = status
                }
            }

            let standard = Self.standardStatuses(for: projectId)

            for def in standard {
                if existingByLegacy[def.legacyStatus ?? ""] != nil {
                    continue
                }
                try await def.save(on: database)
            }

            // Enforce at least 1 default per project (choose Todo if none)
            let defaultsCount = try await CustomStatusModel.query(on: database)
                .filter(\.$project.$id == projectId)
                .filter(\.$isDefault == true)
                .count()
            if defaultsCount == 0 {
                if let todo = try await CustomStatusModel.query(on: database)
                    .filter(\.$project.$id == projectId)
                    .filter(\.$legacyStatus == TaskStatus.todo.rawValue)
                    .first()
                {
                    todo.isDefault = true
                    try await todo.save(on: database)
                }
            }
        }

        // Build lookup: projectId -> legacyStatusRaw -> statusId
        let allStatuses = try await CustomStatusModel.query(on: database).all()
        var statusIdByProjectAndLegacy: [UUID: [String: UUID]] = [:]
        for status in allStatuses {
            guard let statusId = status.id, let legacy = status.legacyStatus else { continue }
            let projectId = status.$project.id
            statusIdByProjectAndLegacy[projectId, default: [:]][legacy] = statusId
        }

        let tasks = try await TaskItemModel.query(on: database)
            .with(\.$list) { list in
                list.with(\.$project)
            }
            .all()

        var updated = 0
        var skipped = 0

        for task in tasks {
            if task.$customStatus.id != nil {
                skipped += 1
                continue
            }
            guard let list = task.list else {
                skipped += 1
                continue
            }
            let projectId = list.$project.id
            guard let statusId = statusIdByProjectAndLegacy[projectId]?[task.status.rawValue] else {
                skipped += 1
                continue
            }
            task.$customStatus.id = statusId
            try await task.save(on: database)
            updated += 1
        }

        logger.info("Backfilled status_id on \(updated) tasks. Skipped \(skipped) tasks.")
    }

    func revert(on database: Database) async throws {
        // Keep statuses (revert should not destroy user-defined workflows).
        // Only clear the backfilled foreign keys.
        let tasks = try await TaskItemModel.query(on: database).all()
        for task in tasks {
            task.$customStatus.id = nil
            try await task.save(on: database)
        }
    }

    private static func standardStatuses(for projectId: UUID) -> [CustomStatusModel] {
        let defs: [(TaskStatus, String, Double, WorkflowStatusCategory, Bool, Bool)] = [
            (.todo, "#94A3B8", 0, .backlog, true, false),
            (.inProgress, "#3B82F6", 1000, .active, false, false),
            (.inReview, "#F59E0B", 2000, .active, false, false),
            (.done, "#22C55E", 3000, .completed, false, true),
            (.cancelled, "#64748B", 4000, .cancelled, false, true)
        ]

        return defs.map { legacy, color, pos, category, isDefault, isFinal in
            CustomStatusModel(
                projectId: projectId,
                name: legacy.displayName,
                color: color,
                position: pos,
                category: category,
                isDefault: isDefault,
                isFinal: isFinal,
                isLocked: true,
                legacyStatus: legacy.rawValue
            )
        }
    }
}
