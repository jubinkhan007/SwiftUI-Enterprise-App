import Fluent

struct CreateDeviceTokens: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(DeviceTokenModel.schema)
            .id()
            .field("user_id", .uuid, .required, .references(UserModel.schema, "id", onDelete: .cascade))
            .field("token", .string, .required)
            .field("platform", .string, .required)
            .field("environment", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "token")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(DeviceTokenModel.schema).delete()
    }
}
