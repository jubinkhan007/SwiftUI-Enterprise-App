import Fluent

struct AddMessagingPhase2Features: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("conversations")
            .field("description", .string)
            .update()

        try await database.schema("conversations")
            .field("topic", .string)
            .update()

        try await database.schema("conversations")
            .field("owner_id", .uuid, .references("users", "id", onDelete: .setNull))
            .update()

        try await database.schema("conversation_members")
            .field("last_seen_at", .datetime)
            .update()

        try await database.schema("conversation_members")
            .field("is_muted", .bool, .required, .sql(.default(false)))
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("conversation_members")
            .deleteField("last_seen_at")
            .update()

        try await database.schema("conversation_members")
            .deleteField("is_muted")
            .update()

        try await database.schema("conversations")
            .deleteField("description")
            .update()

        try await database.schema("conversations")
            .deleteField("topic")
            .update()

        try await database.schema("conversations")
            .deleteField("owner_id")
            .update()
    }
}
