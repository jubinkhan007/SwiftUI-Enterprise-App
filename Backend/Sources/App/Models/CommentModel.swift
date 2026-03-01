import Fluent
import Vapor

/// First-class comment model (Markdown body) scoped to an org and task.
final class CommentModel: Model, Content, @unchecked Sendable {
    static let schema = "comments"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "task_id")
    var task: TaskItemModel

    @Parent(key: "user_id")
    var user: UserModel

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Field(key: "body")
    var body: String

    @OptionalField(key: "edited_at")
    var editedAt: Date?

    @OptionalField(key: "deleted_at")
    var deletedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, taskId: UUID, userId: UUID, orgId: UUID, body: String) {
        self.id = id
        self.$task.id = taskId
        self.$user.id = userId
        self.$organization.id = orgId
        self.body = body
    }
}

