import Foundation
import SwiftData
import SharedModels
import AppNetwork

public protocol LocalSyncOperationStoreProtocol: Sendable {
    func fetchPending(orgId: UUID) async throws -> [LocalSyncOperation]
    func fetchNeedsAttention(orgId: UUID) async throws -> [LocalSyncOperation]
    func enqueueOrSquash(_ operation: LocalSyncOperation) async throws
    func delete(_ operation: LocalSyncOperation) async throws
    func deleteOperations(orgId: UUID, entityType: SyncEntityType, entityId: UUID) async throws
    func save() async throws
}

@MainActor
public final class LocalSyncOperationStore: LocalSyncOperationStoreProtocol, @unchecked Sendable {
    private let modelContainer: ModelContainer

    public init(container: ModelContainer) {
        self.modelContainer = container
    }

    public func fetchPending(orgId: UUID) async throws -> [LocalSyncOperation] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<LocalSyncOperation>(
            predicate: #Predicate { $0.orgId == orgId && $0.needsAttention == false },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    public func fetchNeedsAttention(orgId: UUID) async throws -> [LocalSyncOperation] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<LocalSyncOperation>(
            predicate: #Predicate { $0.orgId == orgId && $0.needsAttention == true },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    public func enqueueOrSquash(_ operation: LocalSyncOperation) async throws {
        let context = modelContainer.mainContext

        let orgId = operation.orgId
        let entityId = operation.entityId
        let entityTypeRawValue = operation.entityTypeRawValue

        var descriptor = FetchDescriptor<LocalSyncOperation>(
            predicate: #Predicate {
                $0.orgId == orgId &&
                $0.entityId == entityId &&
                $0.entityTypeRawValue == entityTypeRawValue &&
                $0.needsAttention == false
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = 50
        let existing = try context.fetch(descriptor)

        if existing.isEmpty {
            context.insert(operation)
            try context.save()
            return
        }

        // Squash against the most recent operation for this entity.
        guard let last = existing.last else {
            context.insert(operation)
            try context.save()
            return
        }

        let squashed = try Self.squash(last: last, incoming: operation, context: context)
        if squashed {
            try context.save()
            return
        }

        context.insert(operation)
        try context.save()
    }

    public func delete(_ operation: LocalSyncOperation) async throws {
        let context = modelContainer.mainContext
        context.delete(operation)
        try context.save()
    }

    public func deleteOperations(orgId: UUID, entityType: SyncEntityType, entityId: UUID) async throws {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<LocalSyncOperation>(
            predicate: #Predicate {
                $0.orgId == orgId &&
                $0.entityId == entityId &&
                $0.entityTypeRawValue == entityType.rawValue
            }
        )
        let ops = try context.fetch(descriptor)
        for op in ops {
            context.delete(op)
        }
        try context.save()
    }

    public func save() async throws {
        let context = modelContainer.mainContext
        if context.hasChanges {
            try context.save()
        }
    }

    // MARK: - Squashing

    private static func squash(last: LocalSyncOperation, incoming: LocalSyncOperation, context: ModelContext) throws -> Bool {
        switch (last.operation, incoming.operation) {
        case (.put, .put):
            try mergePutIntoPut(target: last, incoming: incoming)
            return true
        case (.post, .put):
            try foldPutIntoPost(target: last, incoming: incoming)
            return true
        case (.put, .delete):
            context.delete(last)
            // Replace with a single DELETE.
            context.insert(incoming)
            return true
        case (.post, .delete):
            // Create + delete before sync => no-op.
            context.delete(last)
            return true
        case (.delete, .put):
            last.needsAttention = true
            last.lastError = "Invalid offline sequence: DELETE followed by PUT."
            return true
        default:
            return false
        }
    }

    private static func mergePutIntoPut(target: LocalSyncOperation, incoming: LocalSyncOperation) throws {
        let mergedPayload = try mergeUpdatePayload(
            olderJSON: target.payloadJSON,
            newerJSON: incoming.payloadJSON
        )
        target.payloadJSON = mergedPayload.payloadJSON
        target.dirtyFields = Array(Set(target.dirtyFields + incoming.dirtyFields)).sorted()
        target.baseSnapshotJSON = try mergeBaseSnapshot(
            olderJSON: target.baseSnapshotJSON,
            newerJSON: incoming.baseSnapshotJSON
        )
        target.timestamp = max(target.timestamp, incoming.timestamp)
    }

    private static func foldPutIntoPost(target: LocalSyncOperation, incoming: LocalSyncOperation) throws {
        guard target.operation == .post else { return }
        guard let postJSON = target.payloadJSON else { return }
        guard let putJSON = incoming.payloadJSON else { return }

        let create = try JSONCoding.decoder.decode(CreateTaskRequest.self, from: Data(postJSON.utf8))
        let update = try JSONCoding.decoder.decode(UpdateTaskRequest.self, from: Data(putJSON.utf8))

        let merged = mergeCreatePayload(create: create, update: update)
        let mergedData = try JSONCoding.encoder.encode(merged)
        target.payloadJSON = String(decoding: mergedData, as: UTF8.self)
        target.timestamp = max(target.timestamp, incoming.timestamp)
    }

    private struct MergedUpdatePayload {
        let payloadJSON: String?
    }

    private static func mergeUpdatePayload(olderJSON: String?, newerJSON: String?) throws -> MergedUpdatePayload {
        var older = (olderJSON.flatMap { try? JSONCoding.decoder.decode(UpdateTaskRequest.self, from: Data($0.utf8)) }) ?? UpdateTaskRequest()
        let newer = (newerJSON.flatMap { try? JSONCoding.decoder.decode(UpdateTaskRequest.self, from: Data($0.utf8)) }) ?? UpdateTaskRequest()

        // Preserve the earliest expectedVersion if present.
        if older.expectedVersion == nil {
            older.expectedVersion = newer.expectedVersion
        }

        if let v = newer.title { older.title = v }
        if let v = newer.description { older.description = v }
        if let v = newer.statusId { older.statusId = v }
        if let v = newer.status { older.status = v }
        if let v = newer.priority { older.priority = v }
        if let v = newer.taskType { older.taskType = v }
        if let v = newer.storyPoints { older.storyPoints = v }
        if let v = newer.labels { older.labels = v }
        if let v = newer.startDate { older.startDate = v }
        if let v = newer.dueDate { older.dueDate = v }
        if let v = newer.assigneeId { older.assigneeId = v }
        if let v = newer.listId { older.listId = v }
        if let v = newer.position { older.position = v }
        if let v = newer.archivedAt { older.archivedAt = v }
        if let v = newer.sprintId { older.sprintId = v }
        if let v = newer.backlogPosition { older.backlogPosition = v }
        if let v = newer.sprintPosition { older.sprintPosition = v }
        if let v = newer.bugSeverity { older.bugSeverity = v }
        if let v = newer.bugEnvironment { older.bugEnvironment = v }
        if let v = newer.affectedVersionId { older.affectedVersionId = v }
        if let v = newer.expectedResult { older.expectedResult = v }
        if let v = newer.actualResult { older.actualResult = v }
        if let v = newer.reproductionSteps { older.reproductionSteps = v }

        let data = try JSONCoding.encoder.encode(older)
        return MergedUpdatePayload(payloadJSON: String(decoding: data, as: UTF8.self))
    }

    private static func mergeBaseSnapshot(olderJSON: String?, newerJSON: String?) throws -> String? {
        var older = (olderJSON.flatMap { try? JSONCoding.decoder.decode(TaskFieldSnapshot.self, from: Data($0.utf8)) }) ?? TaskFieldSnapshot()
        let newer = (newerJSON.flatMap { try? JSONCoding.decoder.decode(TaskFieldSnapshot.self, from: Data($0.utf8)) }) ?? TaskFieldSnapshot()

        if older.title == nil { older.title = newer.title }
        if older.description == nil { older.description = newer.description }
        if older.statusId == nil { older.statusId = newer.statusId }
        if older.status == nil { older.status = newer.status }
        if older.priority == nil { older.priority = newer.priority }
        if older.taskType == nil { older.taskType = newer.taskType }
        if older.storyPoints == nil { older.storyPoints = newer.storyPoints }
        if older.labels == nil { older.labels = newer.labels }
        if older.startDate == nil { older.startDate = newer.startDate }
        if older.dueDate == nil { older.dueDate = newer.dueDate }
        if older.assigneeId == nil { older.assigneeId = newer.assigneeId }
        if older.listId == nil { older.listId = newer.listId }
        if older.position == nil { older.position = newer.position }
        if older.archivedAt == nil { older.archivedAt = newer.archivedAt }
        if older.sprintId == nil { older.sprintId = newer.sprintId }
        if older.backlogPosition == nil { older.backlogPosition = newer.backlogPosition }
        if older.sprintPosition == nil { older.sprintPosition = newer.sprintPosition }
        if older.bugSeverity == nil { older.bugSeverity = newer.bugSeverity }
        if older.bugEnvironment == nil { older.bugEnvironment = newer.bugEnvironment }
        if older.affectedVersionId == nil { older.affectedVersionId = newer.affectedVersionId }
        if older.expectedResult == nil { older.expectedResult = newer.expectedResult }
        if older.actualResult == nil { older.actualResult = newer.actualResult }
        if older.reproductionSteps == nil { older.reproductionSteps = newer.reproductionSteps }

        let data = try JSONCoding.encoder.encode(older)
        return String(decoding: data, as: UTF8.self)
    }

    private static func mergeCreatePayload(create: CreateTaskRequest, update: UpdateTaskRequest) -> CreateTaskRequest {
        CreateTaskRequest(
            id: create.id,
            title: update.title ?? create.title,
            description: update.description ?? create.description,
            statusId: update.statusId ?? create.statusId,
            status: update.status ?? create.status,
            priority: update.priority ?? create.priority,
            taskType: update.taskType ?? create.taskType,
            parentId: create.parentId,
            storyPoints: update.storyPoints ?? create.storyPoints,
            labels: update.labels ?? create.labels,
            startDate: update.startDate ?? create.startDate,
            dueDate: update.dueDate ?? create.dueDate,
            assigneeId: update.assigneeId ?? create.assigneeId,
            listId: update.listId ?? create.listId,
            sprintId: update.sprintId ?? create.sprintId,
            backlogPosition: update.backlogPosition ?? create.backlogPosition,
            sprintPosition: update.sprintPosition ?? create.sprintPosition,
            bugSeverity: update.bugSeverity ?? create.bugSeverity,
            bugEnvironment: update.bugEnvironment ?? create.bugEnvironment,
            affectedVersionId: update.affectedVersionId ?? create.affectedVersionId,
            expectedResult: update.expectedResult ?? create.expectedResult,
            actualResult: update.actualResult ?? create.actualResult,
            reproductionSteps: update.reproductionSteps ?? create.reproductionSteps
        )
    }
}
