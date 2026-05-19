import Fluent
import Vapor

/// A single emoji reaction on a message by one user. Unique on (message_id, user_id, emoji).
final class MessageReactionModel: Model, Content, @unchecked Sendable {
    static let schema = "message_reactions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "message_id")
    var message: MessageModel

    @Parent(key: "user_id")
    var user: UserModel

    @Field(key: "emoji")
    var emoji: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, messageId: UUID, userId: UUID, emoji: String) {
        self.id = id
        self.$message.id = messageId
        self.$user.id = userId
        self.emoji = emoji
    }
}
