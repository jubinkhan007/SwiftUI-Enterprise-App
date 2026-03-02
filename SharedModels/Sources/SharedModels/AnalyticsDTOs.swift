import Foundation

// MARK: - Sprint Status

public enum SprintStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case active
    case completed
}

// MARK: - Sprint DTO

public struct SprintDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let projectId: UUID
    public let name: String
    public let startDate: Date
    public let endDate: Date
    public let status: SprintStatus
    public let createdAt: Date?

    public init(id: UUID, projectId: UUID, name: String, startDate: Date, endDate: Date, status: SprintStatus, createdAt: Date? = nil) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.createdAt = createdAt
    }
}

// MARK: - Project Daily Stats DTO

public struct ProjectDailyStatsDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let projectId: UUID
    public let date: Date
    public let remainingPoints: Double
    public let completedPoints: Double
    public let completedTasks: Int
    public let createdTasks: Int

    public init(id: UUID, projectId: UUID, date: Date, remainingPoints: Double, completedPoints: Double, completedTasks: Int, createdTasks: Int) {
        self.id = id
        self.projectId = projectId
        self.date = date
        self.remainingPoints = remainingPoints
        self.completedPoints = completedPoints
        self.completedTasks = completedTasks
        self.createdTasks = createdTasks
    }
}

// MARK: - Analytics Response DTO

/// Standardized response format for Enterprise Trust analytics.
public struct AnalyticsResponseDTO<T: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let metric: String
    public let value: T
    public let p50: T?
    public let p90: T?
    public let sampleSize: Int
    public let from: Date
    public let to: Date
    public let filters: [String: String]

    public init(metric: String, value: T, p50: T? = nil, p90: T? = nil, sampleSize: Int, from: Date, to: Date, filters: [String: String]) {
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
