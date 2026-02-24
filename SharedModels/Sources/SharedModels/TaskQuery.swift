import Foundation

/// Defines standard parameters for filtering, sorting, and searching tasks.
/// Shared between the client query engine and the backend Vapor controllers.
public struct TaskQuery: Codable, Sendable, Equatable {
    public var page: Int
    public var perPage: Int
    public var status: TaskStatus?
    public var priority: TaskPriority?
    public var assigneeId: UUID?
    public var search: String?
    
    public init(
        page: Int = 1,
        perPage: Int = 20,
        status: TaskStatus? = nil,
        priority: TaskPriority? = nil,
        assigneeId: UUID? = nil,
        search: String? = nil
    ) {
        self.page = page
        self.perPage = perPage
        self.status = status
        self.priority = priority
        self.assigneeId = assigneeId
        self.search = search
    }
}
