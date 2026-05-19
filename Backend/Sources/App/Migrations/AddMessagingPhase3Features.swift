import Fluent
import FluentSQL

/// Phase 3: reactions, pins, bookmarks, user presence/custom status,
/// and message -> task linkage.
struct AddMessagingPhase3Features: AsyncMigration {
    func prepare(on database: Database) async throws {
        // 1. Reactions
        try await database.schema("message_reactions")
            .id()
            .field("message_id", .uuid, .required, .references("messages", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("emoji", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "message_id", "user_id", "emoji")
            .create()

        // 2. Pins (per-conversation)
        try await database.schema("message_pins")
            .id()
            .field("message_id", .uuid, .required, .references("messages", "id", onDelete: .cascade))
            .field("conversation_id", .uuid, .required, .references("conversations", "id", onDelete: .cascade))
            .field("pinned_by", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .unique(on: "message_id")
            .create()

        // 3. Bookmarks (per-user)
        try await database.schema("message_bookmarks")
            .id()
            .field("message_id", .uuid, .required, .references("messages", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .unique(on: "message_id", "user_id")
            .create()

        // 4. User presence + custom status (one row per user)
        try await database.schema("user_presences")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("state", .string, .required, .sql(.default("offline")))
            .field("custom_status_emoji", .string)
            .field("custom_status_text", .string)
            .field("custom_status_expires_at", .datetime)
            .field("last_heartbeat_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()

        // 5. Message -> task linkage column
        try await database.schema("messages")
            .field("linked_task_id", .uuid, .references("task_items", "id", onDelete: .setNull))
            .update()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_reactions_msg ON message_reactions(message_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_pins_conv ON message_pins(conversation_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_bookmarks_user ON message_bookmarks(user_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_presence_user ON user_presences(user_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_messages_linked_task ON messages(linked_task_id)").run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_reactions_msg").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_pins_conv").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_bookmarks_user").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_presence_user").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_messages_linked_task").run()
        }

        try await database.schema("messages")
            .deleteField("linked_task_id")
            .update()
        try await database.schema("user_presences").delete()
        try await database.schema("message_bookmarks").delete()
        try await database.schema("message_pins").delete()
        try await database.schema("message_reactions").delete()
    }
}
