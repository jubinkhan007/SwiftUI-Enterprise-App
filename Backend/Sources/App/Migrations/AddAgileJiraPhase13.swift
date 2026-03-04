import Fluent
import FluentSQL
import SharedModels
import SQLKit

/// Phase 13: Agile / Jira features (backlog, sprints, issue keys, releases, bug fields, epic rollups).
struct AddAgileJiraPhase13: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Projects: issue key prefix
        try await database.schema(ProjectModel.schema)
            .field("issue_key_prefix", .string)
            .update()

        // Sprints: capacity
        try await database.schema(SprintModel.schema)
            .field("capacity", .double)
            .update()

        // Releases table
        try await database.schema(ReleaseModel.schema)
            .id()
            .field("project_id", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("description", .string)
            .field("release_date", .datetime)
            .field("released_at", .datetime)
            .field("status", .string, .required, .sql(.default(ReleaseStatus.unreleased.rawValue)))
            .field("is_locked", .bool, .required, .sql(.default(false)))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // Issue key counters table
        try await database.schema(IssueKeyCounterModel.schema)
            .id()
            .field("project_id", .uuid, .required, .references(ProjectModel.schema, "id", onDelete: .cascade))
            .field("next_number", .int, .required)
            .unique(on: "project_id")
            .create()

        // Task items: backlog/sprint assignment + issue keys + bug fields + epic rollups.
        try await database.schema(TaskItemModel.schema)
            .field("project_id", .uuid)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("sprint_id", .uuid)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("issue_key", .string)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("backlog_position", .double)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("sprint_position", .double)
            .update()

        try await database.schema(TaskItemModel.schema)
            .field("epic_total_points", .int)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("epic_completed_points", .int)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("epic_children_count", .int)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("epic_children_done_count", .int)
            .update()

        try await database.schema(TaskItemModel.schema)
            .field("bug_severity", .string)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("bug_environment", .string)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("affected_version_id", .uuid)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("expected_result", .string)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("actual_result", .string)
            .update()
        try await database.schema(TaskItemModel.schema)
            .field("reproduction_steps", .string)
            .update()

        // Indexes (SQLite-friendly via raw SQL)
        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_tasks_project_backlogpos ON task_items(project_id, backlog_position)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_tasks_project_sprint_sprintpos ON task_items(project_id, sprint_id, sprint_position)").run()
            try await sql.raw("CREATE UNIQUE INDEX IF NOT EXISTS ux_tasks_project_issue_key ON task_items(project_id, issue_key)").run()
        }

        // Backfill: issue_key_prefix if missing (best-effort for SQLite)
        if let sql = database as? SQLDatabase, sql.dialect.name == "sqlite" {
            try await sql.raw("""
            UPDATE projects
            SET issue_key_prefix = upper(substr(replace(name, ' ', ''), 1, 5))
            WHERE issue_key_prefix IS NULL OR issue_key_prefix = ''
            """).run()
        }

        // Backfill: project_id on tasks from list -> project
        if let sql = database as? SQLDatabase {
            try await sql.raw("""
            UPDATE task_items
            SET project_id = (
              SELECT project_id
              FROM task_lists
              WHERE task_lists.id = task_items.list_id
            )
            WHERE project_id IS NULL AND list_id IS NOT NULL
            """).run()

            // Backfill: backlog_position default from existing list position when not in a sprint
            try await sql.raw("""
            UPDATE task_items
            SET backlog_position = position
            WHERE backlog_position IS NULL AND sprint_id IS NULL
            """).run()

            // Backfill: sprint_position default from existing list position when already assigned
            try await sql.raw("""
            UPDATE task_items
            SET sprint_position = position
            WHERE sprint_position IS NULL AND sprint_id IS NOT NULL
            """).run()
        }

        // Backfill: issue keys + counters (Swift-level for sequential per-project keys)
        let projects = try await ProjectModel.query(on: database).all()
        for project in projects {
            guard let projectId = project.id else { continue }
            let prefix = project.issueKeyPrefix ?? IssueKeyService.computePrefix(from: project.name)

            // Ensure prefix persisted for non-SQLite dialects as well
            if project.issueKeyPrefix == nil || project.issueKeyPrefix?.isEmpty == true {
                project.issueKeyPrefix = prefix
                try? await project.save(on: database)
            }

            let tasks = try await TaskItemModel.query(on: database)
                .filter(\.$project.$id == projectId)
                .sort(\.$createdAt, .ascending)
                .sort(\.$id, .ascending)
                .all()

            var next = 1
            for task in tasks {
                if let existing = task.issueKey, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Try to parse suffix; keep the counter above the max.
                    if let suffix = existing.split(separator: "-").last, let n = Int(suffix) {
                        next = max(next, n + 1)
                    }
                    continue
                }
                task.issueKey = "\(prefix)-\(next)"
                next += 1
                try? await task.save(on: database)
            }

            if let counter = try await IssueKeyCounterModel.query(on: database)
                .filter(\.$project.$id == projectId)
                .first()
            {
                counter.nextNumber = max(counter.nextNumber, next)
                try? await counter.save(on: database)
            } else {
                try? await IssueKeyCounterModel(projectId: projectId, nextNumber: next).save(on: database)
            }
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try? await sql.raw("DROP INDEX IF EXISTS idx_tasks_project_backlogpos").run()
            try? await sql.raw("DROP INDEX IF EXISTS idx_tasks_project_sprint_sprintpos").run()
            try? await sql.raw("DROP INDEX IF EXISTS ux_tasks_project_issue_key").run()
        }

        try? await database.schema(ReleaseModel.schema).delete()
        try? await database.schema(IssueKeyCounterModel.schema).delete()

        try? await database.schema(ProjectModel.schema)
            .deleteField("issue_key_prefix")
            .update()
        try? await database.schema(SprintModel.schema)
            .deleteField("capacity")
            .update()

        try? await database.schema(TaskItemModel.schema)
            .deleteField("project_id")
            .deleteField("sprint_id")
            .deleteField("issue_key")
            .deleteField("backlog_position")
            .deleteField("sprint_position")
            .deleteField("epic_total_points")
            .deleteField("epic_completed_points")
            .deleteField("epic_children_count")
            .deleteField("epic_children_done_count")
            .deleteField("bug_severity")
            .deleteField("bug_environment")
            .deleteField("affected_version_id")
            .deleteField("expected_result")
            .deleteField("actual_result")
            .deleteField("reproduction_steps")
            .update()
    }
}

