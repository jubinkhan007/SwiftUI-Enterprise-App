import Foundation
import SharedModels
import AppNetwork
import Domain

/// Concrete implementation of TaskRepositoryProtocol bridging the APIClient and TaskLocalStore.
public final class TaskRepository: TaskRepositoryProtocol {
    private let apiClient: APIClient
    private let localStore: TaskLocalStoreProtocol
    private let operationStore: LocalSyncOperationStoreProtocol
    private let apiConfiguration: APIConfiguration
    
    public init(
        apiClient: APIClient,
        localStore: TaskLocalStoreProtocol,
        operationStore: LocalSyncOperationStoreProtocol,
        configuration: APIConfiguration = .localVapor
    ) {
        self.apiClient = apiClient
        self.localStore = localStore
        self.operationStore = operationStore
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
            id: payload.id ?? UUID(), // Optimistic but stable client ID
            title: payload.title,
            taskDescription: payload.description,
            statusId: payload.statusId,
            status: payload.status ?? .todo,
            priority: payload.priority ?? .medium,
            taskType: payload.taskType ?? .task,
            dueDate: payload.dueDate,
            startDate: payload.startDate,
            assigneeId: payload.assigneeId,
            parentId: payload.parentId,
            storyPoints: payload.storyPoints,
            labels: payload.labels,
            listId: payload.listId,
            version: 1,
            createdAt: Date(),
            updatedAt: Date(),
            isPendingSync: true
        )
        
        // Optimistically save immediately
        try await localStore.save(task: localTask)

        guard let orgId = OrganizationContext.shared.orgId else {
            // No org context; keep local and let the UI drive recovery.
            return localTask.toDTO()
        }

        let createPayload = CreateTaskRequest(
            id: localTask.id,
            title: payload.title,
            description: payload.description,
            statusId: payload.statusId,
            status: payload.status,
            priority: payload.priority,
            taskType: payload.taskType,
            parentId: payload.parentId,
            storyPoints: payload.storyPoints,
            labels: payload.labels,
            startDate: payload.startDate,
            dueDate: payload.dueDate,
            assigneeId: payload.assigneeId,
            listId: payload.listId,
            sprintId: payload.sprintId,
            backlogPosition: payload.backlogPosition,
            sprintPosition: payload.sprintPosition,
            bugSeverity: payload.bugSeverity,
            bugEnvironment: payload.bugEnvironment,
            affectedVersionId: payload.affectedVersionId,
            expectedResult: payload.expectedResult,
            actualResult: payload.actualResult,
            reproductionSteps: payload.reproductionSteps
        )
        let createData = try JSONCoding.encoder.encode(createPayload)
        let op = LocalSyncOperation(
            entityType: .task,
            entityId: localTask.id,
            orgId: orgId,
            operation: .post,
            payloadJSON: String(decoding: createData, as: UTF8.self)
        )
        try await operationStore.enqueueOrSquash(op)
        
        do {
            let endpoint = TaskEndpoint.createTask(payload: createPayload, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
            guard let data = response.data else { throw NetworkError.underlying("No data") }
            
            // Server succeeded: update local row and clear the op.
            await MainActor.run {
                localTask.update(from: data)
            }
            try await localStore.save(task: localTask)
            try await operationStore.deleteOperations(orgId: orgId, entityType: .task, entityId: localTask.id)
            return data
            
        } catch let error as NetworkError {
            if error == .offline {
                // Return the optimistic DTO, GlobalSyncEngine will catch it later.
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

        guard let orgId = OrganizationContext.shared.orgId else {
            throw NetworkError.underlying("Missing organization context")
        }

        let dirtyFields = Self.dirtyFields(from: payload)
        let baseSnapshot = Self.baseSnapshot(for: localTask, payload: payload)
        let baseData = try JSONCoding.encoder.encode(baseSnapshot)
        let payloadData = try JSONCoding.encoder.encode(payload)
        let op = LocalSyncOperation(
            entityType: .task,
            entityId: id,
            orgId: orgId,
            operation: .put,
            payloadJSON: String(decoding: payloadData, as: UTF8.self),
            baseSnapshotJSON: String(decoding: baseData, as: UTF8.self),
            dirtyFields: dirtyFields
        )
        
        // Apply optimistic changes, mark for sync
        applyUpdates(to: localTask, payload: payload)
        await MainActor.run {
            localTask.isPendingSync = true
        }
        
        try await localStore.save(task: localTask)
        try await operationStore.enqueueOrSquash(op)
        
        do {
            let endpoint = TaskEndpoint.updateTask(id: id, payload: payload, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
            guard let data = response.data else { throw NetworkError.underlying("No data") }
            
            // Apply true server state
            await MainActor.run {
                localTask.update(from: data)
            }
            try await localStore.save(task: localTask)
            try await operationStore.deleteOperations(orgId: orgId, entityType: .task, entityId: id)
            return data
            
        } catch let error as NetworkError {
            if error == .offline {
                // Defer to sync queue
                return localTask.toDTO()
            }
            if case .conflict(let data, _, _) = error,
               let latest = try? JSONCoding.decoder.decode(APIResponse<TaskItemDTO>.self, from: data).data
            {
                await MainActor.run { localTask.update(from: latest) }
                try await localStore.save(task: localTask)
                try await operationStore.deleteOperations(orgId: orgId, entityType: .task, entityId: id)
                throw error
            }
            throw error
        }
    }

    public func partialUpdateTask(id: UUID, payload: UpdateTaskRequest) async throws -> TaskItemDTO {
        // Fetch current local state for optimistic update
        guard let localTask = try await localStore.getTask(id: id) else {
            throw NetworkError.underlying("Task not found locally")
        }

        guard let orgId = OrganizationContext.shared.orgId else {
            throw NetworkError.underlying("Missing organization context")
        }

        let dirtyFields = Self.dirtyFields(from: payload)
        let baseSnapshot = Self.baseSnapshot(for: localTask, payload: payload)
        let baseData = try JSONCoding.encoder.encode(baseSnapshot)
        let payloadData = try JSONCoding.encoder.encode(payload)
        let op = LocalSyncOperation(
            entityType: .task,
            entityId: id,
            orgId: orgId,
            operation: .put,
            payloadJSON: String(decoding: payloadData, as: UTF8.self),
            baseSnapshotJSON: String(decoding: baseData, as: UTF8.self),
            dirtyFields: dirtyFields
        )
        
        // Apply optimistic changes, mark for sync
        applyUpdates(to: localTask, payload: payload)
        await MainActor.run {
            localTask.isPendingSync = true
        }
        
        try await localStore.save(task: localTask)
        try await operationStore.enqueueOrSquash(op)
        
        do {
            let endpoint = TaskEndpoint.partialUpdateTask(id: id, payload: payload, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskItemDTO>.self)
            guard let data = response.data else { throw NetworkError.underlying("No data") }
            
            // Apply true server state
            await MainActor.run {
                localTask.update(from: data)
            }
            try await localStore.save(task: localTask)
            try await operationStore.deleteOperations(orgId: orgId, entityType: .task, entityId: id)
            return data
            
        } catch let error as NetworkError {
            if error == .offline {
                // Defer to sync queue
                return localTask.toDTO()
            }
            if case .conflict(let data, _, _) = error,
               let latest = try? JSONCoding.decoder.decode(APIResponse<TaskItemDTO>.self, from: data).data
            {
                await MainActor.run { localTask.update(from: latest) }
                try await localStore.save(task: localTask)
                try await operationStore.deleteOperations(orgId: orgId, entityType: .task, entityId: id)
                throw error
            }
            throw error
        }
    }

    public func moveMultiple(payload: BulkMoveTaskRequest) async throws -> [TaskItemDTO] {
        // Optimistic local update involves fetching all tasks and applying moves
        _ = try await localStore.getTasks(query: TaskQuery()) // Simple fetch to get tasks in memory, optimized in real app
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

                if let orgId = OrganizationContext.shared.orgId {
                    var update = UpdateTaskRequest(
                        listId: payload.targetListId,
                        position: moveAction.newPosition,
                        expectedVersion: task.version
                    )
                    if let s = payload.targetStatus { update.status = s }
                    let dirtyFields = Self.dirtyFields(from: update)
                    let baseSnapshot = Self.baseSnapshot(for: task, payload: update)
                    let baseData = try JSONCoding.encoder.encode(baseSnapshot)
                    let payloadData = try JSONCoding.encoder.encode(update)
                    let op = LocalSyncOperation(
                        entityType: .task,
                        entityId: moveAction.taskId,
                        orgId: orgId,
                        operation: .put,
                        payloadJSON: String(decoding: payloadData, as: UTF8.self),
                        baseSnapshotJSON: String(decoding: baseData, as: UTF8.self),
                        dirtyFields: dirtyFields
                    )
                    try await operationStore.enqueueOrSquash(op)
                }
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
                if let orgId = OrganizationContext.shared.orgId {
                    try? await operationStore.deleteOperations(orgId: orgId, entityType: .task, entityId: dto.id)
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

        if let orgId = OrganizationContext.shared.orgId {
            let op = LocalSyncOperation(entityType: .task, entityId: id, orgId: orgId, operation: .delete)
            try await operationStore.enqueueOrSquash(op)
        }
        
        do {
            let endpoint = TaskEndpoint.deleteTask(id: id, configuration: apiConfiguration)
            _ = try await apiClient.request(endpoint, responseType: APIResponse<EmptyResponse>.self)
            
            // Success -> actually delete locally
            try await localStore.delete(id: id)
            if let orgId = OrganizationContext.shared.orgId {
                try await operationStore.deleteOperations(orgId: orgId, entityType: .task, entityId: id)
            }
            
        } catch let error as NetworkError {
            if error == .offline {
                // Leave marked as pending deletion for SyncQueue
                return 
            }
            throw error
        }
    }

    // MARK: - Phase 13: Agile / Jira

    public func getBacklog(projectId: UUID) async throws -> [TaskItemDTO] {
        let endpoint = AgileEndpoint.getBacklog(projectId: projectId, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[TaskItemDTO]>.self)
        return response.data ?? []
    }

    public func getSprintIssues(sprintId: UUID) async throws -> [TaskItemDTO] {
        let endpoint = AgileEndpoint.getSprintIssues(sprintId: sprintId, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[TaskItemDTO]>.self)
        return response.data ?? []
    }
    
    // MARK: - Helpers
    
    private func applyUpdates(to localTask: LocalTaskItem, payload: UpdateTaskRequest) {
        if let title = payload.title { localTask.title = title }
        if let desc = payload.description { localTask.taskDescription = desc }
        if let statusId = payload.statusId { localTask.statusId = statusId }
        if let status = payload.status { localTask.statusRawValue = status.rawValue }
        if let prio = payload.priority { localTask.priorityRawValue = prio.rawValue }
        if let type = payload.taskType { localTask.taskTypeRawValue = type.rawValue }
        if let sp = payload.storyPoints { localTask.storyPoints = sp }
        if let labels = payload.labels { localTask.labels = labels }
        if let start = payload.startDate { localTask.startDate = start }
        if let due = payload.dueDate { localTask.dueDate = due }
        if let assignee = payload.assigneeId { localTask.assigneeId = assignee }
        if let listId = payload.listId { localTask.listId = listId }
        if let position = payload.position { localTask.position = position }
        if let archivedAt = payload.archivedAt { localTask.archivedAt = archivedAt }
    }

    private static func dirtyFields(from payload: UpdateTaskRequest) -> [String] {
        var fields: [String] = []
        if payload.title != nil { fields.append("title") }
        if payload.description != nil { fields.append("description") }
        if payload.statusId != nil { fields.append("statusId") }
        if payload.status != nil { fields.append("status") }
        if payload.priority != nil { fields.append("priority") }
        if payload.taskType != nil { fields.append("taskType") }
        if payload.storyPoints != nil { fields.append("storyPoints") }
        if payload.labels != nil { fields.append("labels") }
        if payload.startDate != nil { fields.append("startDate") }
        if payload.dueDate != nil { fields.append("dueDate") }
        if payload.assigneeId != nil { fields.append("assigneeId") }
        if payload.listId != nil { fields.append("listId") }
        if payload.position != nil { fields.append("position") }
        if payload.archivedAt != nil { fields.append("archivedAt") }
        return fields
    }

    private static func baseSnapshot(for localTask: LocalTaskItem, payload: UpdateTaskRequest) -> TaskFieldSnapshot {
        var snapshot = TaskFieldSnapshot()
        if payload.title != nil { snapshot.title = localTask.title }
        if payload.description != nil { snapshot.description = localTask.taskDescription }
        if payload.statusId != nil { snapshot.statusId = localTask.statusId }
        if payload.status != nil { snapshot.status = TaskStatus(rawValue: localTask.statusRawValue) }
        if payload.priority != nil { snapshot.priority = TaskPriority(rawValue: localTask.priorityRawValue) }
        if payload.taskType != nil { snapshot.taskType = TaskType(rawValue: localTask.taskTypeRawValue) }
        if payload.storyPoints != nil { snapshot.storyPoints = localTask.storyPoints }
        if payload.labels != nil { snapshot.labels = localTask.labels }
        if payload.startDate != nil { snapshot.startDate = localTask.startDate }
        if payload.dueDate != nil { snapshot.dueDate = localTask.dueDate }
        if payload.assigneeId != nil { snapshot.assigneeId = localTask.assigneeId }
        if payload.listId != nil { snapshot.listId = localTask.listId }
        if payload.position != nil { snapshot.position = localTask.position }
        if payload.archivedAt != nil { snapshot.archivedAt = localTask.archivedAt }
        return snapshot
    }
}
