import Foundation

public enum ActivityType: String, Codable, Sendable {
    case created
    case statusChanged
    case comment
    case assigned
    case priorityChanged
    case moved
    case typeChanged
    case parentChanged
}

/// Represents an activity item in the task's timeline.
public struct TaskActivityDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let taskId: UUID
    public let userId: UUID
    public let type: ActivityType
    public let content: String?
    public let createdAt: Date
    
    // Optional metadata for rich display (e.g. "To: Done" for status changed)
    public let metadata: [String: String]?
    
    public init(
        id: UUID = UUID(),
        taskId: UUID,
        userId: UUID,
        type: ActivityType,
        content: String? = nil,
        createdAt: Date = Date(),
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.userId = userId
        self.type = type
        self.content = content
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

/// Request payload for adding a comment.
/// `mentionedUserIds` carries explicitly-tracked mention IDs so the client can
/// display plain `@Full Name` text without embedding UUIDs in the comment body.
public struct CreateCommentRequest: Codable, Sendable {
    public let content: String
    public let mentionedUserIds: [UUID]?

    public init(content: String, mentionedUserIds: [UUID]? = nil) {
        self.content = content
        self.mentionedUserIds = mentionedUserIds
    }
}
