import Fluent
import Vapor
import SharedModels

/// Fluent database model for an Organization (Workspace).
final class OrganizationModel: Model, Content, @unchecked Sendable {
    static let schema = "organizations"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "slug")
    var slug: String

    @OptionalField(key: "description")
    var description: String?

    @Parent(key: "owner_id")
    var owner: UserModel

    /// Lifecycle status: "active" or "suspended".
    @Field(key: "status")
    var status: String

    /// Message retention window in days. `nil` means retain indefinitely.
    @OptionalField(key: "retention_days")
    var retentionDays: Int?

    @Children(for: \.$organization)
    var members: [OrganizationMemberModel]

    @Children(for: \.$organization)
    var invites: [OrganizationInviteModel]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        slug: String,
        description: String? = nil,
        ownerId: UUID,
        status: String = "active",
        retentionDays: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.$owner.id = ownerId
        self.status = status
        self.retentionDays = retentionDays
    }

    /// Convert to the shared DTO for API responses.
    func toDTO(memberCount: Int? = nil) -> OrganizationDTO {
        OrganizationDTO(
            id: id ?? UUID(),
            name: name,
            slug: slug,
            description: description,
            ownerId: $owner.id,
            memberCount: memberCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            status: status,
            retentionDays: retentionDays
        )
    }
}
