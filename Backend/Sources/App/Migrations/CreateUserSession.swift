import Fluent

/// Creates the `user_sessions` table.
struct CreateUserSession: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user_sessions")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("device_type", .string, .required)
            .field("ip_address", .string, .required)
            .field("user_agent", .string, .required)
            .field("is_revoked", .bool, .required, .custom("DEFAULT false"))
            .field("expires_at", .datetime, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("user_sessions").delete()
    }
}
