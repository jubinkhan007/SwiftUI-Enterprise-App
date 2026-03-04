import Fluent
import Vapor
import SharedModels

/// Represents a release/version for a project.
final class ReleaseModel: Model, Content, @unchecked Sendable {
    static let schema = "releases"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: ProjectModel

    @Field(key: "name")
    var name: String

    @OptionalField(key: "description")
    var description: String?

    @OptionalField(key: "release_date")
    var releaseDate: Date?

    @OptionalField(key: "released_at")
    var releasedAt: Date?

    @Enum(key: "status")
    var status: ReleaseStatus

    @Field(key: "is_locked")
    var isLocked: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        projectId: UUID,
        name: String,
        description: String? = nil,
        releaseDate: Date? = nil,
        releasedAt: Date? = nil,
        status: ReleaseStatus = .unreleased,
        isLocked: Bool = false
    ) {
        self.id = id
        self.$project.id = projectId
        self.name = name
        self.description = description
        self.releaseDate = releaseDate
        self.releasedAt = releasedAt
        self.status = status
        self.isLocked = isLocked
    }

    func toDTO() -> ReleaseDTO {
        ReleaseDTO(
            id: id ?? UUID(),
            projectId: $project.id,
            name: name,
            description: description,
            releaseDate: releaseDate,
            releasedAt: releasedAt,
            status: status,
            isLocked: isLocked,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

