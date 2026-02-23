import Fluent
import Vapor
import SharedModels

/// Fluent database model for a Task item.
final class TaskItemModel: Model, Content, @unchecked Sendable {
    static let schema = "task_items"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @OptionalField(key: "description")
    var description: String?

    @Enum(key: "status")
    var status: TaskStatus

    @Enum(key: "priority")
    var priority: TaskPriority

    @OptionalField(key: "due_date")
    var dueDate: Date?

    @OptionalParent(key: "assignee_id")
    var assignee: UserModel?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        title: String,
        description: String? = nil,
        status: TaskStatus = .todo,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        assigneeId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.$assignee.id = assigneeId
    }

    /// Convert to the shared DTO for API responses.
    func toDTO() -> TaskItemDTO {
        TaskItemDTO(
            id: id ?? UUID(),
            title: title,
            description: description,
            status: status,
            priority: priority,
            dueDate: dueDate,
            assigneeId: $assignee.id,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
