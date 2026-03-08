import Fluent
import Vapor

public struct CreateAPIKeys: AsyncMigration {
    public func prepare(on database: Database) async throws {
        try await database.schema(APIKeyModel.schema)
            .id()
            .field("org_id", .uuid, .required, .references(OrganizationModel.schema, "id", onDelete: .cascade))
            .field("user_id", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
            .field("name", .string, .required)
            .field("key_hash", .string, .required)
            .field("key_prefix", .string, .required)
            .field("scopes", .array(of: .string), .required)
            .field("last_used_at", .datetime)
            .field("expires_at", .datetime)
            .field("is_revoked", .bool, .required, .sql(.default(false)))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema(APIKeyModel.schema).delete()
    }
}
