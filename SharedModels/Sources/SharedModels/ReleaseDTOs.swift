import Foundation

// MARK: - Releases (Phase 13)

public enum ReleaseStatus: String, Codable, CaseIterable, Sendable {
    case unreleased
    case released
    case archived
}

public struct ReleaseDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let projectId: UUID
    public let name: String
    public let description: String?
    public let releaseDate: Date?
    public let releasedAt: Date?
    public let status: ReleaseStatus
    public let isLocked: Bool
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        projectId: UUID,
        name: String,
        description: String? = nil,
        releaseDate: Date? = nil,
        releasedAt: Date? = nil,
        status: ReleaseStatus = .unreleased,
        isLocked: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.description = description
        self.releaseDate = releaseDate
        self.releasedAt = releasedAt
        self.status = status
        self.isLocked = isLocked
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CreateReleaseRequest: Codable, Sendable {
    public let name: String
    public let description: String?
    public let releaseDate: Date?

    public init(name: String, description: String? = nil, releaseDate: Date? = nil) {
        self.name = name
        self.description = description
        self.releaseDate = releaseDate
    }
}

public struct ReleaseProgressDTO: Codable, Sendable, Equatable {
    public let releaseId: UUID
    public let totalIssues: Int
    public let doneIssues: Int
    public let remainingIssues: Int
    public let totalPoints: Int
    public let donePoints: Int
    public let bugCount: Int
    public let criticalBugCount: Int

    public init(
        releaseId: UUID,
        totalIssues: Int,
        doneIssues: Int,
        remainingIssues: Int,
        totalPoints: Int,
        donePoints: Int,
        bugCount: Int,
        criticalBugCount: Int
    ) {
        self.releaseId = releaseId
        self.totalIssues = totalIssues
        self.doneIssues = doneIssues
        self.remainingIssues = remainingIssues
        self.totalPoints = totalPoints
        self.donePoints = donePoints
        self.bugCount = bugCount
        self.criticalBugCount = criticalBugCount
    }
}

public struct FinalizeReleaseRequest: Codable, Sendable {
    public let lock: Bool?

    public init(lock: Bool? = nil) {
        self.lock = lock
    }
}

