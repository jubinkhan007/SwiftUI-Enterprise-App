import Foundation
import SwiftData
import SharedModels

/// SwiftData model representing a locally cached Task.
@Model
public final class LocalTaskItem: @unchecked Sendable {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var taskDescription: String?
    public var statusRawValue: String
    public var priorityRawValue: String
    public var dueDate: Date?
    public var assigneeId: UUID?
    
    // Phase 8 Additions
    public var taskTypeRawValue: String
    public var parentId: UUID?
    public var subtaskCount: Int
    public var completedSubtaskCount: Int
    public var storyPoints: Int?
    public var labels: [String]?
    public var startDate: Date?
    
    // Phase 7 Additions
    public var listId: UUID?
    public var position: Double
    public var archivedAt: Date?
    
    public var version: Int
    public var createdAt: Date?
    public var updatedAt: Date?
    
    // Metadata for sync engine
    public var isPendingSync: Bool
    public var isDeletedLocally: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        taskDescription: String? = nil,
        status: TaskStatus = .todo,
        priority: TaskPriority = .medium,
        taskType: TaskType = .task,
        dueDate: Date? = nil,
        startDate: Date? = nil,
        assigneeId: UUID? = nil,
        parentId: UUID? = nil,
        subtaskCount: Int = 0,
        completedSubtaskCount: Int = 0,
        storyPoints: Int? = nil,
        labels: [String]? = nil,
        listId: UUID? = nil,
        position: Double = 0.0,
        archivedAt: Date? = nil,
        version: Int = 1,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        isPendingSync: Bool = false,
        isDeletedLocally: Bool = false
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.statusRawValue = status.rawValue
        self.priorityRawValue = priority.rawValue
        self.taskTypeRawValue = taskType.rawValue
        self.dueDate = dueDate
        self.startDate = startDate
        self.assigneeId = assigneeId
        self.parentId = parentId
        self.subtaskCount = subtaskCount
        self.completedSubtaskCount = completedSubtaskCount
        self.storyPoints = storyPoints
        self.labels = labels
        self.listId = listId
        self.position = position
        self.archivedAt = archivedAt
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPendingSync = isPendingSync
        self.isDeletedLocally = isDeletedLocally
    }
    
    /// Converts this local model back to the shared DTO.
    public func toDTO() -> TaskItemDTO {
        TaskItemDTO(
            id: id,
            title: title,
            description: taskDescription,
            status: TaskStatus(rawValue: statusRawValue) ?? .todo,
            priority: TaskPriority(rawValue: priorityRawValue) ?? .medium,
            taskType: TaskType(rawValue: taskTypeRawValue) ?? .task,
            parentId: parentId,
            subtaskCount: subtaskCount,
            completedSubtaskCount: completedSubtaskCount,
            storyPoints: storyPoints,
            labels: labels,
            startDate: startDate,
            dueDate: dueDate,
            assigneeId: assigneeId,
            version: version,
            listId: listId,
            position: position,
            archivedAt: archivedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    /// Updates from a server DTO.
    public func update(from dto: TaskItemDTO) {
        self.title = dto.title
        self.taskDescription = dto.description
        self.statusRawValue = dto.status.rawValue
        self.priorityRawValue = dto.priority.rawValue
        self.taskTypeRawValue = dto.taskType.rawValue
        self.dueDate = dto.dueDate
        self.startDate = dto.startDate
        self.assigneeId = dto.assigneeId
        self.parentId = dto.parentId
        self.subtaskCount = dto.subtaskCount
        self.completedSubtaskCount = dto.completedSubtaskCount
        self.storyPoints = dto.storyPoints
        self.labels = dto.labels
        self.listId = dto.listId
        self.position = dto.position
        self.archivedAt = dto.archivedAt
        self.version = dto.version
        self.createdAt = dto.createdAt
        self.updatedAt = dto.updatedAt
        self.isPendingSync = false
    }
}
