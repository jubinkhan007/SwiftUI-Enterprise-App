import Fluent
import FluentSQL

/// Phase 4 (Meetings slice): scheduling, participants/RSVP/waiting-room,
/// collaborative notes, and post-meeting summary.
struct CreateMeetings: AsyncMigration {
    func prepare(on database: Database) async throws {
        // 1. Meetings
        try await database.schema("meetings")
            .id()
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("conversation_id", .uuid, .references("conversations", "id", onDelete: .setNull))
            .field("meeting_chat_conversation_id", .uuid, .references("conversations", "id", onDelete: .setNull))
            .field("title", .string, .required)
            .field("description", .string)
            .field("agenda", .string)
            .field("scheduled_start_at", .datetime, .required)
            .field("scheduled_end_at", .datetime, .required)
            .field("timezone", .string, .required, .sql(.default("UTC")))
            .field("status", .string, .required, .sql(.default("scheduled")))
            .field("started_at", .datetime)
            .field("ended_at", .datetime)
            .field("cancelled_at", .datetime)
            .field("cancel_reason", .string)
            .field("host_id", .uuid, .required, .references("users", "id", onDelete: .restrict))
            .field("requires_waiting_room", .bool, .required, .sql(.default(true)))
            .field("allow_guests", .bool, .required, .sql(.default(false)))
            .field("join_code", .string, .required)
            .field("access_token", .string, .required)
            .field("provider", .string, .required, .sql(.default("internal")))
            .field("provider_session_id", .string)
            .field("recurrence_rule", .string)
            .field("parent_meeting_id", .uuid, .references("meetings", "id", onDelete: .setNull))
            .field("created_by", .uuid, .required, .references("users", "id", onDelete: .restrict))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "join_code")
            .create()

        // 2. Participants
        try await database.schema("meeting_participants")
            .id()
            .field("meeting_id", .uuid, .required, .references("meetings", "id", onDelete: .cascade))
            .field("user_id", .uuid, .references("users", "id", onDelete: .cascade))
            .field("guest_email", .string)
            .field("guest_name", .string)
            .field("role", .string, .required, .sql(.default("attendee")))
            .field("invite_status", .string, .required, .sql(.default("pending")))
            .field("join_state", .string, .required, .sql(.default("not_joined")))
            .field("waiting_since_at", .datetime)
            .field("joined_at", .datetime)
            .field("left_at", .datetime)
            .field("last_state_changed_at", .datetime)
            .field("invite_token", .string)
            .field("created_at", .datetime)
            .create()

        // 3. Notes (one row per meeting)
        try await database.schema("meeting_notes")
            .id()
            .field("meeting_id", .uuid, .required, .references("meetings", "id", onDelete: .cascade))
            .field("body", .string, .required, .sql(.default("")))
            .field("version", .int, .required, .sql(.default(1)))
            .field("updated_by", .uuid, .references("users", "id", onDelete: .setNull))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "meeting_id")
            .create()

        // 4. Summaries (one or more per meeting; latest wins)
        try await database.schema("meeting_summaries")
            .id()
            .field("meeting_id", .uuid, .required, .references("meetings", "id", onDelete: .cascade))
            .field("summary_text", .string, .required)
            .field("action_items_json", .string)
            .field("highlights_json", .string)
            .field("generated_by", .uuid, .references("users", "id", onDelete: .setNull))
            .field("source", .string, .required, .sql(.default("template")))
            .field("generated_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_meetings_org_start ON meetings(org_id, scheduled_start_at)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_meetings_org_status ON meetings(org_id, status)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_meetings_host ON meetings(host_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_meetings_parent ON meetings(parent_meeting_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_meeting_participants_meeting ON meeting_participants(meeting_id, join_state)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_meeting_participants_user ON meeting_participants(user_id, invite_status)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_meeting_summaries_meeting ON meeting_summaries(meeting_id)").run()

            try await sql.raw(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_meeting_user ON meeting_participants(meeting_id, user_id) WHERE user_id IS NOT NULL"
            ).run()
            try await sql.raw(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_meeting_guest ON meeting_participants(meeting_id, guest_email) WHERE guest_email IS NOT NULL"
            ).run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS uq_meeting_guest").run()
            try await sql.raw("DROP INDEX IF EXISTS uq_meeting_user").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_meeting_summaries_meeting").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_meeting_participants_user").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_meeting_participants_meeting").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_meetings_parent").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_meetings_host").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_meetings_org_status").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_meetings_org_start").run()
        }
        try await database.schema("meeting_summaries").delete()
        try await database.schema("meeting_notes").delete()
        try await database.schema("meeting_participants").delete()
        try await database.schema("meetings").delete()
    }
}
