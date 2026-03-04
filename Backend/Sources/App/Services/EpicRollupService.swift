import Foundation
import Fluent
import SharedModels

enum EpicRollupService {
    static func recomputeEpic(epicId: UUID, db: any Database) async throws {
        guard let epic = try await TaskItemModel.query(on: db)
            .filter(\.$id == epicId)
            .first()
        else {
            return
        }

        guard epic.taskType == .epic else { return }

        let children = try await TaskItemModel.query(on: db)
            .filter(\.$parent.$id == epicId)
            .filter(\.$archivedAt == nil)
            .all()

        var totalPoints = 0
        var donePoints = 0
        var doneCount = 0

        for c in children {
            let sp = c.storyPoints ?? 0
            totalPoints += sp
            let isDone = c.completedAt != nil || c.status == .done
            if isDone {
                doneCount += 1
                donePoints += sp
            }
        }

        epic.epicChildrenCount = children.count
        epic.epicChildrenDoneCount = doneCount
        epic.epicTotalPoints = totalPoints
        epic.epicCompletedPoints = donePoints

        try await epic.save(on: db)
    }
}
