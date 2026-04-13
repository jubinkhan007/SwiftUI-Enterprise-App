import Fluent
import Vapor
import SharedModels

/// Tracks user-initiated requests to join an organization.
final class OrganizationJoinRequestModel: Model, Content, @unchecked Sendable {
    static let schema = "organization_join_requests"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Parent(key: "user_id")
    var user: UserModel

    @Field(key: "status")
    var status: String  // "pending", "accepted", "rejected"

    @OptionalField(key: "responded_by")
    var respondedBy: UUID?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, orgId: UUID, userId: UUID, status: String = "pending", respondedBy: UUID? = nil) {
        self.id = id
        self.$organization.id = orgId
        self.$user.id = userId
        self.status = status
        self.respondedBy = respondedBy
    }

    func toDTO(orgName: String, userName: String, userEmail: String) -> OrganizationJoinRequestDTO {
        return OrganizationJoinRequestDTO(
            id: try! self.requireID(),
            orgId: self.$organization.id,
            userId: self.$user.id,
            userDisplayName: userName,
            userEmail: userEmail,
            status: self.status,
            createdAt: self.createdAt
        )
    }
}
