import Fluent
import Vapor

/// Tracks a structured mention of a user in a comment.
final class MentionModel: Model, Content, @unchecked Sendable {
    static let schema = "mentions"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: UserModel

    @Parent(key: "comment_id")
    var comment: CommentModel

    @Parent(key: "task_id")
    var task: TaskItemModel

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, userId: UUID, commentId: UUID, taskId: UUID) {
        self.id = id
        self.$user.id = userId
        self.$comment.id = commentId
        self.$task.id = taskId
    }
}

