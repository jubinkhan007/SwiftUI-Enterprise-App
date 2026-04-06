import Fluent
import Vapor

/// A single message within a conversation. Supports soft-delete and threading.
final class MessageModel: Model, Content, @unchecked Sendable {
    static let schema = "messages"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "conversation_id")
    var conversation: ConversationModel

    @Parent(key: "sender_id")
    var sender: UserModel

    @Field(key: "body")
    var body: String

    @Field(key: "message_type")
    var messageType: String  // "text", "system", "file"

    @OptionalParent(key: "parent_id")
    var parent: MessageModel?  // threading support (Phase 3)

    @OptionalField(key: "edited_at")
    var editedAt: Date?

    @OptionalField(key: "deleted_at")
    var deletedAt: Date?  // soft delete

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        conversationId: UUID,
        senderId: UUID,
        body: String,
        messageType: String = "text",
        parentId: UUID? = nil
    ) {
        self.id = id
        self.$conversation.id = conversationId
        self.$sender.id = senderId
        self.body = body
        self.messageType = messageType
        if let parentId { self.$parent.id = parentId }
    }
}
