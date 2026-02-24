import Fluent
import Vapor
import SharedModels

/// Fluent database model for tracking activity and comments on a Task.
final class TaskActivityModel: Model, Content, @unchecked Sendable {
    static let schema = "task_activities"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "task_id")
    var task: TaskItemModel

    @Parent(key: "user_id")
    var user: UserModel

    @Enum(key: "type")
    var type: ActivityType

    @OptionalField(key: "content")
    var content: String?

    // Optional metadata stored as JSON (e.g. "To: Done" for status changed)
    @OptionalField(key: "metadata")
    var metadata: [String: String]?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        taskId: UUID,
        userId: UUID,
        type: ActivityType,
        content: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.$task.id = taskId
        self.$user.id = userId
        self.type = type
        self.content = content
        self.metadata = metadata
    }

    func toDTO() -> TaskActivityDTO {
        TaskActivityDTO(
            id: id ?? UUID(),
            taskId: $task.id,
            userId: $user.id,
            type: type,
            content: content,
            createdAt: createdAt ?? Date(),
            metadata: metadata
        )
    }
}
