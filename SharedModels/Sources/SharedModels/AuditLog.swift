import Foundation

// MARK: - Audit Log DTO

/// A Data Transfer Object representing an audit log entry within a workspace.
public struct AuditLogDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let orgId: UUID
    public let userId: UUID
    public let userEmail: String
    public let action: String
    public let resourceType: String
    public let resourceId: UUID?
    public let details: String?
    public let createdAt: Date?

    public init(
        id: UUID = UUID(),
        orgId: UUID,
        userId: UUID,
        userEmail: String,
        action: String,
        resourceType: String,
        resourceId: UUID? = nil,
        details: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.orgId = orgId
        self.userId = userId
        self.userEmail = userEmail
        self.action = action
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.details = details
        self.createdAt = createdAt
    }
}
