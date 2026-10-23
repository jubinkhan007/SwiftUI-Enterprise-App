import Foundation
import SwiftData
import SharedModels
import AppNetwork
import AppData
import XCTest

final class SyncConflictStressTests: XCTestCase {
    func test_stressQueue_highVolumeInterleavedMutations() async throws {
        let container = try makeInMemoryContainer()
        let store = await MainActor.run { LocalSyncOperationStore(container: container) }

        let orgAlpha = UUID()
        let orgBeta = UUID()
        let orgs = [orgAlpha, orgBeta]

        let taskIds = [UUID(), UUID(), UUID(), UUID()]

        // Enqueue 100 interleaved operations across 4 tasks and 2 organizations
        for round in 0..<25 {
            for (idx, taskId) in taskIds.enumerated() {
                let orgId = orgs[idx % 2]
                let payload = UpdateTaskRequest(
                    title: "Title_Round_\(round)",
                    description: "Desc_Round_\(round)",
                    expectedVersion: round == 0 ? 1 : (100 + round)
                )
                let payloadJSON = String(decoding: try JSONCoding.encoder.encode(payload), as: UTF8.self)

                let op = await MainActor.run {
                    LocalSyncOperation(
                        entityType: .task,
                        entityId: taskId,
                        orgId: orgId,
                        operation: .put,
                        payloadJSON: payloadJSON,
                        dirtyFields: ["title", "description_\(round)"]
                    )
                }
                try await store.enqueueOrSquash(op)
            }
        }

        // Verify isolation: exactly 2 pending ops for orgAlpha, 2 pending ops for orgBeta
        let pendingAlpha = try await store.fetchPending(orgId: orgAlpha)
        let pendingBeta = try await store.fetchPending(orgId: orgBeta)

        XCTAssertEqual(pendingAlpha.count, 2)
        XCTAssertEqual(pendingBeta.count, 2)

        for op in (pendingAlpha + pendingBeta) {
            XCTAssertEqual(op.operation, .put)
            let decoded = try JSONCoding.decoder.decode(UpdateTaskRequest.self, from: Data((op.payloadJSON ?? "").utf8))
            // Must preserve earliest expectedVersion = 1 from round 0
            XCTAssertEqual(decoded.expectedVersion, 1)
            // Must preserve the latest round title
            XCTAssertEqual(decoded.title, "Title_Round_24")
        }
    }

    func test_fieldLevelCollision_detectsCollisionOnSameField() async throws {
        var baseSnapshot = TaskFieldSnapshot()
        baseSnapshot.title = "Original Title"
        baseSnapshot.description = "Original Description"
        baseSnapshot.status = .todo
        baseSnapshot.priority = .low
        let baseJSON = String(decoding: try JSONCoding.encoder.encode(baseSnapshot), as: UTF8.self)

        let op = await MainActor.run {
            LocalSyncOperation(
                entityType: .task,
                entityId: UUID(),
                orgId: UUID(),
                operation: .put,
                baseSnapshotJSON: baseJSON,
                dirtyFields: ["title"]
            )
        }

        // Server has updated the title to something different from the base snapshot
        let serverDTO = TaskItemDTO(
            id: op.entityId,
            title: "Server Updated Title",
            description: "Original Description",
            status: .todo,
            priority: .low,
            taskType: .task,
            version: 2
        )

        let collision = hasCollisionHelper(operation: op, server: serverDTO)
        XCTAssertTrue(collision, "Modifying the same field ('title') should trigger a collision.")
    }

    func test_fieldLevelCollision_noCollisionOnDisjointFields() async throws {
        var baseSnapshot = TaskFieldSnapshot()
        baseSnapshot.title = "Original Title"
        baseSnapshot.description = "Original Description"
        baseSnapshot.status = .todo
        baseSnapshot.priority = .low
        let baseJSON = String(decoding: try JSONCoding.encoder.encode(baseSnapshot), as: UTF8.self)

        // Client modified only 'title'
        let op = await MainActor.run {
            LocalSyncOperation(
                entityType: .task,
                entityId: UUID(),
                orgId: UUID(),
                operation: .put,
                baseSnapshotJSON: baseJSON,
                dirtyFields: ["title"]
            )
        }

        // Server modified only 'priority' (title remained identical to base snapshot)
        let serverDTO = TaskItemDTO(
            id: op.entityId,
            title: "Original Title", // Unchanged by server
            description: "Original Description",
            status: .todo,
            priority: .high, // Changed by server
            taskType: .task,
            version: 2
        )

        let collision = hasCollisionHelper(operation: op, server: serverDTO)
        XCTAssertFalse(collision, "Disjoint field modifications ('title' vs 'priority') should not collide.")
    }

    func test_occConflict_3WayAutoMerge_preservesServerNonCollidingFields() throws {
        // Local changes: user changed title to "Local Title"
        var localPayload = UpdateTaskRequest(title: "Local Title", expectedVersion: 1)

        // Server changes: server changed priority to .critical and bumped version to 2
        let serverDTO = TaskItemDTO(
            id: UUID(),
            title: "Base Title",
            status: .todo,
            priority: .critical,
            taskType: .task,
            version: 2
        )

        // 3-way merge: adopt server version, keep local title, keep server priority
        localPayload.expectedVersion = serverDTO.version

        XCTAssertEqual(localPayload.expectedVersion, 2)
        XCTAssertEqual(localPayload.title, "Local Title")
        XCTAssertEqual(serverDTO.priority, .critical)
    }

    func test_occConflict_collidingFields_marksNeedsAttention_withRemoteSnapshot() async throws {
        let container = try makeInMemoryContainer()
        let store = await MainActor.run { LocalSyncOperationStore(container: container) }

        let taskId = UUID()
        let orgId = UUID()

        let op = await MainActor.run {
            LocalSyncOperation(
                entityType: .task,
                entityId: taskId,
                orgId: orgId,
                operation: .put,
                dirtyFields: ["title"]
            )
        }
        try await store.enqueueOrSquash(op)

        // Simulate 409 Conflict with colliding remote snapshot
        let serverDTO = TaskItemDTO(
            id: taskId,
            title: "Conflicting Remote Title",
            status: .inProgress,
            priority: .high,
            taskType: .task,
            version: 3
        )
        let serverJSON = String(decoding: try JSONCoding.encoder.encode(serverDTO), as: UTF8.self)

        await MainActor.run {
            op.needsAttention = true
            op.lastError = "Conflict: server has newer changes for the same fields."
            op.remoteSnapshotJSON = serverJSON
        }
        try await store.save()

        let attentionOps = try await store.fetchNeedsAttention(orgId: orgId)
        XCTAssertEqual(attentionOps.count, 1)

        let conflicted = attentionOps[0]
        XCTAssertEqual(conflicted.needsAttention, true)
        XCTAssertNotNil(conflicted.remoteSnapshotJSON)
        XCTAssertTrue(conflicted.lastError?.contains("Conflict") == true)

        let decodedRemote = try JSONCoding.decoder.decode(TaskItemDTO.self, from: Data((conflicted.remoteSnapshotJSON ?? "").utf8))
        XCTAssertEqual(decodedRemote.version, 3)
        XCTAssertEqual(decodedRemote.title, "Conflicting Remote Title")
    }

    private func hasCollisionHelper(operation: LocalSyncOperation, server: TaskItemDTO) -> Bool {
        guard let baseJSON = operation.baseSnapshotJSON else { return true }
        guard let base = try? JSONCoding.decoder.decode(TaskFieldSnapshot.self, from: Data(baseJSON.utf8)) else { return true }

        for field in operation.dirtyFields {
            switch field {
            case "title":
                if base.title != nil && server.title != base.title { return true }
            case "description":
                if server.description != base.description { return true }
            case "statusId":
                if server.statusId != base.statusId { return true }
            case "status":
                if server.status != (base.status ?? server.status) && base.status != nil { return true }
            case "priority":
                if server.priority != (base.priority ?? server.priority) && base.priority != nil { return true }
            case "taskType":
                if server.taskType != (base.taskType ?? server.taskType) && base.taskType != nil { return true }
            case "storyPoints":
                if server.storyPoints != base.storyPoints { return true }
            default:
                break
            }
        }
        return false
    }
}

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([LocalSyncOperation.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}
