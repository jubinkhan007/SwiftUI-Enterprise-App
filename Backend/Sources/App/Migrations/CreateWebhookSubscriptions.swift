import Fluent

struct CreateWebhookSubscriptions: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("webhook_subscriptions")
            .id()
            .field("org_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("target_url", .string, .required)
            .field("secret", .string, .required)
            .field("events", .json, .required)
            .field("is_active", .bool, .required, .custom("DEFAULT 1"))
            .field("failure_count", .int, .required, .custom("DEFAULT 0"))
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("webhook_subscriptions").delete()
    }
}

