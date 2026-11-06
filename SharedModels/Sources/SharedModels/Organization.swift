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
    /// Lifecycle status: "active" or "suspended". Optional for backward compatibility.
    public let status: String?
    /// Message retention window in days; `nil` (with `retentionConfigured == false`) means indefinite.
    public let retentionDays: Int?

    // SaaS fields
    public let subscriptionTier: String?
    public let stripeCustomerId: String?
    public let stripeSubscriptionId: String?
    public let subscriptionStatus: String?
    public let logoUrl: String?
    public let brandColorHex: String?
    public let customDomain: String?
    public let allowedEmailDomains: String? // Comma-separated domains e.g. "acme.com,acme.co"
    public let ssoEnabled: Bool?
    public let ssoIdpUrl: String?
    public let ssoEntityId: String?
    public let ssoCertificate: String?

    public init(
        id: UUID = UUID(),
        name: String,
        slug: String,
        description: String? = nil,
        ownerId: UUID,
        memberCount: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        status: String? = nil,
        retentionDays: Int? = nil,
        subscriptionTier: String? = nil,
        stripeCustomerId: String? = nil,
        stripeSubscriptionId: String? = nil,
        subscriptionStatus: String? = nil,
        logoUrl: String? = nil,
        brandColorHex: String? = nil,
        customDomain: String? = nil,
        allowedEmailDomains: String? = nil,
        ssoEnabled: Bool? = nil,
        ssoIdpUrl: String? = nil,
        ssoEntityId: String? = nil,
        ssoCertificate: String? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.ownerId = ownerId
        self.memberCount = memberCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.retentionDays = retentionDays
        self.subscriptionTier = subscriptionTier
        self.stripeCustomerId = stripeCustomerId
        self.stripeSubscriptionId = stripeSubscriptionId
        self.subscriptionStatus = subscriptionStatus
        self.logoUrl = logoUrl
        self.brandColorHex = brandColorHex
        self.customDomain = customDomain
        self.allowedEmailDomains = allowedEmailDomains
        self.ssoEnabled = ssoEnabled
        self.ssoIdpUrl = ssoIdpUrl
        self.ssoEntityId = ssoEntityId
        self.ssoCertificate = ssoCertificate
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

// MARK: - Billing Redirect DTO

/// Response payload for Stripe Checkout & Customer Portal session redirects.
public struct BillingRedirectDTO: Codable, Sendable, Equatable {
    public let url: String

    public init(url: String) {
        self.url = url
    }
}

// MARK: - Enterprise Branding, Domain, SSO & Compliance Payloads

public struct UpdateBrandingRequest: Codable, Sendable, Equatable {
    public let logoUrl: String?
    public let brandColorHex: String?

    public init(logoUrl: String?, brandColorHex: String?) {
        self.logoUrl = logoUrl
        self.brandColorHex = brandColorHex
    }
}

public struct UpdateDomainSettingsRequest: Codable, Sendable, Equatable {
    public let customDomain: String?
    public let allowedEmailDomains: String?

    public init(customDomain: String?, allowedEmailDomains: String?) {
        self.customDomain = customDomain
        self.allowedEmailDomains = allowedEmailDomains
    }
}

public struct UpdateSSOSettingsRequest: Codable, Sendable, Equatable {
    public let ssoEnabled: Bool
    public let ssoIdpUrl: String?
    public let ssoEntityId: String?
    public let ssoCertificate: String?

    public init(
        ssoEnabled: Bool,
        ssoIdpUrl: String?,
        ssoEntityId: String?,
        ssoCertificate: String?
    ) {
        self.ssoEnabled = ssoEnabled
        self.ssoIdpUrl = ssoIdpUrl
        self.ssoEntityId = ssoEntityId
        self.ssoCertificate = ssoCertificate
    }
}

public struct RetentionPolicyPayloadDTO: Codable, Sendable, Equatable {
    public let retentionDays: Int?

    public init(retentionDays: Int?) {
        self.retentionDays = retentionDays
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let retentionDays {
            try container.encode(retentionDays, forKey: .retentionDays)
        } else {
            try container.encodeNil(forKey: .retentionDays)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case retentionDays
    }
}

public struct PurgeResultPayloadDTO: Codable, Sendable, Equatable {
    public let deletedCount: Int

    public init(deletedCount: Int) {
        self.deletedCount = deletedCount
    }
}

public struct ComplianceExportDescriptorDTO: Codable, Sendable, Equatable {
    public let downloadUrl: String
    public let format: String
    public let sizeBytes: Int
    public let expiresAt: Date

    public init(downloadUrl: String, format: String, sizeBytes: Int, expiresAt: Date) {
        self.downloadUrl = downloadUrl
        self.format = format
        self.sizeBytes = sizeBytes
        self.expiresAt = expiresAt
    }
}

