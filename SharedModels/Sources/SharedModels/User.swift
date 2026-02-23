import Foundation

// MARK: - User DTO

/// A Data Transfer Object representing a user profile.
/// Used for API communication between the client and server.
public struct UserDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let email: String
    public let displayName: String
    public let role: UserRole
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID = UUID(),
        email: String,
        displayName: String,
        role: UserRole = .member,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
