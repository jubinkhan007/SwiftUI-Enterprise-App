import Fluent
import SharedModels

struct CreateOrganizationInvite: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("organization_invites")
            .id()
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("email", .string, .required)
            .field("role", .string, .required)
            .field("status", .string, .required)
            .field("invited_by", .uuid, .required)
            .field("expires_at", .datetime, .required)
            .field("created_at", .datetime)
            .unique(on: "org_id", "email", "status")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("organization_invites").delete()
    }
}
