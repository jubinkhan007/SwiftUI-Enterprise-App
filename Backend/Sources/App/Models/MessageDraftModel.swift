import Fluent
import Vapor

/// Phase 4 (Productivity): server-synced draft for cross-device editing.
/// One row per (user, conversation, parent_id). `parent_id` is nullable for
/// the main composer; non-null for thread drafts.
final class MessageDraftModel: Model, Content, @unchecked Sendable {
    static let schema = "message_drafts"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: UserModel

    @Parent(key: "conversation_id")
    var conversation: ConversationModel

    @OptionalParent(key: "parent_id")
    var parent: MessageModel?

    @Field(key: "body")
    var body: String

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, userId: UUID, conversationId: UUID, parentId: UUID? = nil, body: String) {
        self.id = id
        self.$user.id = userId
        self.$conversation.id = conversationId
        if let parentId { self.$parent.id = parentId }
        self.body = body
    }
}
