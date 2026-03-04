import Foundation

// MARK: - TaskItem DTO

/// A Data Transfer Object representing a task/work item.
/// Used for API communication between the client and server.
public struct TaskItemDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    /// Denormalized project id for agile queries (may be nil for legacy tasks).
    public let projectId: UUID?
    /// Project-scoped issue key (e.g. "APP-42").
    public let issueKey: String?
    public let title: String
    public let description: String?
    /// Canonical workflow status (project-scoped). May be nil for legacy tasks.
    public let statusId: UUID?
    public let status: TaskStatus
    public let priority: TaskPriority
    public let taskType: TaskType
    public let parentId: UUID?
    public let subtaskCount: Int
    public let completedSubtaskCount: Int
    public let storyPoints: Int?
    // Sprint / backlog assignment (Phase 13)
    public let sprintId: UUID?
    public let backlogPosition: Double?
    public let sprintPosition: Double?
    public let labels: [String]?
    public let startDate: Date?
    public let dueDate: Date?
    public let assigneeId: UUID?
    public let version: Int
    public let listId: UUID?
    public let position: Double
    // Epics: denormalized progress counters (Phase 13)
    public let epicTotalPoints: Int?
    public let epicCompletedPoints: Int?
    public let epicChildrenCount: Int?
    public let epicChildrenDoneCount: Int?
    // Bug fields (Phase 13)
    public let bugSeverity: BugSeverity?
    public let bugEnvironment: BugEnvironment?
    public let affectedVersionId: UUID?
    public let expectedResult: String?
    public let actualResult: String?
    public let reproductionSteps: String?
    public let archivedAt: Date?
    public let completedAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID = UUID(),
        projectId: UUID? = nil,
        issueKey: String? = nil,
        title: String,
        description: String? = nil,
        statusId: UUID? = nil,
        status: TaskStatus = .todo,
        priority: TaskPriority = .medium,
        taskType: TaskType = .task,
        parentId: UUID? = nil,
        subtaskCount: Int = 0,
        completedSubtaskCount: Int = 0,
        storyPoints: Int? = nil,
        sprintId: UUID? = nil,
        backlogPosition: Double? = nil,
        sprintPosition: Double? = nil,
        labels: [String]? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        assigneeId: UUID? = nil,
        version: Int = 1,
        listId: UUID? = nil,
        position: Double = 0.0,
        epicTotalPoints: Int? = nil,
        epicCompletedPoints: Int? = nil,
        epicChildrenCount: Int? = nil,
        epicChildrenDoneCount: Int? = nil,
        bugSeverity: BugSeverity? = nil,
        bugEnvironment: BugEnvironment? = nil,
        affectedVersionId: UUID? = nil,
        expectedResult: String? = nil,
        actualResult: String? = nil,
        reproductionSteps: String? = nil,
        archivedAt: Date? = nil,
        completedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.issueKey = issueKey
        self.title = title
        self.description = description
        self.statusId = statusId
        self.status = status
        self.priority = priority
        self.taskType = taskType
        self.parentId = parentId
        self.subtaskCount = subtaskCount
        self.completedSubtaskCount = completedSubtaskCount
        self.storyPoints = storyPoints
        self.sprintId = sprintId
        self.backlogPosition = backlogPosition
        self.sprintPosition = sprintPosition
        self.labels = labels
        self.startDate = startDate
        self.dueDate = dueDate
        self.assigneeId = assigneeId
        self.version = version
        self.listId = listId
        self.position = position
        self.epicTotalPoints = epicTotalPoints
        self.epicCompletedPoints = epicCompletedPoints
        self.epicChildrenCount = epicChildrenCount
        self.epicChildrenDoneCount = epicChildrenDoneCount
        self.bugSeverity = bugSeverity
        self.bugEnvironment = bugEnvironment
        self.affectedVersionId = affectedVersionId
        self.expectedResult = expectedResult
        self.actualResult = actualResult
        self.reproductionSteps = reproductionSteps
        self.archivedAt = archivedAt
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Create / Update Payloads

/// Payload for creating a new task.
public struct CreateTaskRequest: Codable, Sendable {
    public let title: String
    public let description: String?
    public let statusId: UUID?
    public let status: TaskStatus?
    public let priority: TaskPriority?
    public let taskType: TaskType?
    public let parentId: UUID?
    public let storyPoints: Int?
    public let labels: [String]?
    public let startDate: Date?
    public let dueDate: Date?
    public let assigneeId: UUID?
    public let listId: UUID?
    // Phase 13: backlog / sprint assignment
    public let sprintId: UUID?
    public let backlogPosition: Double?
    public let sprintPosition: Double?
    // Phase 13: bug fields
    public let bugSeverity: BugSeverity?
    public let bugEnvironment: BugEnvironment?
    public let affectedVersionId: UUID?
    public let expectedResult: String?
    public let actualResult: String?
    public let reproductionSteps: String?

    public init(
        title: String,
        description: String? = nil,
        statusId: UUID? = nil,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        taskType: TaskType? = nil,
        parentId: UUID? = nil,
        storyPoints: Int? = nil,
        labels: [String]? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        assigneeId: UUID? = nil,
        listId: UUID? = nil,
        sprintId: UUID? = nil,
        backlogPosition: Double? = nil,
        sprintPosition: Double? = nil,
        bugSeverity: BugSeverity? = nil,
        bugEnvironment: BugEnvironment? = nil,
        affectedVersionId: UUID? = nil,
        expectedResult: String? = nil,
        actualResult: String? = nil,
        reproductionSteps: String? = nil
    ) {
        self.title = title
        self.description = description
        self.statusId = statusId
        self.status = status
        self.priority = priority
        self.taskType = taskType
        self.parentId = parentId
        self.storyPoints = storyPoints
        self.labels = labels
        self.startDate = startDate
        self.dueDate = dueDate
        self.assigneeId = assigneeId
        self.listId = listId
        self.sprintId = sprintId
        self.backlogPosition = backlogPosition
        self.sprintPosition = sprintPosition
        self.bugSeverity = bugSeverity
        self.bugEnvironment = bugEnvironment
        self.affectedVersionId = affectedVersionId
        self.expectedResult = expectedResult
        self.actualResult = actualResult
        self.reproductionSteps = reproductionSteps
    }
}

/// Payload for updating an existing task.
public struct UpdateTaskRequest: Codable, Sendable {
    public var title: String?
    public var description: String?
    public var statusId: UUID?
    public var status: TaskStatus?
    public var priority: TaskPriority?
    public var taskType: TaskType?
    public var storyPoints: Int?
    public var labels: [String]?
    public var startDate: Date?
    public var dueDate: Date?
    public var assigneeId: UUID?
    public var listId: UUID?
    public var position: Double?
    public var archivedAt: Date?
    // Phase 13: backlog / sprint assignment
    public var sprintId: UUID?
    public var backlogPosition: Double?
    public var sprintPosition: Double?
    // Phase 13: bug fields
    public var bugSeverity: BugSeverity?
    public var bugEnvironment: BugEnvironment?
    public var affectedVersionId: UUID?
    public var expectedResult: String?
    public var actualResult: String?
    public var reproductionSteps: String?
    public var expectedVersion: Int?

    public init(
        title: String? = nil,
        description: String? = nil,
        statusId: UUID? = nil,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        taskType: TaskType? = nil,
        storyPoints: Int? = nil,
        labels: [String]? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        assigneeId: UUID? = nil,
        listId: UUID? = nil,
        position: Double? = nil,
        archivedAt: Date? = nil,
        sprintId: UUID? = nil,
        backlogPosition: Double? = nil,
        sprintPosition: Double? = nil,
        bugSeverity: BugSeverity? = nil,
        bugEnvironment: BugEnvironment? = nil,
        affectedVersionId: UUID? = nil,
        expectedResult: String? = nil,
        actualResult: String? = nil,
        reproductionSteps: String? = nil,
        expectedVersion: Int? = nil
    ) {
        self.title = title
        self.description = description
        self.statusId = statusId
        self.status = status
        self.priority = priority
        self.taskType = taskType
        self.storyPoints = storyPoints
        self.labels = labels
        self.startDate = startDate
        self.dueDate = dueDate
        self.assigneeId = assigneeId
        self.listId = listId
        self.position = position
        self.archivedAt = archivedAt
        self.sprintId = sprintId
        self.backlogPosition = backlogPosition
        self.sprintPosition = sprintPosition
        self.bugSeverity = bugSeverity
        self.bugEnvironment = bugEnvironment
        self.affectedVersionId = affectedVersionId
        self.expectedResult = expectedResult
        self.actualResult = actualResult
        self.reproductionSteps = reproductionSteps
        self.expectedVersion = expectedVersion
    }
}

/// Payload for moving a task to a different list or position.
public struct MoveTaskRequest: Codable, Sendable {
    public let targetListId: UUID
    public let position: Double

    public init(targetListId: UUID, position: Double) {
        self.targetListId = targetListId
        self.position = position
    }
}

/// A specific move instruction for a single task within a bulk move operation.
public struct TaskMoveAction: Codable, Sendable {
    public let taskId: UUID
    public let newPosition: Double

    public init(taskId: UUID, newPosition: Double) {
        self.taskId = taskId
        self.newPosition = newPosition
    }
}

/// Payload for atomically moving multiple tasks (e.g. reordering a Kanban column).
public struct BulkMoveTaskRequest: Codable, Sendable {
    public let targetListId: UUID?
    public let targetStatusId: UUID?
    public let targetStatus: TaskStatus?
    public let moves: [TaskMoveAction]

    public init(targetListId: UUID? = nil, targetStatusId: UUID? = nil, targetStatus: TaskStatus? = nil, moves: [TaskMoveAction]) {
        self.targetListId = targetListId
        self.targetStatusId = targetStatusId
        self.targetStatus = targetStatus
        self.moves = moves
    }
}
