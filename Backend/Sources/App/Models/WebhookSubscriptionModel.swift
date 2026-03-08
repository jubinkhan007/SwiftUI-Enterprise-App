import Fluent
import Vapor
import Foundation

/// Represents a registered Webhook endpoint that listens for internal events (e.g. task.created).
final class WebhookSubscriptionModel: Model, @unchecked Sendable {
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

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        orgId: UUID,
        targetUrl: String,
        secret: String,
        events: [String]
    ) {
        self.id = id
        self.$organization.id = orgId
        self.targetUrl = targetUrl
        self.secret = secret
        self.events = events
        self.isActive = true
        self.failureCount = 0
    }
}
