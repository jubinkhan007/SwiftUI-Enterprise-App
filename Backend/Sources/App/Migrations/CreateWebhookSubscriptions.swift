import Fluent
import Vapor

public struct CreateWebhookSubscriptions: AsyncMigration {
    public func prepare(on database: Database) async throws {
        try await database.schema(WebhookSubscriptionModel.schema)
            .id()
            .field("org_id", .uuid, .required, .references(OrganizationModel.schema, "id", onDelete: .cascade))
            .field("target_url", .string, .required)
            .field("secret", .string, .required)
            .field("events", .array(of: .string), .required)
            .field("is_active", .bool, .required, .sql(.default(true)))
            .field("failure_count", .int, .required, .sql(.default(0)))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema(WebhookSubscriptionModel.schema).delete()
    }
}
