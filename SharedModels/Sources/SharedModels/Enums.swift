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

// MARK: - Task Type

/// Defines the category of a work item.
public enum TaskType: String, Codable, CaseIterable, Sendable {
    case task
    case bug
    case story
    case epic
    case subtask

    public var displayName: String {
        switch self {
        case .task: return "Task"
        case .bug: return "Bug"
        case .story: return "Story"
        case .epic: return "Epic"
        case .subtask: return "Subtask"
        }
    }

    /// SF Symbol name for the type icon.
    public var iconName: String {
        switch self {
        case .task: return "checkmark.circle"
        case .bug: return "ladybug.fill"
        case .story: return "book.fill"
        case .epic: return "bolt.fill"
        case .subtask: return "arrow.turn.down.right"
        }
    }

    /// Hex color string for visual coding.
    public var colorHex: String {
        switch self {
        case .task: return "#4A90D9"    // Blue
        case .bug: return "#E74C3C"     // Red
        case .story: return "#2ECC71"   // Green
        case .epic: return "#9B59B6"    // Purple
        case .subtask: return "#95A5A6" // Gray
        }
    }

    /// Whether this type can have children (subtask support).
    public var canHaveChildren: Bool {
        switch self {
        case .subtask: return false
        default: return true
        }
    }
}

// MARK: - User Role (RBAC)

/// Defines the access level of a user within an organization.
/// Ordered from least to most privileged.
public enum UserRole: String, Codable, CaseIterable, Sendable {
    case guest
    case member
    case manager
    case admin
    case owner

    public var displayName: String {
        switch self {
        case .guest: return "Guest"
        case .member: return "Member"
        case .manager: return "Manager"
        case .admin: return "Admin"
        case .owner: return "Owner"
        }
    }

    /// Privilege level for comparison (higher = more privileged).
    public var privilegeLevel: Int {
        switch self {
        case .guest: return 0
        case .member: return 1
        case .manager: return 2
        case .admin: return 3
        case .owner: return 4
        }
    }
}

// MARK: - Permission

/// Granular permission actions within an organization.
/// Roles map to sets of these permissions server-side.
public enum Permission: String, Codable, Sendable, CaseIterable {
    // Tasks
    case tasksRead       = "tasks.read"
    case tasksCreate     = "tasks.create"
    case tasksEdit       = "tasks.edit"
    case tasksDelete     = "tasks.delete"
    case tasksAssign     = "tasks.assign"

    // Members
    case membersView     = "members.view"
    case membersInvite   = "members.invite"
    case membersManage   = "members.manage"
    case membersRemove   = "members.remove"

    // Projects (future, but define now)
    case projectsCreate  = "projects.create"
    case projectsEdit    = "projects.edit"
    case projectsDelete  = "projects.delete"
    case projectsArchive = "projects.archive"

    // Analytics
    case analyticsView   = "analytics.view"
    case analyticsExport = "analytics.export"

    // Admin
    case orgSettings     = "org.settings"
    case orgDelete       = "org.delete"
    case auditLogView    = "audit_log.view"

    // Advanced Tasks (Phase 8)
    case tasksCreateSubtask = "tasks.create_subtask"
    case tasksChangeType    = "tasks.change_type"
    case tasksRelate        = "tasks.relate"
    case tasksManageChecklist = "tasks.manage_checklist"
}

/// A set of permissions for the current user within an org context.
/// Computed server-side and sent to the client via `/api/me`.
public struct PermissionSet: Codable, Sendable, Equatable {
    public let permissions: Set<Permission>

    public init(permissions: Set<Permission>) {
        self.permissions = permissions
    }

    public func has(_ permission: Permission) -> Bool {
        permissions.contains(permission)
    }

    /// Convenience: Create a PermissionSet from a role using the default mapping.
    public static func defaultPermissions(for role: UserRole) -> PermissionSet {
        switch role {
        case .guest:
            return PermissionSet(permissions: [.tasksRead, .membersView])
        case .member:
            return PermissionSet(permissions: [
                .tasksRead, .tasksCreate, .tasksEdit, .tasksAssign,
                .membersView, .analyticsView
            ])
        case .manager:
            return PermissionSet(permissions: [
                .tasksRead, .tasksCreate, .tasksEdit, .tasksDelete, .tasksAssign,
                .tasksCreateSubtask, .tasksChangeType, .tasksRelate, .tasksManageChecklist,
                .membersView, .membersInvite,
                .projectsCreate, .projectsEdit,
                .analyticsView, .analyticsExport
            ])
        case .admin:
            return PermissionSet(permissions: [
                .tasksRead, .tasksCreate, .tasksEdit, .tasksDelete, .tasksAssign,
                .tasksCreateSubtask, .tasksChangeType, .tasksRelate, .tasksManageChecklist,
                .membersView, .membersInvite, .membersManage, .membersRemove,
                .projectsCreate, .projectsEdit, .projectsDelete, .projectsArchive,
                .analyticsView, .analyticsExport,
                .orgSettings, .auditLogView
            ])
        case .owner:
            return PermissionSet(permissions: Set(Permission.allCases))
        }
    }
}

// MARK: - Invite Status

/// Lifecycle status of an organization invite.
public enum InviteStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case accepted
    case expired
    case revoked
}
