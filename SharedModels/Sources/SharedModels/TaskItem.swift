import Foundation

// MARK: - TaskItem DTO

/// A Data Transfer Object representing a task/work item.
/// Used for API communication between the client and server.
public struct TaskItemDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let status: TaskStatus
    public let priority: TaskPriority
    public let taskType: TaskType
    public let parentId: UUID?
    public let subtaskCount: Int
    public let completedSubtaskCount: Int
    public let storyPoints: Int?
    public let labels: [String]?
    public let startDate: Date?
    public let dueDate: Date?
    public let assigneeId: UUID?
    public let version: Int
    public let listId: UUID?
    public let position: Double
    public let archivedAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        status: TaskStatus = .todo,
        priority: TaskPriority = .medium,
        taskType: TaskType = .task,
        parentId: UUID? = nil,
        subtaskCount: Int = 0,
        completedSubtaskCount: Int = 0,
        storyPoints: Int? = nil,
        labels: [String]? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        assigneeId: UUID? = nil,
        version: Int = 1,
        listId: UUID? = nil,
        position: Double = 0.0,
        archivedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.taskType = taskType
        self.parentId = parentId
        self.subtaskCount = subtaskCount
        self.completedSubtaskCount = completedSubtaskCount
        self.storyPoints = storyPoints
        self.labels = labels
        self.startDate = startDate
        self.dueDate = dueDate
        self.assigneeId = assigneeId
        self.version = version
        self.listId = listId
        self.position = position
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Create / Update Payloads

/// Payload for creating a new task.
public struct CreateTaskRequest: Codable, Sendable {
    public let title: String
    public let description: String?
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

    public init(
        title: String,
        description: String? = nil,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        taskType: TaskType? = nil,
        parentId: UUID? = nil,
        storyPoints: Int? = nil,
        labels: [String]? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        assigneeId: UUID? = nil,
        listId: UUID? = nil
    ) {
        self.title = title
        self.description = description
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
    }
}

/// Payload for updating an existing task.
public struct UpdateTaskRequest: Codable, Sendable {
    public var title: String?
    public var description: String?
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
    public var expectedVersion: Int?

    public init(
        title: String? = nil,
        description: String? = nil,
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
        expectedVersion: Int? = nil
    ) {
        self.title = title
        self.description = description
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
    public let targetStatus: TaskStatus?
    public let moves: [TaskMoveAction]

    public init(targetListId: UUID? = nil, targetStatus: TaskStatus? = nil, moves: [TaskMoveAction]) {
        self.targetListId = targetListId
        self.targetStatus = targetStatus
        self.moves = moves
    }
}
