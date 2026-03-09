import Foundation
import SharedModels
import AppNetwork

public protocol GlobalSyncEngineProtocol: Sendable {
    func sync(orgId: UUID) async
}

public final class GlobalSyncEngine: GlobalSyncEngineProtocol, @unchecked Sendable {
    private let apiClient: APIClient
    private let taskLocalStore: TaskLocalStoreProtocol
    private let operationStore: LocalSyncOperationStoreProtocol

    public init(apiClient: APIClient, taskLocalStore: TaskLocalStoreProtocol, operationStore: LocalSyncOperationStoreProtocol) {
        self.apiClient = apiClient
        self.taskLocalStore = taskLocalStore
        self.operationStore = operationStore
    }

    public func sync(orgId: UUID) async {
        do {
            let operations = try await operationStore.fetchPending(orgId: orgId)
            for operation in operations {
                if let next = operation.nextAttemptAt, next > Date() { continue }
                await process(operation: operation)
            }
        } catch {
            // Store access errors should not crash the app.
            print("GlobalSyncEngine: failed to fetch operations: \(error)")
        }
    }

    private func process(operation: LocalSyncOperation) async {
        do {
            switch (operation.entityType, operation.operation) {
            case (.task, .post):
                try await replayTaskCreate(operation: operation)
            case (.task, .put):
                try await replayTaskUpdate(operation: operation)
            case (.task, .delete):
                try await replayTaskDelete(operation: operation)
            default:
                operation.needsAttention = true
                operation.lastError = "Unsupported operation: \(operation.entityTypeRawValue) \(operation.operationRawValue)"
                try await operationStore.save()
            }
        } catch let error as NetworkError {
            await handle(networkError: error, operation: operation)
        } catch {
            await scheduleRetry(operation: operation, error: String(describing: error))
        }
    }

    private func replayTaskCreate(operation: LocalSyncOperation) async throws {
        guard let payloadJSON = operation.payloadJSON else {
            throw NetworkError.underlying("Missing payload for task create")
        }
        let payload = try JSONCoding.decoder.decode(CreateTaskRequest.self, from: Data(payloadJSON.utf8))
        let endpoint = TaskEndpoint.createTask(payload: payload, configuration: .current)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
        guard let dto = response.data else { throw NetworkError.underlying("No data") }

        // Update local task row and clear the op.
        if let localTask = try await taskLocalStore.getTask(id: dto.id) {
            await MainActor.run { localTask.update(from: dto) }
            try await taskLocalStore.save(task: localTask)
        }
        try await operationStore.delete(operation)
    }

    private func replayTaskUpdate(operation: LocalSyncOperation) async throws {
        guard let payloadJSON = operation.payloadJSON else {
            throw NetworkError.underlying("Missing payload for task update")
        }
        var payload = try JSONCoding.decoder.decode(UpdateTaskRequest.self, from: Data(payloadJSON.utf8))
        let endpoint = TaskEndpoint.updateTask(id: operation.entityId, payload: payload, configuration: .current)

        do {
            let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
            guard let dto = response.data else { throw NetworkError.underlying("No data") }

            if let localTask = try await taskLocalStore.getTask(id: dto.id) {
                await MainActor.run { localTask.update(from: dto) }
                try await taskLocalStore.save(task: localTask)
            }
            try await operationStore.delete(operation)
            return
        } catch let error as NetworkError {
            // Field-level merge on 409 using base snapshots.
            if case .conflict(let data, _, _) = error,
               let latest = try? JSONCoding.decoder.decode(APIResponse<TaskItemDTO>.self, from: data).data
            {
                let collision = hasCollision(operation: operation, server: latest)
                if collision {
                    operation.needsAttention = true
                    operation.lastError = "Conflict: server has newer changes for the same fields."
                    operation.remoteSnapshotJSON = String(decoding: data, as: UTF8.self)
                    try await operationStore.save()
                    return
                }

                payload.expectedVersion = latest.version
                let retryEndpoint = TaskEndpoint.updateTask(id: operation.entityId, payload: payload, configuration: .current)
                let retryResponse = try await apiClient.request(retryEndpoint, responseType: APIResponse<TaskItemDTO>.self)
                guard let mergedDTO = retryResponse.data else { throw NetworkError.underlying("No data") }

                if let localTask = try await taskLocalStore.getTask(id: mergedDTO.id) {
                    await MainActor.run { localTask.update(from: mergedDTO) }
                    try await taskLocalStore.save(task: localTask)
                }
                try await operationStore.delete(operation)
                return
            }
            throw error
        }
    }

    private func replayTaskDelete(operation: LocalSyncOperation) async throws {
        let endpoint = TaskEndpoint.deleteTask(id: operation.entityId, configuration: .current)
        _ = try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
        try await taskLocalStore.delete(id: operation.entityId)
        try await operationStore.delete(operation)
    }

    private func hasCollision(operation: LocalSyncOperation, server: TaskItemDTO) -> Bool {
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
            case "labels":
                if server.labels != base.labels { return true }
            case "startDate":
                if server.startDate != base.startDate { return true }
            case "dueDate":
                if server.dueDate != base.dueDate { return true }
            case "assigneeId":
                if server.assigneeId != base.assigneeId { return true }
            case "listId":
                if server.listId != base.listId { return true }
            case "position":
                if server.position != (base.position ?? server.position) && base.position != nil { return true }
            case "archivedAt":
                if server.archivedAt != base.archivedAt { return true }
            default:
                return true
            }
        }

        return false
    }

    private func handle(networkError: NetworkError, operation: LocalSyncOperation) async {
        switch networkError {
        case .offline:
            // Don't count as a failure; wait for connectivity.
            operation.lastError = "Offline"
            operation.nextAttemptAt = nil
            do { try await operationStore.save() } catch { print("GlobalSyncEngine: save failed: \(error)") }
        case .unauthorized, .forbidden:
            operation.needsAttention = true
            operation.lastError = networkError.errorDescription
            do { try await operationStore.save() } catch { print("GlobalSyncEngine: save failed: \(error)") }
        case .serverError(let status, _) where status == 404:
            operation.needsAttention = true
            operation.lastError = "Not found on server (404)."
            do { try await operationStore.save() } catch { print("GlobalSyncEngine: save failed: \(error)") }
        default:
            await scheduleRetry(operation: operation, error: networkError.errorDescription ?? String(describing: networkError))
        }
    }

    private func scheduleRetry(operation: LocalSyncOperation, error: String) async {
        operation.retryCount += 1
        operation.lastError = error

        if operation.retryCount >= 5 {
            operation.needsAttention = true
            operation.nextAttemptAt = nil
        } else {
            let delay = min(pow(2.0, Double(operation.retryCount)) * 2.0, 120.0)
            operation.nextAttemptAt = Date().addingTimeInterval(delay)
        }

        do { try await operationStore.save() } catch { print("GlobalSyncEngine: save failed: \(error)") }
    }
}

