import Fluent
import FluentSQL

/// Phase 4 (Productivity slice): drafts, scheduled-send, templates, reminders.
struct CreateProductivityFeatures: AsyncMigration {
    func prepare(on database: Database) async throws {
        // 1. Drafts
        try await database.schema("message_drafts")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("conversation_id", .uuid, .required, .references("conversations", "id", onDelete: .cascade))
            .field("parent_id", .uuid, .references("messages", "id", onDelete: .cascade))
            .field("body", .string, .required, .sql(.default("")))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // 2. Scheduled messages
        try await database.schema("scheduled_messages")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("conversation_id", .uuid, .required, .references("conversations", "id", onDelete: .cascade))
            .field("parent_id", .uuid, .references("messages", "id", onDelete: .setNull))
            .field("body", .string, .required)
            .field("message_type", .string, .required, .sql(.default("text")))
            .field("scheduled_for", .datetime, .required)
            .field("status", .string, .required, .sql(.default("scheduled")))
            .field("sent_message_id", .uuid)
            .field("error", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // 3. Templates
        try await database.schema("message_templates")
            .id()
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("owner_user_id", .uuid, .references("users", "id", onDelete: .cascade))
            .field("scope", .string, .required)
            .field("name", .string, .required)
            .field("shortcut", .string)
            .field("body", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        // 4. Reminders
        try await database.schema("reminders")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("body", .string, .required)
            .field("remind_at", .datetime, .required)
            .field("status", .string, .required, .sql(.default("pending")))
            .field("source_type", .string)
            .field("source_id", .uuid)
            .field("fired_at", .datetime)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_drafts_user_conv ON message_drafts(user_id, conversation_id)").run()
            try await sql.raw(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_drafts_main ON message_drafts(user_id, conversation_id) WHERE parent_id IS NULL"
            ).run()
            try await sql.raw(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_drafts_thread ON message_drafts(user_id, conversation_id, parent_id) WHERE parent_id IS NOT NULL"
            ).run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_scheduled_status_for ON scheduled_messages(status, scheduled_for)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_scheduled_user ON scheduled_messages(user_id, status)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_templates_org ON message_templates(org_id, scope)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_templates_owner ON message_templates(owner_user_id)").run()
            try await sql.raw(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_template_user_shortcut ON message_templates(owner_user_id, shortcut) WHERE shortcut IS NOT NULL AND scope = 'user'"
            ).run()
            try await sql.raw(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_template_org_shortcut ON message_templates(org_id, shortcut) WHERE shortcut IS NOT NULL AND scope = 'org'"
            ).run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_reminders_status_at ON reminders(status, remind_at)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_reminders_user ON reminders(user_id, status)").run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_reminders_user").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_reminders_status_at").run()
            try await sql.raw("DROP INDEX IF EXISTS uq_template_org_shortcut").run()
            try await sql.raw("DROP INDEX IF EXISTS uq_template_user_shortcut").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_templates_owner").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_templates_org").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_scheduled_user").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_scheduled_status_for").run()
            try await sql.raw("DROP INDEX IF EXISTS uq_drafts_thread").run()
            try await sql.raw("DROP INDEX IF EXISTS uq_drafts_main").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_drafts_user_conv").run()
        }
        try await database.schema("reminders").delete()
        try await database.schema("message_templates").delete()
        try await database.schema("scheduled_messages").delete()
        try await database.schema("message_drafts").delete()
    }
}
