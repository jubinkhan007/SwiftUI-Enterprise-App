import Fluent
import Vapor

/// Per-user presence + custom status. One row per user.
final class UserPresenceModel: Model, Content, @unchecked Sendable {
    static let schema = "user_presences"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: UserModel

    @Field(key: "state")
    var state: String  // "online", "away", "offline"

    @OptionalField(key: "custom_status_emoji")
    var customStatusEmoji: String?

    @OptionalField(key: "custom_status_text")
    var customStatusText: String?

    @OptionalField(key: "custom_status_expires_at")
    var customStatusExpiresAt: Date?

    @OptionalField(key: "last_heartbeat_at")
    var lastHeartbeatAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, userId: UUID, state: String = "offline") {
        self.id = id
        self.$user.id = userId
        self.state = state
    }
}
