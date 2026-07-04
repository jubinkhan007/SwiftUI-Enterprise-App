import Fluent
import FluentSQL

struct CreateTimeLogsTable: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("time_logs")
            .id()
            .field("task_id", .uuid, .required, .references("task_items", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("hours_logged", .double, .required)
            .field("logged_at", .datetime, .required)
            .field("description", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_time_logs_task_logged ON time_logs(task_id, logged_at)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_time_logs_org_task ON time_logs(org_id, task_id)").run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_time_logs_task_logged").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_time_logs_org_task").run()
        }
        try await database.schema("time_logs").delete()
    }
}
