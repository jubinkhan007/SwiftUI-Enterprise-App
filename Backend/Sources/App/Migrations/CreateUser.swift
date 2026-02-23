import Fluent
import SharedModels

/// Creates the `users` table.
struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("email", .string, .required)
            .field("display_name", .string, .required)
            .field("password_hash", .string, .required)
            .field("role", .string, .required, .custom("DEFAULT 'member'"))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "email")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
