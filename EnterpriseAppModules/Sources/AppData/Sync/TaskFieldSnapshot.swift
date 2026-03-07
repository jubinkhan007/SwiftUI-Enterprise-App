import Foundation
import SharedModels

public struct TaskFieldSnapshot: Codable, Sendable, Equatable {
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
    public var sprintId: UUID?
    public var backlogPosition: Double?
    public var sprintPosition: Double?
    public var bugSeverity: BugSeverity?
    public var bugEnvironment: BugEnvironment?
    public var affectedVersionId: UUID?
    public var expectedResult: String?
    public var actualResult: String?
    public var reproductionSteps: String?

    public init() {}
}

