import Fluent
import Vapor

/// Phase 4 (Productivity): a message queued to send at `scheduledFor`.
/// Status transitions: scheduled -> sending -> sent (sets `sent_message_id`)
/// or scheduled -> cancelled (user) or scheduled -> failed (with `error`).
/// Runner uses claim-by-UPDATE pattern via setting status='sending' before dispatch
/// to avoid double-send across runner ticks.
final class ScheduledMessageModel: Model, Content, @unchecked Sendable {
    static let schema = "scheduled_messages"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: UserModel

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Parent(key: "conversation_id")
    var conversation: ConversationModel

    @OptionalParent(key: "parent_id")
    var parent: MessageModel?

    @Field(key: "body")
    var body: String

    @Field(key: "message_type")
    var messageType: String

    @Field(key: "scheduled_for")
    var scheduledFor: Date

    /// "scheduled" / "sending" / "sent" / "cancelled" / "failed"
    @Field(key: "status")
    var status: String

    @OptionalField(key: "sent_message_id")
    var sentMessageId: UUID?

    @OptionalField(key: "error")
    var error: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userId: UUID,
        orgId: UUID,
        conversationId: UUID,
        parentId: UUID? = nil,
        body: String,
        messageType: String = "text",
        scheduledFor: Date,
        status: String = "scheduled"
    ) {
        self.id = id
        self.$user.id = userId
        self.$organization.id = orgId
        self.$conversation.id = conversationId
        if let parentId { self.$parent.id = parentId }
        self.body = body
        self.messageType = messageType
        self.scheduledFor = scheduledFor
        self.status = status
    }
}
