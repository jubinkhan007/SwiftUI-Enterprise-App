import Fluent
import Vapor
import SharedModels

/// Fluent database model for an Organization Invitation.
final class OrganizationInviteModel: Model, Content, @unchecked Sendable {
    static let schema = "organization_invites"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Field(key: "email")
    var email: String

    @Enum(key: "role")
    var role: UserRole

    @Enum(key: "status")
    var status: InviteStatus

    @Field(key: "invited_by")
    var invitedBy: UUID

    @Field(key: "expires_at")
    var expiresAt: Date

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        orgId: UUID,
        email: String,
        role: UserRole = .member,
        status: InviteStatus = .pending,
        invitedBy: UUID,
        expiresAt: Date
    ) {
        self.id = id
        self.$organization.id = orgId
        self.email = email
        self.role = role
        self.status = status
        self.invitedBy = invitedBy
        self.expiresAt = expiresAt
    }

    /// Convert to the shared DTO for API responses.
    func toDTO() -> OrganizationInviteDTO {
        OrganizationInviteDTO(
            id: id ?? UUID(),
            orgId: $organization.id,
            email: email,
            role: role,
            status: status,
            invitedBy: invitedBy,
            expiresAt: expiresAt,
            createdAt: createdAt
        )
    }
}
