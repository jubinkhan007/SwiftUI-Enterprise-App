import Fluent
import FluentSQL

/// Creates the messaging tables: conversations, conversation_members, messages.
struct CreateMessaging: AsyncMigration {
    func prepare(on database: Database) async throws {
        // 1. Conversations
        try await database.schema("conversations")
            .id()
            .field("type", .string, .required)
            .field("name", .string)
            .field("is_archived", .bool, .required, .sql(.default(false)))
            .field("is_private", .bool, .required, .sql(.default(true)))
            .field("created_by", .uuid, .references("users", "id", onDelete: .setNull))
            .field("last_message_at", .datetime)
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // 2. Conversation Members
        try await database.schema("conversation_members")
            .id()
            .field("conversation_id", .uuid, .required, .references("conversations", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("role", .string, .required, .sql(.default("member")))
            .field("last_read_at", .datetime)
            .field("last_read_message_id", .uuid)
            .field("notification_preference", .string, .required, .sql(.default("all")))
            .field("joined_at", .datetime)
            .unique(on: "conversation_id", "user_id")
            .create()

        // 3. Messages
        try await database.schema("messages")
            .id()
            .field("conversation_id", .uuid, .required, .references("conversations", "id", onDelete: .cascade))
            .field("sender_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("body", .string, .required)
            .field("message_type", .string, .required, .sql(.default("text")))
            .field("parent_id", .uuid, .references("messages", "id", onDelete: .setNull))
            .field("edited_at", .datetime)
            .field("deleted_at", .datetime)
            .field("created_at", .datetime)
            .create()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_conversations_org ON conversations(org_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_conversations_last_msg ON conversations(org_id, last_message_at DESC)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_conv_members_user ON conversation_members(user_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_messages_conv ON messages(conversation_id, created_at DESC)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id)").run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_conversations_org").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_conversations_last_msg").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_conv_members_user").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_messages_conv").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_messages_sender").run()
        }
        try await database.schema("messages").delete()
        try await database.schema("conversation_members").delete()
        try await database.schema("conversations").delete()
    }
}
