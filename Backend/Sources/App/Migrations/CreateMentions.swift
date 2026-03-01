import Fluent
import FluentSQL

struct CreateMentions: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("mentions")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("comment_id", .uuid, .required, .references("comments", "id", onDelete: .cascade))
            .field("task_id", .uuid, .required, .references("task_items", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .create()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_mentions_user_created ON mentions(user_id, created_at)").run()
            try await sql.raw("CREATE UNIQUE INDEX IF NOT EXISTS uq_mentions_user_comment ON mentions(user_id, comment_id)").run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_mentions_user_created").run()
            try await sql.raw("DROP INDEX IF EXISTS uq_mentions_user_comment").run()
        }
        try await database.schema("mentions").delete()
    }
}

