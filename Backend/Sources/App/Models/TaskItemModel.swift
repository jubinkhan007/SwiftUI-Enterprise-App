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

    @Enum(key: "task_type")
    var taskType: TaskType

    @OptionalParent(key: "parent_id")
    var parent: TaskItemModel?

    @OptionalField(key: "story_points")
    var storyPoints: Int?

    @OptionalField(key: "labels")
    var labels: [String]?

    @OptionalParent(key: "org_id")
    var organization: OrganizationModel?

    @OptionalParent(key: "list_id") // Optional for migration step 1
    var list: TaskListModel?

    @Field(key: "position")
    var position: Double

    @OptionalField(key: "archived_at")
    var archivedAt: Date?

    @OptionalField(key: "start_date")
    var startDate: Date?

    @OptionalField(key: "due_date")
    var dueDate: Date?

    @OptionalParent(key: "assignee_id")
    var assignee: UserModel?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Field(key: "version")
    var version: Int

    init() {}

    init(
        id: UUID? = nil,
        orgId: UUID? = nil,
        listId: UUID? = nil,
        title: String,
        description: String? = nil,
        status: TaskStatus = .todo,
        priority: TaskPriority = .medium,
        taskType: TaskType = .task,
        parentId: UUID? = nil,
        storyPoints: Int? = nil,
        labels: [String]? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        assigneeId: UUID? = nil,
        version: Int = 1,
        position: Double = 0.0,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.$organization.id = orgId
        self.$list.id = listId
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.taskType = taskType
        self.$parent.id = parentId
        self.storyPoints = storyPoints
        self.labels = labels
        self.startDate = startDate
        self.dueDate = dueDate
        self.$assignee.id = assigneeId
        self.version = version
        self.position = position
        self.archivedAt = archivedAt
    }

    /// Convert to the shared DTO for API responses.
    /// - Parameters:
    ///   - subtaskCount: Total number of direct subtasks (pass from a pre-computed aggregate).
    ///   - completedSubtaskCount: Number of subtasks with status `.done`.
    func toDTO(subtaskCount: Int = 0, completedSubtaskCount: Int = 0) -> TaskItemDTO {
        TaskItemDTO(
            id: id ?? UUID(),
            title: title,
            description: description,
            status: status,
            priority: priority,
            taskType: taskType,
            parentId: $parent.id,
            subtaskCount: subtaskCount,
            completedSubtaskCount: completedSubtaskCount,
            storyPoints: storyPoints,
            labels: labels,
            startDate: startDate,
            dueDate: dueDate,
            assigneeId: $assignee.id,
            version: version,
            listId: $list.id,
            position: position,
            archivedAt: archivedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
