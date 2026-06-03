import Fluent

/// Admin Panel moderation: adds `conversations.is_locked`.
///
/// Registered AFTER `CreateMessaging` (which creates the conversations table).
/// User/organization admin columns live in `AddAdminUserOrgFields`, which must run
/// much earlier — see that migration's note.
struct AddAdminPanelFields: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("conversations")
            .field("is_locked", .bool, .required, .sql(.default(false)))
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("conversations")
            .deleteField("is_locked")
            .update()
    }
}
