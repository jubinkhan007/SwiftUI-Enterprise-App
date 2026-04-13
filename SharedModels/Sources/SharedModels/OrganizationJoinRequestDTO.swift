import Foundation

public struct OrganizationJoinRequestDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let orgId: UUID
    public let userId: UUID
    public let userDisplayName: String
    public let userEmail: String
    public let status: String // "pending", "accepted", "rejected"
    public let createdAt: Date?

    public init(
        id: UUID,
        orgId: UUID,
        userId: UUID,
        userDisplayName: String,
        userEmail: String,
        status: String,
        createdAt: Date?
    ) {
        self.id = id
        self.orgId = orgId
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.userEmail = userEmail
        self.status = status
        self.createdAt = createdAt
    }
}

public struct RespondToJoinRequestRequest: Codable, Sendable, Hashable {
    public let action: String // "accept", "reject"

    public init(action: String) {
        self.action = action
    }
}
