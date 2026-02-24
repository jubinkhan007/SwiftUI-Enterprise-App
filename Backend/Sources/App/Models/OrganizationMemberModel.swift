import Fluent
import Vapor
import SharedModels

/// Fluent database model for an Organization Membership.
/// Links a user to an organization with a specific role.
final class OrganizationMemberModel: Model, Content, @unchecked Sendable {
    static let schema = "organization_members"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Parent(key: "user_id")
    var user: UserModel

    @Enum(key: "role")
    var role: UserRole

    @Timestamp(key: "joined_at", on: .create)
    var joinedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        orgId: UUID,
        userId: UUID,
        role: UserRole
    ) {
        self.id = id
        self.$organization.id = orgId
        self.$user.id = userId
        self.role = role
    }

    /// Convert to the shared DTO for API responses.
    func toDTO(displayName: String, email: String) -> OrganizationMemberDTO {
        OrganizationMemberDTO(
            id: id ?? UUID(),
            userId: $user.id,
            orgId: $organization.id,
            role: role,
            displayName: displayName,
            email: email,
            joinedAt: joinedAt
        )
    }
}
