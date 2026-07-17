import Foundation

/// A Data Transfer Object representing a user login session.
public struct UserSessionDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let userId: UUID
    public let deviceType: String
    public let ipAddress: String
    public let userAgent: String
    public let isRevoked: Bool
    public let expiresAt: Date
    public let createdAt: Date?

    public init(
        id: UUID,
        userId: UUID,
        deviceType: String,
        ipAddress: String,
        userAgent: String,
        isRevoked: Bool,
        expiresAt: Date,
        createdAt: Date?
    ) {
        self.id = id
        self.userId = userId
        self.deviceType = deviceType
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.isRevoked = isRevoked
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}
