import Fluent
import FluentSQL

/// Phase 4-B (Calls): SFU room sessions, per-user participant state,
/// optional post-call records, and APNs VoIP device tokens.
struct CreateCalls: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("call_sessions")
            .id()
            .field("conversation_id", .uuid, .required, .references("conversations", "id", onDelete: .cascade))
            .field("meeting_id", .uuid, .references("meetings", "id", onDelete: .setNull))
            .field("host_id", .uuid, .required, .references("users", "id", onDelete: .restrict))
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("status", .string, .required, .sql(.default("initiated")))
            .field("room_name", .string, .required)
            .field("has_video", .bool, .required, .sql(.default(true)))
            .field("is_locked", .bool, .required, .sql(.default(false)))
            .field("provider", .string, .required, .sql(.default("livekit")))
            .field("started_at", .datetime)
            .field("ended_at", .datetime)
            .field("updated_at", .datetime)
            .create()

        try await database.schema("call_participants")
            .id()
            .field("call_session_id", .uuid, .required, .references("call_sessions", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("role", .string, .required, .sql(.default("participant")))
            .field("status", .string, .required, .sql(.default("invited")))
            .field("is_audio_muted", .bool, .required, .sql(.default(false)))
            .field("is_video_muted", .bool, .required, .sql(.default(false)))
            .field("is_screen_sharing", .bool, .required, .sql(.default(false)))
            .field("joined_at", .datetime)
            .field("left_at", .datetime)
            .field("created_at", .datetime)
            .unique(on: "call_session_id", "user_id")
            .create()

        try await database.schema("call_records")
            .id()
            .field("call_session_id", .uuid, .required, .references("call_sessions", "id", onDelete: .cascade))
            .field("recording_url", .string)
            .field("summary_url", .string)
            .field("duration_secs", .int)
            .field("created_at", .datetime)
            .create()

        try await database.schema("voip_device_tokens")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("device_token", .string, .required)
            .field("bundle_id", .string, .required)
            .field("environment", .string, .required, .sql(.default("sandbox")))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "device_token")
            .create()

        if let sql = database as? SQLDatabase {
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_call_sessions_conv ON call_sessions(conversation_id, started_at)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_call_sessions_org_status ON call_sessions(org_id, status)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_call_sessions_meeting ON call_sessions(meeting_id)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_call_participants_user ON call_participants(user_id, status)").run()
            try await sql.raw("CREATE INDEX IF NOT EXISTS idx_voip_tokens_user ON voip_device_tokens(user_id)").run()
        }
    }

    func revert(on database: Database) async throws {
        if let sql = database as? SQLDatabase {
            try await sql.raw("DROP INDEX IF EXISTS idx_voip_tokens_user").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_call_participants_user").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_call_sessions_meeting").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_call_sessions_org_status").run()
            try await sql.raw("DROP INDEX IF EXISTS idx_call_sessions_conv").run()
        }
        try await database.schema("voip_device_tokens").delete()
        try await database.schema("call_records").delete()
        try await database.schema("call_participants").delete()
        try await database.schema("call_sessions").delete()
    }
}
