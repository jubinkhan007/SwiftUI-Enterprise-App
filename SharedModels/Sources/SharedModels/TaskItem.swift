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
    public let startDate: Date?
    public let dueDate: Date?
    public let assigneeId: UUID?
    public let version: Int
    public let listId: UUID? // Optional for now during migration
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
    public let startDate: Date?
    public let dueDate: Date?
    public let assigneeId: UUID?
    public let listId: UUID?

    public init(
        title: String,
        description: String? = nil,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        assigneeId: UUID? = nil,
        listId: UUID? = nil
    ) {
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.startDate = startDate
        self.dueDate = dueDate
        self.assigneeId = assigneeId
        self.listId = listId
    }
}

/// Payload for updating an existing task.
public struct UpdateTaskRequest: Codable, Sendable {
    public let title: String?
    public let description: String?
    public let status: TaskStatus?
    public let priority: TaskPriority?
    public let startDate: Date?
    public let dueDate: Date?
    public let assigneeId: UUID?
    public let listId: UUID?
    public let position: Double?
    public let archivedAt: Date?
    public let expectedVersion: Int

    public init(
        title: String? = nil,
        description: String? = nil,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        assigneeId: UUID? = nil,
        listId: UUID? = nil,
        position: Double? = nil,
        archivedAt: Date? = nil,
        expectedVersion: Int
    ) {
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.startDate = startDate
        self.dueDate = dueDate
        self.assigneeId = assigneeId
        self.listId = listId
        self.position = position
        self.archivedAt = archivedAt
        self.expectedVersion = expectedVersion
    }
}
