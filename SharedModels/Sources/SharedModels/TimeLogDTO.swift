import Foundation

/// Represents a time log entry.
public struct TimeLogDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let taskId: UUID
    public let userId: UUID
    public let userDisplayName: String
    public let hoursLogged: Double
    public let loggedAt: Date
    public let description: String?
    public let createdAt: Date?

    public init(
        id: UUID,
        taskId: UUID,
        userId: UUID,
        userDisplayName: String,
        hoursLogged: Double,
        loggedAt: Date,
        description: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.hoursLogged = hoursLogged
        self.loggedAt = loggedAt
        self.description = description
        self.createdAt = createdAt
    }
}

/// Request payload to log time on a task.
public struct LogTimeRequest: Codable, Sendable {
    public let hoursLogged: Double
    public let loggedAt: Date
    public let description: String?

    public init(hoursLogged: Double, loggedAt: Date, description: String? = nil) {
        self.hoursLogged = hoursLogged
        self.loggedAt = loggedAt
        self.description = description
    }
}

/// Rolled-up time logs report for a project.
public struct ProjectTimeReportDTO: Codable, Sendable {
    public struct UserReport: Codable, Sendable, Identifiable {
        public var id: UUID { userId }
        public let userId: UUID
        public let userDisplayName: String
        public let totalHours: Double

        public init(userId: UUID, userDisplayName: String, totalHours: Double) {
            self.userId = userId
            self.userDisplayName = userDisplayName
            self.totalHours = totalHours
        }
    }

    public struct TaskReport: Codable, Sendable, Identifiable {
        public var id: UUID { taskId }
        public let taskId: UUID
        public let taskTitle: String
        public let totalHours: Double

        public init(taskId: UUID, taskTitle: String, totalHours: Double) {
            self.taskId = taskId
            self.taskTitle = taskTitle
            self.totalHours = totalHours
        }
    }

    public let projectId: UUID
    public let totalHours: Double
    public let byUser: [UserReport]
    public let byTask: [TaskReport]

    public init(projectId: UUID, totalHours: Double, byUser: [UserReport], byTask: [TaskReport]) {
        self.projectId = projectId
        self.totalHours = totalHours
        self.byUser = byUser
        self.byTask = byTask
    }
}
