import Fluent
import Vapor
import SharedModels

/// Represents a specifically targeted list or board of tasks within a Project.
/// Hierarchy: Workspace -> Space -> Project -> TaskList -> Task
final class TaskListModel: Model, @unchecked Sendable {
    static let schema = "task_lists"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: ProjectModel

    @Field(key: "name")
    var name: String

    @OptionalField(key: "color")
    var color: String? // Optional hex color code

    @Field(key: "position")
    var position: Double

    @OptionalField(key: "archived_at")
    var archivedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    // Relationships
    @Children(for: \.$list)
    var tasks: [TaskItemModel]

    init() {}

    init(id: UUID? = nil, projectId: UUID, name: String, color: String? = nil, position: Double = 0.0, archivedAt: Date? = nil) {
        self.id = id
        self.$project.id = projectId
        self.name = name
        self.color = color
        self.position = position
        self.archivedAt = archivedAt
    }
}
