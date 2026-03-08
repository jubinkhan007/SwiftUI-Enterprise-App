import Fluent

struct CreateAPIKeys: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("api_keys")
            .id()
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("user_id", .uuid, .required)
            .field("name", .string, .required)
            .field("key_hash", .string, .required)
            .field("key_prefix", .string, .required)
            .field("scopes", .json, .required)
            .field("last_used_at", .datetime)
            .field("expires_at", .datetime)
            .field("is_revoked", .bool, .required, .custom("DEFAULT 0"))
            .field("created_at", .datetime)
            .unique(on: "org_id", "key_prefix", name: "uq_api_keys_org_prefix")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("api_keys").delete()
    }
}

