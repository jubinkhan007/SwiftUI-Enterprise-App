import Fluent
import Vapor
import SharedModels

/// Represents a top-level grouping within a Workspace (Organization).
/// Hierarchy: Workspace -> Space -> Project -> TaskList -> Task
final class SpaceModel: Model, @unchecked Sendable {
    static let schema = "spaces"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Field(key: "name")
    var name: String

    @OptionalField(key: "description")
    var description: String?

    @Field(key: "position")
    var position: Double

    @OptionalField(key: "archived_at")
    var archivedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // Relationships
    @Children(for: \.$space)
    var projects: [ProjectModel]

    init() {}

    init(id: UUID? = nil, orgId: UUID, name: String, description: String? = nil, position: Double = 0.0, archivedAt: Date? = nil) {
        self.id = id
        self.$organization.id = orgId
        self.name = name
        self.description = description
        self.position = position
        self.archivedAt = archivedAt
    }
}
