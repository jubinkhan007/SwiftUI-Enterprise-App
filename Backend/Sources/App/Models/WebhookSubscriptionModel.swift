import Fluent
import Vapor
import SharedModels

final class WebhookSubscriptionModel: Model, Content, @unchecked Sendable {
    static let schema = "webhook_subscriptions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Field(key: "target_url")
    var targetUrl: String

    @Field(key: "secret")
    var secret: String

    @Field(key: "events")
    var events: [String]

    @Field(key: "is_active")
    var isActive: Bool

    @Field(key: "failure_count")
    var failureCount: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        orgId: UUID,
        targetUrl: String,
        secret: String,
        events: [String],
        isActive: Bool = true,
        failureCount: Int = 0
    ) {
        self.id = id
        self.$organization.id = orgId
        self.targetUrl = targetUrl
        self.secret = secret
        self.events = events
        self.isActive = isActive
        self.failureCount = failureCount
    }

    func toDTO() -> WebhookSubscriptionDTO {
        WebhookSubscriptionDTO(
            id: id ?? UUID(),
            orgId: $organization.id,
            targetUrl: targetUrl,
            secret: secret,
            events: events,
            isActive: isActive,
            failureCount: failureCount,
            createdAt: createdAt
        )
    }
}

