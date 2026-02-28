import Foundation
import SharedModels
import AppNetwork
import Domain

/// Concrete implementation of TaskRepositoryProtocol bridging the APIClient and TaskLocalStore.
public final class TaskRepository: TaskRepositoryProtocol {
    private let apiClient: APIClient
    private let localStore: TaskLocalStoreProtocol
    private let syncQueue: TaskSyncQueueProtocol
    private let apiConfiguration: APIConfiguration
    
    public init(apiClient: APIClient, localStore: TaskLocalStoreProtocol, syncQueue: TaskSyncQueueProtocol, configuration: APIConfiguration = .localVapor) {
        self.apiClient = apiClient
        self.localStore = localStore
        self.syncQueue = syncQueue
        self.apiConfiguration = configuration
    }
    
    public func getTasks(query: TaskQuery) async throws -> APIResponse<[TaskItemDTO]> {
        do {
            let endpoint = TaskEndpoint.getTasks(query: query, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[TaskItemDTO]>.self)
            
            guard let data = response.data else {
                throw NetworkError.underlying("No data returned from server")
            }
            
            // Sync fresh data to local store
            let localItems = data.map { dto in
                LocalTaskItem(
                    id: dto.id,
                    title: dto.title,
                    taskDescription: dto.description,
                    statusId: dto.statusId,
                    status: dto.status,
                    priority: dto.priority,
                    dueDate: dto.dueDate,
                    assigneeId: dto.assigneeId,
                    version: dto.version,
                    createdAt: dto.createdAt,
                    updatedAt: dto.updatedAt
                )
            }
            try await localStore.save(tasks: localItems)
            return response
            
        } catch let error as NetworkError {
            if error == .offline {
                // Fallback to local store
                let cachedTasks = try await localStore.getTasks(query: query)
                let dtos = cachedTasks.map { $0.toDTO() }
                
                // Return a mock successful response with cached data
                return APIResponse(
                    success: true,
                    data: dtos,
                    pagination: PaginationMeta(page: query.page, perPage: query.perPage, total: dtos.count)
                )
            }
            throw error
        }
    }
    
    public func getAssignedTasks(query: TaskQuery) async throws -> APIResponse<[TaskItemDTO]> {
        do {
            let endpoint = TaskEndpoint.getAssignedTasks(query: query, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[TaskItemDTO]>.self)
            
            guard let data = response.data else {
                throw NetworkError.underlying("No data returned from server")
            }
            
            // Sync fresh data to local store
            let localItems = data.map { dto in
                LocalTaskItem(
                    id: dto.id,
                    title: dto.title,
                    taskDescription: dto.description,
                    statusId: dto.statusId,
                    status: dto.status,
                    priority: dto.priority,
                    dueDate: dto.dueDate,
                    assigneeId: dto.assigneeId,
                    version: dto.version,
                    createdAt: dto.createdAt,
                    updatedAt: dto.updatedAt
                )
            }
            try await localStore.save(tasks: localItems)
            return response
            
        } catch let error as NetworkError {
            if error == .offline {
                // Return a mock successful response with cached data based on the assignee filter
                // Ideally local cache would also filter by current user if offline, 
                // but local store fallback just matches the query filters for now.
                let cachedTasks = try await localStore.getTasks(query: query)
                let dtos = cachedTasks.map { $0.toDTO() }
                
                return APIResponse(
                    success: true,
                    data: dtos,
                    pagination: PaginationMeta(page: query.page, perPage: query.perPage, total: dtos.count)
                )
            }
            throw error
        }
    }
    
    public func getCalendarTasks(query: TaskQuery) async throws -> APIResponse<[TaskItemDTO]> {
        let endpoint = TaskEndpoint.getCalendarTasks(query: query, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<[TaskItemDTO]>.self)
    }
    
    public func getTimeline(query: TaskQuery) async throws -> APIResponse<TimelineResponseDTO> {
        let endpoint = TaskEndpoint.getTimeline(query: query, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<TimelineResponseDTO>.self)
    }
    
    public func createTask(payload: CreateTaskRequest) async throws -> TaskItemDTO {
        let localTask = LocalTaskItem(
            id: UUID(), // Optimistic ID
            title: payload.title,
            taskDescription: payload.description,
            statusId: payload.statusId,
            status: payload.status ?? .todo,
            priority: payload.priority ?? .medium,
            dueDate: payload.dueDate,
            assigneeId: payload.assigneeId,
            version: 1, // Start at version 1
            createdAt: Date(),
            updatedAt: Date(),
            isPendingSync: true
        )
        
        // Optimistically save immediately
        try await localStore.save(task: localTask)
        
        do {
            let endpoint = TaskEndpoint.createTask(payload: payload, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
            guard let data = response.data else { throw NetworkError.underlying("No data") }
            
            // Server succeeded! The sync queue ignores it next run, but we must update the real ID/version
            await MainActor.run {
                localTask.update(from: data)
            }
            try await localStore.save(task: localTask)
            return data
            
        } catch let error as NetworkError {
            if error == .offline {
                // Return the optimistic DTO, the SyncQueue will catch it later
                return localTask.toDTO()
            }
            throw error
        }
    }
    
    public func updateTask(id: UUID, payload: UpdateTaskRequest) async throws -> TaskItemDTO {
        // Fetch current local state for optimistic update
        guard let localTask = try await localStore.getTask(id: id) else {
            throw NetworkError.underlying("Task not found locally")
        }
        
        // Apply optimistic changes, mark for sync
        applyUpdates(to: localTask, payload: payload)
        await MainActor.run {
            localTask.isPendingSync = true
        }
        
        try await localStore.save(task: localTask)
        
        do {
            let endpoint = TaskEndpoint.updateTask(id: id, payload: payload, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
            guard let data = response.data else { throw NetworkError.underlying("No data") }
            
            // Apply true server state
            await MainActor.run {
                localTask.update(from: data)
            }
            try await localStore.save(task: localTask)
            return data
            
        } catch let error as NetworkError {
            // Check specifically for 409 Conflict here in advanced implementations
            if case .serverError(let statusCode, _) = error, statusCode == 409 {
                // Revert optimistic changes or throw conflict error for ViewModel to handle
                throw error
            }
            if error == .offline {
                // Defer to sync queue
                return localTask.toDTO()
            }
            throw error
        }
    }

    public func partialUpdateTask(id: UUID, payload: UpdateTaskRequest) async throws -> TaskItemDTO {
        // Fetch current local state for optimistic update
        guard let localTask = try await localStore.getTask(id: id) else {
            throw NetworkError.underlying("Task not found locally")
        }
        
        // Apply optimistic changes, mark for sync
        applyUpdates(to: localTask, payload: payload)
        await MainActor.run {
            localTask.isPendingSync = true
        }
        
        try await localStore.save(task: localTask)
        
        do {
            let endpoint = TaskEndpoint.partialUpdateTask(id: id, payload: payload, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
            guard let data = response.data else { throw NetworkError.underlying("No data") }
            
            // Apply true server state
            await MainActor.run {
                localTask.update(from: data)
            }
            try await localStore.save(task: localTask)
            return data
            
        } catch let error as NetworkError {
            if error == .offline {
                // Defer to sync queue
                return localTask.toDTO()
            }
            throw error
        }
    }

    public func moveMultiple(payload: BulkMoveTaskRequest) async throws -> [TaskItemDTO] {
        // Optimistic local update involves fetching all tasks and applying moves
        let localTasks = try await localStore.getTasks(query: TaskQuery()) // Simple fetch to get tasks in memory, optimized in real app
        var updatedDTOs = [TaskItemDTO]()
        
        for moveAction in payload.moves {
            if let task = try await localStore.getTask(id: moveAction.taskId) {
                if let targetListId = payload.targetListId {
                    task.listId = targetListId
                }
                if let targetStatus = payload.targetStatus {
                    task.statusRawValue = targetStatus.rawValue
                }
                task.position = moveAction.newPosition
                task.isPendingSync = true
                try await localStore.save(task: task)
                updatedDTOs.append(task.toDTO())
            }
        }
        
        do {
            let endpoint = TaskEndpoint.moveMultiple(payload: payload, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[TaskItemDTO]>.self)
            guard let data = response.data else { throw NetworkError.underlying("No data") }
            
            // Sync confirmed server changes
            for dto in data {
                if let localTask = try await localStore.getTask(id: dto.id) {
                    await MainActor.run {
                        localTask.update(from: dto)
                    }
                    try await localStore.save(task: localTask)
                }
            }
            return data
            
        } catch let error as NetworkError {
            if error == .offline {
                // In an advanced scenario, queue the bulk operation or individual moves
                // For MVP offline bulk move, we'll return the optimistic DTOs
                return updatedDTOs
            }
            throw error
        }
    }
    
    public func deleteTask(id: UUID) async throws {
        // Mark for deletion but keep it around for the SyncQueue to try
        if let localTask = try await localStore.getTask(id: id) {
             await MainActor.run {
                 localTask.isDeletedLocally = true
                 localTask.isPendingSync = true
             }
             try await localStore.save(task: localTask)
        }
        
        do {
            let endpoint = TaskEndpoint.deleteTask(id: id, configuration: apiConfiguration)
            _ = try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
            
            // Success -> actually delete locally
            try await localStore.delete(id: id)
            
        } catch let error as NetworkError {
            if error == .offline {
                // Leave marked as pending deletion for SyncQueue
                return 
            }
            throw error
        }
    }
    
    // MARK: - Helpers
    
    private func applyUpdates(to localTask: LocalTaskItem, payload: UpdateTaskRequest) {
        if let title = payload.title { localTask.title = title }
        if let desc = payload.description { localTask.taskDescription = desc }
        if let statusId = payload.statusId { localTask.statusId = statusId }
        if let status = payload.status { localTask.statusRawValue = status.rawValue }
        if let prio = payload.priority { localTask.priorityRawValue = prio.rawValue }
        if let due = payload.dueDate { localTask.dueDate = due }
        if let assignee = payload.assigneeId { localTask.assigneeId = assignee }
    }
}
