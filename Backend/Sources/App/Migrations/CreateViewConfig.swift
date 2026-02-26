import Fluent
import SharedModels
import Vapor

struct CreateViewConfig: AsyncMigration {
    func prepare(on database: any Database) async throws {
        // Enums
        let viewType = try await database.enum("view_type")
            .case("list")
            .case("board")
            .case("calendar")
            .case("timeline")
            .create()

        let viewScope = try await database.enum("view_scope")
            .case("org")
            .case("space")
            .case("project")
            .case("list")
            .create()

        try await database.schema(ViewConfigModel.schema)
            .id()
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("type", viewType, .required)
            .field("filters_json", .string)
            .field("sorts_json", .string)
            .field("schema_version", .int, .required, .sql(.default(1)))
            .field("applies_to", viewScope, .required)
            .field("scope_id", .uuid, .required)
            .field("owner_user_id", .uuid)
            .field("is_public", .bool, .required, .sql(.default(false)))
            .field("is_default", .bool, .required, .sql(.default(false)))
            .field("visible_columns_json", .string)
            .field("board_config_json", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(ViewConfigModel.schema).delete()
        try await database.enum("view_scope").delete()
        try await database.enum("view_type").delete()
    }
}
