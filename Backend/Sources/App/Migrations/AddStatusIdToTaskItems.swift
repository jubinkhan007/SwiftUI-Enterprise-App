import Fluent
import SQLKit
import Vapor

/// Step 1: Add nullable `status_id` to task_items (safe additive phase).
struct AddStatusIdToTaskItems: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(TaskItemModel.schema)
            .field("status_id", .uuid)
            .update()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_tasks_status_id ON task_items(status_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_tasks_list_statusid_pos ON task_items(list_id, status_id, position)").run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_tasks_status_id").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_tasks_list_statusid_pos").run()
        }

        try await database.schema(TaskItemModel.schema)
            .deleteField("status_id")
            .update()
    }
}

