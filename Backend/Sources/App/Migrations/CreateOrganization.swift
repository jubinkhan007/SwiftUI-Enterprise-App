import Fluent
import SharedModels

struct CreateOrganization: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("organizations")
            .id()
            .field("name", .string, .required)
            .field("slug", .string, .required)
            .field("description", .string)
            .field("owner_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "slug")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("organizations").delete()
    }
}
