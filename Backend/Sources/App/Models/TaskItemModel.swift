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

    /// Canonical workflow status (project-scoped).
    /// `status` (TaskStatus enum) remains as a compatibility/analytics layer.
    @OptionalParent(key: "status_id")
    var customStatus: CustomStatusModel?

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
    
    /// Denormalized project id for agile queries and issue keys.
    /// Always set for new tasks; may be nil for legacy rows.
    @OptionalParent(key: "project_id")
    var project: ProjectModel?

    /// Sprint assignment (Phase 13).
    @OptionalParent(key: "sprint_id")
    var sprint: SprintModel?
    
    /// Project-scoped issue key (Phase 13).
    @OptionalField(key: "issue_key")
    var issueKey: String?
    
    /// Phase 13 backlog ordering (unassigned to sprint).
    @OptionalField(key: "backlog_position")
    var backlogPosition: Double?
    
    /// Phase 13 sprint ordering (within sprint).
    @OptionalField(key: "sprint_position")
    var sprintPosition: Double?

    // MARK: - Epics: denormalized rollups (Phase 13)
    
    @OptionalField(key: "epic_total_points")
    var epicTotalPoints: Int?
    
    @OptionalField(key: "epic_completed_points")
    var epicCompletedPoints: Int?
    
    @OptionalField(key: "epic_children_count")
    var epicChildrenCount: Int?
    
    @OptionalField(key: "epic_children_done_count")
    var epicChildrenDoneCount: Int?
    
    // MARK: - Bug fields (Phase 13)
    
    @OptionalField(key: "bug_severity")
    var bugSeverityRaw: String?
    
    @OptionalField(key: "bug_environment")
    var bugEnvironmentRaw: String?
    
    @OptionalParent(key: "affected_version_id")
    var affectedVersion: ReleaseModel?
    
    @OptionalField(key: "expected_result")
    var expectedResult: String?
    
    @OptionalField(key: "actual_result")
    var actualResult: String?
    
    @OptionalField(key: "reproduction_steps")
    var reproductionSteps: String?

    @Field(key: "position")
    var position: Double

    @OptionalField(key: "archived_at")
    var archivedAt: Date?

    @OptionalField(key: "start_date")
    var startDate: Date?

    @OptionalField(key: "due_date")
    var dueDate: Date?

    @OptionalField(key: "completed_at")
    var completedAt: Date?

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
        projectId: UUID? = nil,
        title: String,
        description: String? = nil,
        status: TaskStatus = .todo,
        statusId: UUID? = nil,
        priority: TaskPriority = .medium,
        taskType: TaskType = .task,
        parentId: UUID? = nil,
        storyPoints: Int? = nil,
        sprintId: UUID? = nil,
        issueKey: String? = nil,
        backlogPosition: Double? = nil,
        sprintPosition: Double? = nil,
        labels: [String]? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        assigneeId: UUID? = nil,
        version: Int = 1,
        position: Double = 0.0,
        archivedAt: Date? = nil,
        bugSeverity: BugSeverity? = nil,
        bugEnvironment: BugEnvironment? = nil,
        affectedVersionId: UUID? = nil,
        expectedResult: String? = nil,
        actualResult: String? = nil,
        reproductionSteps: String? = nil
    ) {
        self.id = id
        self.$organization.id = orgId
        self.$list.id = listId
        self.$project.id = projectId
        self.title = title
        self.description = description
        self.status = status
        self.$customStatus.id = statusId
        self.priority = priority
        self.taskType = taskType
        self.$parent.id = parentId
        self.storyPoints = storyPoints
        self.$sprint.id = sprintId
        self.issueKey = issueKey
        self.backlogPosition = backlogPosition
        self.sprintPosition = sprintPosition
        self.labels = labels
        self.startDate = startDate
        self.dueDate = dueDate
        self.$assignee.id = assigneeId
        self.version = version
        self.position = position
        self.archivedAt = archivedAt
        self.bugSeverityRaw = bugSeverity?.rawValue
        self.bugEnvironmentRaw = bugEnvironment?.rawValue
        self.$affectedVersion.id = affectedVersionId
        self.expectedResult = expectedResult
        self.actualResult = actualResult
        self.reproductionSteps = reproductionSteps
    }

    /// Convert to the shared DTO for API responses.
    /// - Parameters:
    ///   - subtaskCount: Total number of direct subtasks (pass from a pre-computed aggregate).
    ///   - completedSubtaskCount: Number of subtasks with status `.done`.
    func toDTO(subtaskCount: Int = 0, completedSubtaskCount: Int = 0) -> TaskItemDTO {
        TaskItemDTO(
            id: id ?? UUID(),
            projectId: $project.id,
            issueKey: issueKey,
            title: title,
            description: description,
            statusId: $customStatus.id,
            status: status,
            priority: priority,
            taskType: taskType,
            parentId: $parent.id,
            subtaskCount: subtaskCount,
            completedSubtaskCount: completedSubtaskCount,
            storyPoints: storyPoints,
            sprintId: $sprint.id,
            backlogPosition: backlogPosition,
            sprintPosition: sprintPosition,
            labels: labels,
            startDate: startDate,
            dueDate: dueDate,
            assigneeId: $assignee.id,
            version: version,
            listId: $list.id,
            position: position,
            epicTotalPoints: epicTotalPoints,
            epicCompletedPoints: epicCompletedPoints,
            epicChildrenCount: epicChildrenCount,
            epicChildrenDoneCount: epicChildrenDoneCount,
            bugSeverity: bugSeverityRaw.flatMap(BugSeverity.init(rawValue:)),
            bugEnvironment: bugEnvironmentRaw.flatMap(BugEnvironment.init(rawValue:)),
            affectedVersionId: $affectedVersion.id,
            expectedResult: expectedResult,
            actualResult: actualResult,
            reproductionSteps: reproductionSteps,
            archivedAt: archivedAt,
            completedAt: completedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
