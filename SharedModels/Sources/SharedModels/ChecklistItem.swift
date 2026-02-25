import Foundation

// MARK: - Checklist Item DTO

public struct ChecklistItemDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let taskId: UUID
    public let title: String
    public let isCompleted: Bool
    public let position: Double
    public let createdBy: UUID
    public let updatedBy: UUID?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID = UUID(),
        taskId: UUID,
        title: String,
        isCompleted: Bool = false,
        position: Double = 0.0,
        createdBy: UUID,
        updatedBy: UUID? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.title = title
        self.isCompleted = isCompleted
        self.position = position
        self.createdBy = createdBy
        self.updatedBy = updatedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Request Payloads

public struct CreateChecklistItemRequest: Codable, Sendable {
    public let title: String

    public init(title: String) {
        self.title = title
    }
}

public struct UpdateChecklistItemRequest: Codable, Sendable {
    public let title: String?
    public let isCompleted: Bool?

    public init(title: String? = nil, isCompleted: Bool? = nil) {
        self.title = title
        self.isCompleted = isCompleted
    }
}

public struct ReorderChecklistRequest: Codable, Sendable {
    /// The item to reposition.
    public let itemId: UUID
    /// Place item after this item; nil means move to top.
    public let afterId: UUID?

    public init(itemId: UUID, afterId: UUID? = nil) {
        self.itemId = itemId
        self.afterId = afterId
    }
}
