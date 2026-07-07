import Fluent
import Vapor
import SharedModels

/// Fluent database model for an Organization (Workspace).
final class OrganizationModel: Model, Content, @unchecked Sendable {
    static let schema = "organizations"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "slug")
    var slug: String

    @OptionalField(key: "description")
    var description: String?

    @Parent(key: "owner_id")
    var owner: UserModel

    /// Lifecycle status: "active" or "suspended".
    @Field(key: "status")
    var status: String

    /// Message retention window in days. `nil` means retain indefinitely.
    @OptionalField(key: "retention_days")
    var retentionDays: Int?

    // SaaS fields
    @OptionalField(key: "subscription_tier")
    var subscriptionTier: String?

    @OptionalField(key: "stripe_customer_id")
    var stripeCustomerId: String?

    @OptionalField(key: "stripe_subscription_id")
    var stripeSubscriptionId: String?

    @OptionalField(key: "subscription_status")
    var subscriptionStatus: String?

    @OptionalField(key: "logo_url")
    var logoUrl: String?

    @OptionalField(key: "brand_color_hex")
    var brandColorHex: String?

    @OptionalField(key: "custom_domain")
    var customDomain: String?

    @OptionalField(key: "allowed_email_domains")
    var allowedEmailDomains: String?

    @OptionalField(key: "sso_enabled")
    var ssoEnabled: Bool?

    @OptionalField(key: "sso_idp_url")
    var ssoIdpUrl: String?

    @OptionalField(key: "sso_entity_id")
    var ssoEntityId: String?

    @OptionalField(key: "sso_certificate")
    var ssoCertificate: String?

    @Children(for: \.$organization)
    var members: [OrganizationMemberModel]

    @Children(for: \.$organization)
    var invites: [OrganizationInviteModel]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        slug: String,
        description: String? = nil,
        ownerId: UUID,
        status: String = "active",
        retentionDays: Int? = nil,
        subscriptionTier: String? = "free",
        stripeCustomerId: String? = nil,
        stripeSubscriptionId: String? = nil,
        subscriptionStatus: String? = nil,
        logoUrl: String? = nil,
        brandColorHex: String? = nil,
        customDomain: String? = nil,
        allowedEmailDomains: String? = nil,
        ssoEnabled: Bool? = false,
        ssoIdpUrl: String? = nil,
        ssoEntityId: String? = nil,
        ssoCertificate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.$owner.id = ownerId
        self.status = status
        self.retentionDays = retentionDays
        self.subscriptionTier = subscriptionTier
        self.stripeCustomerId = stripeCustomerId
        self.stripeSubscriptionId = stripeSubscriptionId
        self.subscriptionStatus = subscriptionStatus
        self.logoUrl = logoUrl
        self.brandColorHex = brandColorHex
        self.customDomain = customDomain
        self.allowedEmailDomains = allowedEmailDomains
        self.ssoEnabled = ssoEnabled
        self.ssoIdpUrl = ssoIdpUrl
        self.ssoEntityId = ssoEntityId
        self.ssoCertificate = ssoCertificate
    }

    /// Convert to the shared DTO for API responses.
    func toDTO(memberCount: Int? = nil) -> OrganizationDTO {
        OrganizationDTO(
            id: id ?? UUID(),
            name: name,
            slug: slug,
            description: description,
            ownerId: $owner.id,
            memberCount: memberCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: status,
            retentionDays: retentionDays,
            subscriptionTier: subscriptionTier,
            stripeCustomerId: stripeCustomerId,
            stripeSubscriptionId: stripeSubscriptionId,
            subscriptionStatus: subscriptionStatus,
            logoUrl: logoUrl,
            brandColorHex: brandColorHex,
            customDomain: customDomain,
            allowedEmailDomains: allowedEmailDomains,
            ssoEnabled: ssoEnabled,
            ssoIdpUrl: ssoIdpUrl,
            ssoEntityId: ssoEntityId,
            ssoCertificate: ssoCertificate
        )
    }
}
