import Fluent

struct CreateAuditLog: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("audit_logs")
            .id()
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required)
            .field("user_email", .string, .required)
            .field("action", .string, .required)
            .field("resource_type", .string, .required)
            .field("resource_id", .uuid)
            .field("details", .string)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("audit_logs").delete()
    }
}
