import Fluent
import Vapor
import SharedModels

/// A checklist sub-item belonging to a task.
final class ChecklistItemModel: Model, Content, @unchecked Sendable {
    static let schema = "checklist_items"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "task_id")
    var task: TaskItemModel

    @Field(key: "title")
    var title: String

    @Field(key: "is_completed")
    var isCompleted: Bool

    @Field(key: "position")
    var position: Double

    @Parent(key: "created_by")
    var createdByUser: UserModel

    @OptionalParent(key: "updated_by")
    var updatedByUser: UserModel?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        taskId: UUID,
        title: String,
        isCompleted: Bool = false,
        position: Double = 0.0,
        createdBy: UUID,
        updatedBy: UUID? = nil
    ) {
        self.id = id
        self.$task.id = taskId
        self.title = title
        self.isCompleted = isCompleted
        self.position = position
        self.$createdByUser.id = createdBy
        self.$updatedByUser.id = updatedBy
    }

    func toDTO() -> ChecklistItemDTO {
        ChecklistItemDTO(
            id: id ?? UUID(),
            taskId: $task.id,
            title: title,
            isCompleted: isCompleted,
            position: position,
            createdBy: $createdByUser.id,
            updatedBy: $updatedByUser.id,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
