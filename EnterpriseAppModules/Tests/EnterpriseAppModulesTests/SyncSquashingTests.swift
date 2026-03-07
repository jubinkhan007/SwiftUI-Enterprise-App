import Foundation
import Testing
import SwiftData
import SharedModels
import AppNetwork
import AppData

@Test func syncSquash_putPlusPut_mergesPayloads() async throws {
    let container = try makeInMemoryContainer()
    let store = await MainActor.run { LocalSyncOperationStore(container: container) }

    let orgId = UUID()
    let taskId = UUID()

    let olderPayload = UpdateTaskRequest(title: "A", expectedVersion: 10)
    let newerPayload = UpdateTaskRequest(priority: .high, expectedVersion: 999)

    let olderJSON = String(decoding: try JSONCoding.encoder.encode(olderPayload), as: UTF8.self)
    let newerJSON = String(decoding: try JSONCoding.encoder.encode(newerPayload), as: UTF8.self)

    let op1 = await MainActor.run {
        LocalSyncOperation(entityType: .task, entityId: taskId, orgId: orgId, operation: .put, payloadJSON: olderJSON, dirtyFields: ["title"])
    }
    let op2 = await MainActor.run {
        LocalSyncOperation(entityType: .task, entityId: taskId, orgId: orgId, operation: .put, payloadJSON: newerJSON, dirtyFields: ["priority"])
    }

    try await store.enqueueOrSquash(op1)
    try await store.enqueueOrSquash(op2)

    let pending = try await store.fetchPending(orgId: orgId)
    #expect(pending.count == 1)
    #expect(pending[0].operation == .put)

    let merged = try JSONCoding.decoder.decode(UpdateTaskRequest.self, from: Data((pending[0].payloadJSON ?? "").utf8))
    #expect(merged.title == "A")
    #expect(merged.priority == .high)
    // ExpectedVersion should stay from the earliest op when both are present.
    #expect(merged.expectedVersion == 10)
}

@Test func syncSquash_postPlusPut_foldsIntoCreate() async throws {
    let container = try makeInMemoryContainer()
    let store = await MainActor.run { LocalSyncOperationStore(container: container) }

    let orgId = UUID()
    let taskId = UUID()

    let create = CreateTaskRequest(id: taskId, title: "Old", listId: UUID())
    let update = UpdateTaskRequest(title: "New", expectedVersion: 1)

    let createJSON = String(decoding: try JSONCoding.encoder.encode(create), as: UTF8.self)
    let updateJSON = String(decoding: try JSONCoding.encoder.encode(update), as: UTF8.self)

    let postOp = await MainActor.run {
        LocalSyncOperation(entityType: .task, entityId: taskId, orgId: orgId, operation: .post, payloadJSON: createJSON)
    }
    let putOp = await MainActor.run {
        LocalSyncOperation(entityType: .task, entityId: taskId, orgId: orgId, operation: .put, payloadJSON: updateJSON, dirtyFields: ["title"])
    }

    try await store.enqueueOrSquash(postOp)
    try await store.enqueueOrSquash(putOp)

    let pending = try await store.fetchPending(orgId: orgId)
    #expect(pending.count == 1)
    #expect(pending[0].operation == .post)

    let merged = try JSONCoding.decoder.decode(CreateTaskRequest.self, from: Data((pending[0].payloadJSON ?? "").utf8))
    #expect(merged.id == taskId)
    #expect(merged.title == "New")
}

@Test func syncSquash_postPlusDelete_becomesNoop() async throws {
    let container = try makeInMemoryContainer()
    let store = await MainActor.run { LocalSyncOperationStore(container: container) }

    let orgId = UUID()
    let taskId = UUID()

    let create = CreateTaskRequest(id: taskId, title: "Temp", listId: UUID())
    let createJSON = String(decoding: try JSONCoding.encoder.encode(create), as: UTF8.self)

    let postOp = await MainActor.run {
        LocalSyncOperation(entityType: .task, entityId: taskId, orgId: orgId, operation: .post, payloadJSON: createJSON)
    }
    let deleteOp = await MainActor.run {
        LocalSyncOperation(entityType: .task, entityId: taskId, orgId: orgId, operation: .delete)
    }

    try await store.enqueueOrSquash(postOp)
    try await store.enqueueOrSquash(deleteOp)

    let pending = try await store.fetchPending(orgId: orgId)
    #expect(pending.isEmpty)
}

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([LocalSyncOperation.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

