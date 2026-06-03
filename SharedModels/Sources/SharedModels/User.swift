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
    /// Platform-level super-admin flag. Optional for backward compatibility with
    /// older clients; `nil` is treated as `false`.
    public let isSuperAdmin: Bool?

    public init(
        id: UUID = UUID(),
        email: String,
        displayName: String,
        role: UserRole = .member,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        isSuperAdmin: Bool? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSuperAdmin = isSuperAdmin
    }
}
