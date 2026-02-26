import Fluent
import Vapor
import SQLKit

struct AddViewIndexes: AsyncMigration {
    func prepare(on database: any Database) async throws {
        // We use explicit SQL for multi-column indexes since Fluent's builder
        // primarily supports single-column indexes natively via SchemaBuilder.

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_tasks_list_status_pos ON task_items(list_id, status, position)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_tasks_org_assignee_due ON task_items(org_id, assignee_id, due_date)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_tasks_org_updated ON task_items(org_id, updated_at)").run()
        }
    }

    func revert(on database: any Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_tasks_list_status_pos").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_tasks_org_assignee_due").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_tasks_org_updated").run()
        }
    }
}
