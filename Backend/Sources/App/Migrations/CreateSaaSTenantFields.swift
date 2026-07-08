import Fluent

struct CreateSaaSTenantFields: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("organizations").field("subscription_tier", .string).update()
        try await database.schema("organizations").field("stripe_customer_id", .string).update()
        try await database.schema("organizations").field("stripe_subscription_id", .string).update()
        try await database.schema("organizations").field("subscription_status", .string).update()
        try await database.schema("organizations").field("logo_url", .string).update()
        try await database.schema("organizations").field("brand_color_hex", .string).update()
        try await database.schema("organizations").field("custom_domain", .string).update()
        try await database.schema("organizations").field("allowed_email_domains", .string).update()
        try await database.schema("organizations").field("sso_enabled", .bool).update()
        try await database.schema("organizations").field("sso_idp_url", .string).update()
        try await database.schema("organizations").field("sso_entity_id", .string).update()
        try await database.schema("organizations").field("sso_certificate", .string).update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("organizations").deleteField("subscription_tier").update()
        try await database.schema("organizations").deleteField("stripe_customer_id").update()
        try await database.schema("organizations").deleteField("stripe_subscription_id").update()
        try await database.schema("organizations").deleteField("subscription_status").update()
        try await database.schema("organizations").deleteField("logo_url").update()
        try await database.schema("organizations").deleteField("brand_color_hex").update()
        try await database.schema("organizations").deleteField("custom_domain").update()
        try await database.schema("organizations").deleteField("allowed_email_domains").update()
        try await database.schema("organizations").deleteField("sso_enabled").update()
        try await database.schema("organizations").deleteField("sso_idp_url").update()
        try await database.schema("organizations").deleteField("sso_entity_id").update()
        try await database.schema("organizations").deleteField("sso_certificate").update()
    }
}
