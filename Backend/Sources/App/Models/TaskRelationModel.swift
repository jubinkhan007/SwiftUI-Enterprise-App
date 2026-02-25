import Fluent
import Vapor
import SharedModels

/// Stores a canonical directed relationship between two tasks in the same org.
/// `blockedBy` is never stored — it is computed as the inverse of a `blocks` row.
final class TaskRelationModel: Model, Content, @unchecked Sendable {
    static let schema = "task_relations"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "source_task_id")
    var sourceTask: TaskItemModel

    @Parent(key: "target_task_id")
    var targetTask: TaskItemModel

    @Enum(key: "relation_type")
    var relationType: StoredRelationType

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        sourceTaskId: UUID,
        targetTaskId: UUID,
        relationType: StoredRelationType
    ) {
        self.id = id
        self.$sourceTask.id = sourceTaskId
        self.$targetTask.id = targetTaskId
        self.relationType = relationType
    }

    /// Convert to DTO from the perspective of `viewingTaskId`.
    /// If the viewing task is the source, it's a direct relation.
    /// If the viewing task is the target of a `blocks` row, it becomes `blockedBy`.
    func toDTO(viewingTaskId: UUID) -> TaskRelationDTO {
        let rowId = id ?? UUID()
        let isInverse = $targetTask.id == viewingTaskId

        if isInverse {
            // "A blocks me" → viewed as "blockedBy A"
            let inverseType: TaskRelationType = relationType == .blocks ? .blockedBy : relationType.shared
            return TaskRelationDTO(
                id: rowId,
                taskId: viewingTaskId,
                relatedTaskId: $sourceTask.id,
                relationType: inverseType,
                createdAt: createdAt ?? Date()
            )
        } else {
            return TaskRelationDTO(
                id: rowId,
                taskId: viewingTaskId,
                relatedTaskId: $targetTask.id,
                relationType: relationType.shared,
                createdAt: createdAt ?? Date()
            )
        }
    }
}

// MARK: - Stored Relation Type

/// The subset of `TaskRelationType` that is actually persisted in the database.
/// `blockedBy` is virtual and never stored.
enum StoredRelationType: String, Codable, CaseIterable {
    case blocks
    case relatesTo
    case duplicateOf

    var shared: TaskRelationType {
        switch self {
        case .blocks:      return .blocks
        case .relatesTo:   return .relatesTo
        case .duplicateOf: return .duplicateOf
        }
    }

    static func from(_ shared: TaskRelationType) -> StoredRelationType? {
        switch shared {
        case .blocks:      return .blocks
        case .relatesTo:   return .relatesTo
        case .duplicateOf: return .duplicateOf
        case .blockedBy:   return nil  // virtual, not stored directly
        }
    }
}
