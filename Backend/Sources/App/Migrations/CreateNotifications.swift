import Fluent
import FluentSQL

struct CreateNotifications: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("notifications")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("actor_user_id", .uuid, .required)
            .field("entity_type", .string, .required)
            .field("entity_id", .uuid, .required)
            .field("type", .string, .required)
            .field("payload_json", .string)
            .field("read_at", .datetime)
            .field("created_at", .datetime)
            .create()

        // Deduplication: one active (unread) notification per user/entity/type.
        // SQLite supports partial indexes; Fluent doesn't model them, so we use raw SQL.
        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_notifications_org_user ON notifications(org_id, user_id)").run()
            try await sql.raw(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_unread_dedupe ON notifications(user_id, entity_type, entity_id, type) WHERE read_at IS NULL"
            ).run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_notifications_user_created").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_notifications_org_user").run()
            try await sql.raw("DROP INDEX IF EXISTS uq_notifications_unread_dedupe").run()
        }
        try await database.schema("notifications").delete()
    }
}

