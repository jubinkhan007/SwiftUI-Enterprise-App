import Fluent
import Vapor
import SharedModels

/// Fluent database model for a Sprint.
final class SprintModel: Model, Content, @unchecked Sendable {
    static let schema = "sprints"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: ProjectModel

    @Field(key: "name")
    var name: String

    @Field(key: "start_date")
    var startDate: Date

    @Field(key: "end_date")
    var endDate: Date

    @Enum(key: "status")
    var status: SprintStatus

    @OptionalField(key: "capacity")
    var capacity: Double?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, projectId: UUID, name: String, startDate: Date, endDate: Date, status: SprintStatus = .planned, capacity: Double? = nil) {
        self.id = id
        self.$project.id = projectId
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.capacity = capacity
    }

    func toDTO() -> SprintDTO {
        SprintDTO(
            id: id ?? UUID(),
            projectId: $project.id,
            name: name,
            startDate: startDate,
            endDate: endDate,
            status: status,
            capacity: capacity,
            createdAt: createdAt
        )
    }
}
