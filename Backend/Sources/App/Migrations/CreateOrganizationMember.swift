import Fluent
import SharedModels

struct CreateOrganizationMember: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("organization_members")
            .id()
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("role", .string, .required)
            .field("joined_at", .datetime)
            .unique(on: "org_id", "user_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("organization_members").delete()
    }
}
