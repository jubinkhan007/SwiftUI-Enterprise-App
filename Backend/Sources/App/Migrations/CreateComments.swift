import Fluent
import FluentSQL

struct CreateComments: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("comments")
            .id()
            .field("task_id", .uuid, .required, .references("task_items", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("body", .string, .required)
            .field("edited_at", .datetime)
            .field("deleted_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_comments_task_created ON comments(task_id, created_at)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_comments_org_task ON comments(org_id, task_id)").run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_comments_task_created").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_comments_org_task").run()
        }
        try await database.schema("comments").delete()
    }
}

