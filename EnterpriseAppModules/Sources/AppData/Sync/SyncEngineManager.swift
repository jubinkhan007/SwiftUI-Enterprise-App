import Foundation
import Combine
import AppNetwork
import SharedModels

public enum SyncEngineState: Equatable, Sendable {
    case online
    case offline
    case syncing(count: Int)
    case attentionNeeded
}

@MainActor
public final class SyncEngineManager: ObservableObject {
    @Published public private(set) var state: SyncEngineState = .offline
    @Published public private(set) var pendingOperations: [LocalSyncOperation] = []
    @Published public private(set) var attentionOperations: [LocalSyncOperation] = []
    @Published public private(set) var lastSyncedAt: Date? = nil

    private let engine: GlobalSyncEngineProtocol
    private let operationStore: LocalSyncOperationStoreProtocol
    private let taskLocalStore: TaskLocalStoreProtocol
    private var syncTask: Task<Void, Never>?

    public init(engine: GlobalSyncEngineProtocol, operationStore: LocalSyncOperationStoreProtocol, taskLocalStore: TaskLocalStoreProtocol) {
        self.engine = engine
        self.operationStore = operationStore
        self.taskLocalStore = taskLocalStore
        self.state = .online
    }

    deinit {
        syncTask?.cancel()
    }

    public func refresh() async {
        guard let orgId = OrganizationContext.shared.orgId else { return }
        do {
            pendingOperations = try await operationStore.fetchPending(orgId: orgId)
            attentionOperations = try await operationStore.fetchNeedsAttention(orgId: orgId)
        } catch {
            print("SyncEngineManager: refresh failed: \(error)")
        }
        recomputeState()
    }

    public func syncNow() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            guard let self else { return }
            guard let orgId = OrganizationContext.shared.orgId else { return }
            await self.refresh()

            if !self.attentionOperations.isEmpty {
                self.state = .attentionNeeded
                return
            }

            self.state = .syncing(count: self.pendingOperations.count)
            await self.engine.sync(orgId: orgId)
            self.lastSyncedAt = Date()
            await self.refresh()

            if self.pendingOperations.contains(where: { $0.lastError == "Offline" }) {
                self.state = .offline
            }
        }
    }

    public func retry(_ operation: LocalSyncOperation) async {
        operation.needsAttention = false
        operation.retryCount = 0
        operation.nextAttemptAt = nil
        operation.lastError = nil
        operation.remoteSnapshotJSON = nil
        do {
            try await operationStore.save()
        } catch {
            print("SyncEngineManager: retry save failed: \(error)")
        }
        syncNow()
    }

    public func discard(_ operation: LocalSyncOperation) async {
        do {
            try await operationStore.delete(operation)
            await refresh()
        } catch {
            print("SyncEngineManager: discard failed: \(error)")
        }
    }

    public func resolveConflictUseTheirs(_ operation: LocalSyncOperation) async {
        guard let snapshotJSON = operation.remoteSnapshotJSON,
              let data = snapshotJSON.data(using: .utf8),
              let latest = try? JSONCoding.decoder.decode(APIResponse<TaskItemDTO>.self, from: data).data
        else {
            await discard(operation)
            return
        }

        if let localTask = try? await taskLocalStore.getTask(id: latest.id) {
            await MainActor.run { localTask.update(from: latest) }
            try? await taskLocalStore.save(task: localTask)
        }
        await discard(operation)
    }

    public func resolveConflictKeepMine(_ operation: LocalSyncOperation) async {
        guard let snapshotJSON = operation.remoteSnapshotJSON,
              let data = snapshotJSON.data(using: .utf8),
              let latest = try? JSONCoding.decoder.decode(APIResponse<TaskItemDTO>.self, from: data).data
        else {
            await discard(operation)
            return
        }

        guard let payloadJSON = operation.payloadJSON,
              var payload = try? JSONCoding.decoder.decode(UpdateTaskRequest.self, from: Data(payloadJSON.utf8))
        else {
            await discard(operation)
            return
        }

        payload.expectedVersion = latest.version
        if let encoded = try? JSONCoding.encoder.encode(payload) {
            operation.payloadJSON = String(decoding: encoded, as: UTF8.self)
        }

        operation.needsAttention = false
        operation.retryCount = 0
        operation.nextAttemptAt = nil
        operation.lastError = nil
        operation.remoteSnapshotJSON = nil

        do {
            try await operationStore.save()
        } catch {
            print("SyncEngineManager: resolve keep mine save failed: \(error)")
        }
        syncNow()
    }

    private func recomputeState() {
        if !attentionOperations.isEmpty {
            state = .attentionNeeded
            return
        }
        if case .offline = state { return }
        state = .online
    }
}
