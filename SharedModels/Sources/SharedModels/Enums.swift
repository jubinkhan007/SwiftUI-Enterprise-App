import Foundation

// MARK: - Task Status

/// Represents the lifecycle state of a task.
public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case todo
    case inProgress = "in_progress"
    case inReview = "in_review"
    case done
    case cancelled

    public var displayName: String {
        switch self {
        case .todo: return "To Do"
        case .inProgress: return "In Progress"
        case .inReview: return "In Review"
        case .done: return "Done"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Task Priority

/// Represents the urgency level of a task.
public enum TaskPriority: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
    case critical

    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    /// Sort order, higher value = higher priority.
    public var sortOrder: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
}

// MARK: - User Role

/// Defines the access level of a user within the organization.
public enum UserRole: String, Codable, CaseIterable, Sendable {
    case viewer
    case member
    case admin
    case owner

    public var displayName: String {
        switch self {
        case .viewer: return "Viewer"
        case .member: return "Member"
        case .admin: return "Admin"
        case .owner: return "Owner"
        }
    }
}
