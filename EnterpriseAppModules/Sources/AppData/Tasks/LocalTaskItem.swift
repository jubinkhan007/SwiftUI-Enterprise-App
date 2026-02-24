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
        dueDate: Date? = nil,
        assigneeId: UUID? = nil,
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
        self.dueDate = dueDate
        self.assigneeId = assigneeId
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
            dueDate: dueDate,
            assigneeId: assigneeId,
            version: version,
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
        self.dueDate = dto.dueDate
        self.assigneeId = dto.assigneeId
        self.version = dto.version
        self.createdAt = dto.createdAt
        self.updatedAt = dto.updatedAt
        self.isPendingSync = false
    }
}
