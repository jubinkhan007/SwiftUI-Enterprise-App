import Foundation
import SharedModels
import AppNetwork

public protocol TaskSyncQueueProtocol: Sendable {
    func syncPendingMutations() async
}

/// A background queue that finds locally mutated tasks and syncs them to the backend.
public final class TaskSyncQueue: TaskSyncQueueProtocol {
    private let localStore: TaskLocalStoreProtocol
    private let apiClient: APIClient
    
    public init(localStore: TaskLocalStoreProtocol, apiClient: APIClient) {
        self.localStore = localStore
        self.apiClient = apiClient
    }
    
    public func syncPendingMutations() async {
        do {
            let pendingTasks = try await localStore.getPendingSyncTasks()
            
            for localTask in pendingTasks {
                do {
                    if localTask.isDeletedLocally {
                        // Attempt DELETE
                        let endpoint = TaskEndpoint.deleteTask(id: localTask.id, configuration: .localVapor)
                        _ = try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
                        
                        // Success -> remove from local store entirely
                        try await localStore.delete(id: localTask.id)
                    } else if localTask.version == 1 {
                        // Attempt POST (Creation)
                        let payload = CreateTaskRequest(
                            title: localTask.title,
                            description: localTask.taskDescription,
                            statusId: localTask.statusId,
                            status: TaskStatus(rawValue: localTask.statusRawValue) ?? .todo,
                            priority: TaskPriority(rawValue: localTask.priorityRawValue) ?? .medium,
                            dueDate: localTask.dueDate,
                            assigneeId: localTask.assigneeId
                        )
                        let endpoint = TaskEndpoint.createTask(payload: payload, configuration: .localVapor)
                        let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
                        
                        guard let data = response.data else { throw NetworkError.underlying("No data") }
                        
                        // Success -> Update local task with server ID & real metadata
                        await MainActor.run {
                            localTask.update(from: data)
                        }
                        try await localStore.save(task: localTask)
                    } else {
                        // Attempt PUT (Update)
                        let payload = UpdateTaskRequest(
                            title: localTask.title,
                            description: localTask.taskDescription,
                            statusId: localTask.statusId,
                            status: TaskStatus(rawValue: localTask.statusRawValue) ?? .todo,
                            priority: TaskPriority(rawValue: localTask.priorityRawValue) ?? .medium,
                            dueDate: localTask.dueDate,
                            assigneeId: localTask.assigneeId,
                            expectedVersion: localTask.version - 1 // Send the pre-mutation version
                        )
                        let endpoint = TaskEndpoint.updateTask(id: localTask.id, payload: payload, configuration: .localVapor)
                        let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
                        
                        guard let data = response.data else { throw NetworkError.underlying("No data") }
                        
                        // Success -> clear pending flag
                        await MainActor.run {
                            localTask.update(from: data)
                        }
                        try await localStore.save(task: localTask)
                    }
                } catch {
                    print("Failed to sync task \(localTask.id): \(error)")
                    // Simple retry logic relies on the caller invoking `syncPendingMutations()` periodically 
                    // (e.g., App active, network restored)
                }
            }
        } catch {
            print("Failed to fetch pending sync tasks: \(error)")
        }
    }
}
