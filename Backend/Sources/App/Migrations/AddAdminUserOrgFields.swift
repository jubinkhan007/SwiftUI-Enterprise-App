import Fluent

/// Admin Panel foundation (users + organizations).
///
/// Registered EARLY — right after the user/org/invite tables exist and before any
/// backfill migration queries `OrganizationModel`/`UserModel`. The Fluent models
/// declare these columns as stored properties, so every SELECT against those models
/// references them; they must exist before any such query runs on a fresh database.
///
///   - `users.is_super_admin`        → platform-level super-admin flag
///   - `organizations.status`        → "active" / "suspended" lifecycle
///   - `organizations.retention_days`→ message auto-purge window (nil = indefinite)
///
/// Note: SQLite only allows one `ADD COLUMN` per `ALTER TABLE`, so each column is
/// added in its own `.update()`.
struct AddAdminUserOrgFields: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("is_super_admin", .bool, .required, .sql(.default(false)))
            .update()

        try await database.schema("organizations")
            .field("status", .string, .required, .sql(.default("active")))
            .update()

        try await database.schema("organizations")
            .field("retention_days", .int)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("is_super_admin")
            .update()

        try await database.schema("organizations")
            .deleteField("status")
            .update()

        try await database.schema("organizations")
            .deleteField("retention_days")
            .update()
    }
}
