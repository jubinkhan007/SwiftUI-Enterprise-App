import Fluent
import Vapor

/// A per-user bookmark of a message ("Saved Items").
final class MessageBookmarkModel: Model, Content, @unchecked Sendable {
    static let schema = "message_bookmarks"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "message_id")
    var message: MessageModel

    @Parent(key: "user_id")
    var user: UserModel

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, messageId: UUID, userId: UUID) {
        self.id = id
        self.$message.id = messageId
        self.$user.id = userId
    }
}
