import Fluent
import Vapor

/// A durable, deduplicated notification row for a user within an org.
final class NotificationModel: Model, Content, @unchecked Sendable {
    static let schema = "notifications"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: UserModel

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Field(key: "actor_user_id")
    var actorUserId: UUID

    @Field(key: "entity_type")
    var entityType: String

    @Field(key: "entity_id")
    var entityId: UUID

    @Field(key: "type")
    var type: String

    @OptionalField(key: "payload_json")
    var payloadJson: String?

    @OptionalField(key: "read_at")
    var readAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userId: UUID,
        orgId: UUID,
        actorUserId: UUID,
        entityType: String,
        entityId: UUID,
        type: String,
        payloadJson: String?,
        readAt: Date? = nil
    ) {
        self.id = id
        self.$user.id = userId
        self.$organization.id = orgId
        self.actorUserId = actorUserId
        self.entityType = entityType
        self.entityId = entityId
        self.type = type
        self.payloadJson = payloadJson
        self.readAt = readAt
    }
}

