import Foundation

/// Defines standard parameters for filtering, sorting, and searching tasks.
/// Shared between the client query engine and the backend Vapor controllers.
public struct TaskQuery: Codable, Sendable, Equatable {
    public var page: Int
    public var perPage: Int
    public var status: TaskStatus?
    public var priority: TaskPriority?
    public var taskType: TaskType?
    public var parentId: UUID?
    /// When false (default), top-level list excludes subtasks.
    public var includeSubtasks: Bool
    public var assigneeId: UUID?
    public var search: String?
    public var spaceId: UUID?
    public var projectId: UUID?
    public var listId: UUID?

    public init(
        page: Int = 1,
        perPage: Int = 20,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        taskType: TaskType? = nil,
        parentId: UUID? = nil,
        includeSubtasks: Bool = false,
        assigneeId: UUID? = nil,
        search: String? = nil,
        spaceId: UUID? = nil,
        projectId: UUID? = nil,
        listId: UUID? = nil
    ) {
        self.page = page
        self.perPage = perPage
        self.status = status
        self.priority = priority
        self.taskType = taskType
        self.parentId = parentId
        self.includeSubtasks = includeSubtasks
        self.assigneeId = assigneeId
        self.search = search
        self.spaceId = spaceId
        self.projectId = projectId
        self.listId = listId
    }
}
