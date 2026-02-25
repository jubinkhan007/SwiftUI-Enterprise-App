import Foundation

// MARK: - Organization DTO

/// A Data Transfer Object representing a workspace / organization.
public struct OrganizationDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let slug: String
    public let description: String?
    public let ownerId: UUID
    public let memberCount: Int?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        slug: String,
        description: String? = nil,
        ownerId: UUID,
        memberCount: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.ownerId = ownerId
        self.memberCount = memberCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Organization Member DTO

/// Represents a user's membership within a specific organization.
public struct OrganizationMemberDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let userId: UUID
    public let orgId: UUID
    public let role: UserRole
    public let displayName: String
    public let email: String
    public let joinedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        orgId: UUID,
        role: UserRole,
        displayName: String,
        email: String,
        joinedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.orgId = orgId
        self.role = role
        self.displayName = displayName
        self.email = email
        self.joinedAt = joinedAt
    }
}

// MARK: - Organization Invite DTO

/// Represents an invitation to join an organization.
public struct OrganizationInviteDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let orgId: UUID
    public let email: String
    public let role: UserRole
    public let status: InviteStatus
    public let invitedBy: UUID
    public let expiresAt: Date
    public let createdAt: Date?

    public init(
        id: UUID = UUID(),
        orgId: UUID,
        email: String,
        role: UserRole,
        status: InviteStatus = .pending,
        invitedBy: UUID,
        expiresAt: Date,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.orgId = orgId
        self.email = email
        self.role = role
        self.status = status
        self.invitedBy = invitedBy
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

// MARK: - Pending Invite DTO

/// Represents a pending invite visible to the invited user.
/// This includes lightweight workspace metadata so the client can display
/// "You were invited to <workspace>" without requiring org membership first.
public struct PendingInviteDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let orgId: UUID
    public let orgName: String
    public let role: UserRole
    public let invitedBy: UUID
    public let expiresAt: Date
    public let createdAt: Date?

    public init(
        id: UUID,
        orgId: UUID,
        orgName: String,
        role: UserRole,
        invitedBy: UUID,
        expiresAt: Date,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.orgId = orgId
        self.orgName = orgName
        self.role = role
        self.invitedBy = invitedBy
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

// MARK: - Create / Update Payloads

/// Payload for creating a new organization.
public struct CreateOrganizationRequest: Codable, Sendable {
    public let name: String
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

/// Payload for inviting a user to an organization.
public struct CreateInviteRequest: Codable, Sendable {
    public let email: String
    public let role: UserRole

    public init(email: String, role: UserRole = .member) {
        self.email = email
        self.role = role
    }
}

/// Payload for updating a member's role.
public struct UpdateMemberRoleRequest: Codable, Sendable {
    public let role: UserRole

    public init(role: UserRole) {
        self.role = role
    }
}

// MARK: - /api/me Response

/// Response payload for `GET /api/me?org_id=<id>`.
/// Returns the current user's membership, role, and computed permissions for the active org.
public struct MeResponse: Codable, Sendable, Equatable {
    public let user: UserDTO
    public let orgId: UUID?
    public let role: UserRole?
    public let permissions: PermissionSet?
    public let organizations: [OrganizationDTO]

    public init(
        user: UserDTO,
        orgId: UUID? = nil,
        role: UserRole? = nil,
        permissions: PermissionSet? = nil,
        organizations: [OrganizationDTO]
    ) {
        self.user = user
        self.orgId = orgId
        self.role = role
        self.permissions = permissions
        self.organizations = organizations
    }
}
