import Fluent
import Vapor

/// Join table linking users to conversations with per-member preferences.
final class ConversationMemberModel: Model, Content, @unchecked Sendable {
    static let schema = "conversation_members"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "conversation_id")
    var conversation: ConversationModel

    @Parent(key: "user_id")
    var user: UserModel

    @Field(key: "role")
    var role: String  // "admin", "member"

    @OptionalField(key: "last_read_at")
    var lastReadAt: Date?

    @OptionalField(key: "last_seen_at")
    var lastSeenAt: Date?

    @OptionalField(key: "last_read_message_id")
    var lastReadMessageId: UUID?

    @Field(key: "status")
    var status: String  // "active", "pending"

    @Field(key: "notification_preference")
    var notificationPreference: String  // "all", "mentions", "none"

    @Field(key: "is_muted")
    var isMuted: Bool

    @Timestamp(key: "joined_at", on: .create)
    var joinedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        conversationId: UUID,
        userId: UUID,
        role: String = "member",
        status: String = "active",
        notificationPreference: String = "all",
        isMuted: Bool = false
    ) {
        self.id = id
        self.$conversation.id = conversationId
        self.$user.id = userId
        self.role = role
        self.status = status
        self.notificationPreference = notificationPreference
        self.isMuted = isMuted
    }
}
