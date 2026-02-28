import Fluent
import Vapor
import SharedModels

/// Project-scoped custom workflow status definition.
final class CustomStatusModel: Model, Content, @unchecked Sendable {
    static let schema = "custom_statuses"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: ProjectModel

    @Field(key: "name")
    var name: String

    /// Hex color string, e.g. "#4F46E5"
    @Field(key: "color")
    var color: String

    /// Sorting position for UI ordering.
    @Field(key: "position")
    var position: Double

    /// Category mapping for analytics / fallbacks.
    @Enum(key: "category")
    var category: WorkflowStatusCategory

    /// Where new tasks start for this project. At least one per project is required.
    @Field(key: "is_default")
    var isDefault: Bool

    /// Indicates completed/cancelled states.
    @Field(key: "is_final")
    var isFinal: Bool

    /// Prevent deletion of system/base statuses.
    @Field(key: "is_locked")
    var isLocked: Bool

    /// Optional mapping back to legacy `TaskStatus` for compatibility.
    @OptionalField(key: "legacy_status")
    var legacyStatus: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        projectId: UUID,
        name: String,
        color: String,
        position: Double,
        category: WorkflowStatusCategory,
        isDefault: Bool = false,
        isFinal: Bool = false,
        isLocked: Bool = false,
        legacyStatus: String? = nil
    ) {
        self.id = id
        self.$project.id = projectId
        self.name = name
        self.color = color
        self.position = position
        self.category = category
        self.isDefault = isDefault
        self.isFinal = isFinal
        self.isLocked = isLocked
        self.legacyStatus = legacyStatus
    }
}
