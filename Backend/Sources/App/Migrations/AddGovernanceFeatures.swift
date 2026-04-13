import Fluent

/// Adds governance tables and fields:
/// - `organization_join_requests` table for workspace join requests.
/// - `status` column to `conversation_members` for pending/active channel membership.
struct AddGovernanceFeatures: AsyncMigration {
    func prepare(on database: Database) async throws {
        // 1. Add status to conversation_members (default "active" for existing rows)
        try await database.schema("conversation_members")
            .field("status", .string, .required, .sql(.default("active")))
            .update()

        // 2. Create organization_join_requests table
        try await database.schema("organization_join_requests")
            .id()
            .field("organization_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("status", .string, .required, .sql(.default("pending")))
            .field("responded_by", .uuid)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "organization_id", "user_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("organization_join_requests").delete()
        try await database.schema("conversation_members")
            .deleteField("status")
            .update()
    }
}
