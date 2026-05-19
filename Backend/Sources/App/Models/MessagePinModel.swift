import Fluent
import Vapor

/// A pinned message within a conversation. Unique on message_id.
final class MessagePinModel: Model, Content, @unchecked Sendable {
    static let schema = "message_pins"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "message_id")
    var message: MessageModel

    @Parent(key: "conversation_id")
    var conversation: ConversationModel

    @Parent(key: "pinned_by")
    var pinnedBy: UserModel

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, messageId: UUID, conversationId: UUID, pinnedBy: UUID) {
        self.id = id
        self.$message.id = messageId
        self.$conversation.id = conversationId
        self.$pinnedBy.id = pinnedBy
    }
}
