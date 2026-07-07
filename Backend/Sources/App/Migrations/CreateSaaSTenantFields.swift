import Fluent

struct CreateSaaSTenantFields: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("organizations")
            .field("subscription_tier", .string)
            .field("stripe_customer_id", .string)
            .field("stripe_subscription_id", .string)
            .field("subscription_status", .string)
            .field("logo_url", .string)
            .field("brand_color_hex", .string)
            .field("custom_domain", .string)
            .field("allowed_email_domains", .string)
            .field("sso_enabled", .bool)
            .field("sso_idp_url", .string)
            .field("sso_entity_id", .string)
            .field("sso_certificate", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("organizations")
            .deleteField("subscription_tier")
            .deleteField("stripe_customer_id")
            .deleteField("stripe_subscription_id")
            .deleteField("subscription_status")
            .deleteField("logo_url")
            .deleteField("brand_color_hex")
            .deleteField("custom_domain")
            .deleteField("allowed_email_domains")
            .deleteField("sso_enabled")
            .deleteField("sso_idp_url")
            .deleteField("sso_entity_id")
            .deleteField("sso_certificate")
            .update()
    }
}
