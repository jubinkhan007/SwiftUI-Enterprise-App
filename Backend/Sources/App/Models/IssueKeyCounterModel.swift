import Foundation
import Fluent

/// Atomic per-project counter for Issue Keys (e.g. APP-42).
final class IssueKeyCounterModel: Model, @unchecked Sendable {
    static let schema = "issue_key_counters"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "project_id")
    var project: ProjectModel

    @Field(key: "next_number")
    var nextNumber: Int

    init() {}

    init(id: UUID? = nil, projectId: UUID, nextNumber: Int) {
        self.id = id
        self.$project.id = projectId
        self.nextNumber = nextNumber
    }
}
