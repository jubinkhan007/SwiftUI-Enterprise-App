import Foundation

// MARK: - Task Relation Type

/// The kind of relationship between two tasks.
/// Only `blocks`, `relatesTo`, and `duplicateOf` are stored canonically.
/// `blockedBy` is a computed inverse returned in responses when another task blocks this one.
public enum TaskRelationType: String, Codable, CaseIterable, Sendable {
    case blocks
    case blockedBy   // virtual/computed — never stored in DB
    case relatesTo
    case duplicateOf

    public var displayName: String {
        switch self {
        case .blocks:      return "Blocks"
        case .blockedBy:   return "Blocked by"
        case .relatesTo:   return "Relates to"
        case .duplicateOf: return "Duplicate of"
        }
    }

    public var iconName: String {
        switch self {
        case .blocks:      return "arrow.right.circle.fill"
        case .blockedBy:   return "arrow.left.circle.fill"
        case .relatesTo:   return "link"
        case .duplicateOf: return "doc.on.doc"
        }
    }
}

// MARK: - DTOs

/// Represents a relation between two tasks as returned by the API.
/// May be a canonical stored row or a computed inverse (blockedBy).
public struct TaskRelationDTO: Codable, Identifiable, Sendable, Equatable {
    /// The ID of the underlying canonical relation row.
    public let id: UUID
    /// The task this relation is being viewed from.
    public let taskId: UUID
    /// The other task involved in this relation.
    public let relatedTaskId: UUID
    /// The relation type from `taskId`'s perspective.
    public let relationType: TaskRelationType
    public let createdAt: Date

    public init(
        id: UUID,
        taskId: UUID,
        relatedTaskId: UUID,
        relationType: TaskRelationType,
        createdAt: Date
    ) {
        self.id = id
        self.taskId = taskId
        self.relatedTaskId = relatedTaskId
        self.relationType = relationType
        self.createdAt = createdAt
    }
}

// MARK: - Request Payloads

public struct CreateRelationRequest: Codable, Sendable {
    public let relatedTaskId: UUID
    public let relationType: TaskRelationType

    public init(relatedTaskId: UUID, relationType: TaskRelationType) {
        self.relatedTaskId = relatedTaskId
        self.relationType = relationType
    }
}
