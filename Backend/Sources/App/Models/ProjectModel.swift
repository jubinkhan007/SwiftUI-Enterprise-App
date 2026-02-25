import Fluent
import Vapor
import SharedModels

/// Represents a distinct initiative or grouping within a Space.
/// Hierarchy: Workspace -> Space -> Project -> TaskList -> Task
final class ProjectModel: Model, @unchecked Sendable {
    static let schema = "projects"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "space_id")
    var space: SpaceModel

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
    @Children(for: \.$project)
    var taskLists: [TaskListModel]

    init() {}

    init(id: UUID? = nil, spaceId: UUID, name: String, description: String? = nil, position: Double = 0.0, archivedAt: Date? = nil) {
        self.id = id
        self.$space.id = spaceId
        self.name = name
        self.description = description
        self.position = position
        self.archivedAt = archivedAt
    }
}
