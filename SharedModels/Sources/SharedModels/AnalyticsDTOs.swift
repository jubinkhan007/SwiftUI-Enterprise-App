import Foundation

// MARK: - Analytics Response (Enterprise Trust)

/// Generic analytics response wrapper with built-in explainability metadata.
/// Concrete endpoints should instantiate this with a concrete `T` (e.g. `Double`, `[ProjectDailyStatsDTO]`).
public struct AnalyticsResponseDTO<T: Codable & Sendable>: Codable, Sendable {
    public let metric: String
    public let value: T
    public let p50: T?
    public let p90: T?
    public let sampleSize: Int
    public let from: Date
    public let to: Date
    public let filters: [String: String]

    public init(
        metric: String,
        value: T,
        p50: T? = nil,
        p90: T? = nil,
        sampleSize: Int,
        from: Date,
        to: Date,
        filters: [String: String] = [:]
    ) {
        self.metric = metric
        self.value = value
        self.p50 = p50
        self.p90 = p90
        self.sampleSize = sampleSize
        self.from = from
        self.to = to
        self.filters = filters
    }
}

// MARK: - Project Daily Stats

public struct ProjectDailyStatsDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let projectId: UUID
    /// UTC midnight for the day this row represents.
    public let date: Date
    public let remainingPoints: Double
    public let completedPoints: Double
    public let completedTasks: Int
    public let createdTasks: Int

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        date: Date,
        remainingPoints: Double,
        completedPoints: Double,
        completedTasks: Int,
        createdTasks: Int
    ) {
        self.id = id
        self.projectId = projectId
        self.date = date
        self.remainingPoints = remainingPoints
        self.completedPoints = completedPoints
        self.completedTasks = completedTasks
        self.createdTasks = createdTasks
    }
}

// MARK: - Sprints

public enum SprintStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case active
    case closed
    case completed

    public var isClosedLike: Bool {
        self == .closed || self == .completed
    }
}

public struct SprintDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let projectId: UUID
    public let name: String
    public let startDate: Date
    public let endDate: Date
    public let status: SprintStatus
    public let capacity: Double?
    public let createdAt: Date?

    public init(
        id: UUID,
        projectId: UUID,
        name: String,
        startDate: Date,
        endDate: Date,
        status: SprintStatus,
        capacity: Double? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.capacity = capacity
        self.createdAt = createdAt
    }
}

public struct CreateSprintRequest: Codable, Sendable {
    public let name: String
    public let startDate: Date
    public let endDate: Date
    public let status: SprintStatus?
    public let capacity: Double?

    public init(name: String, startDate: Date, endDate: Date, status: SprintStatus? = nil, capacity: Double? = nil) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.capacity = capacity
    }
}

// MARK: - Reporting Series

/// Weekly throughput bucket (UTC ISO week start).
public struct WeeklyThroughputPointDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let weekStart: Date
    public let completedTasks: Int

    public init(id: UUID = UUID(), weekStart: Date, completedTasks: Int) {
        self.id = id
        self.weekStart = weekStart
        self.completedTasks = completedTasks
    }
}

/// Sprint velocity series point (computed from tasks completed within the sprint window).
public struct SprintVelocityPointDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let sprintId: UUID
    public let name: String
    public let startDate: Date
    public let endDate: Date
    public let completedPoints: Double
    public let completedTasks: Int

    public init(
        id: UUID = UUID(),
        sprintId: UUID,
        name: String,
        startDate: Date,
        endDate: Date,
        completedPoints: Double,
        completedTasks: Int
    ) {
        self.id = id
        self.sprintId = sprintId
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.completedPoints = completedPoints
        self.completedTasks = completedTasks
    }
}

// MARK: - Report Payload (for CSV/PDF export)

/// Server-provided report payload; iOS renders PDF locally from this structured JSON.
public struct AnalyticsReportPayloadDTO: Codable, Sendable {
    public let projectId: UUID
    public let projectName: String
    public let from: Date
    public let to: Date
    public let generatedAt: Date

    public let leadTime: AnalyticsResponseDTO<Double>?
    public let cycleTime: AnalyticsResponseDTO<Double>?
    public let velocity: AnalyticsResponseDTO<Double>?
    public let throughput: AnalyticsResponseDTO<Int>?

    public let burndown: [ProjectDailyStatsDTO]
    public let weeklyThroughput: [WeeklyThroughputPointDTO]
    public let sprintVelocity: [SprintVelocityPointDTO]

    public init(
        projectId: UUID,
        projectName: String,
        from: Date,
        to: Date,
        generatedAt: Date = Date(),
        leadTime: AnalyticsResponseDTO<Double>? = nil,
        cycleTime: AnalyticsResponseDTO<Double>? = nil,
        velocity: AnalyticsResponseDTO<Double>? = nil,
        throughput: AnalyticsResponseDTO<Int>? = nil,
        burndown: [ProjectDailyStatsDTO] = [],
        weeklyThroughput: [WeeklyThroughputPointDTO] = [],
        sprintVelocity: [SprintVelocityPointDTO] = []
    ) {
        self.projectId = projectId
        self.projectName = projectName
        self.from = from
        self.to = to
        self.generatedAt = generatedAt
        self.leadTime = leadTime
        self.cycleTime = cycleTime
        self.velocity = velocity
        self.throughput = throughput
        self.burndown = burndown
        self.weeklyThroughput = weeklyThroughput
        self.sprintVelocity = sprintVelocity
    }
}
