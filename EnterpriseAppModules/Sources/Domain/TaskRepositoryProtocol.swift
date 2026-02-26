import Foundation
import SharedModels

public protocol TaskRepositoryProtocol: Sendable {
    /// Fetch tasks using the provided query. Returns from local cache if offline.
    func getTasks(query: TaskQuery) async throws -> APIResponse<[TaskItemDTO]>
    
    /// Fetch tasks assigned to the current user globally.
    func getAssignedTasks(query: TaskQuery) async throws -> APIResponse<[TaskItemDTO]>
    
    /// Fetch tasks for Calendar view (filtered by date range).
    func getCalendarTasks(query: TaskQuery) async throws -> APIResponse<[TaskItemDTO]>
    
    /// Fetch tasks and relations for Timeline/Gantt view.
    func getTimeline(query: TaskQuery) async throws -> APIResponse<TimelineResponseDTO>
    
    /// Create a new task. Optimistically saves locally if offline.
    func createTask(payload: CreateTaskRequest) async throws -> TaskItemDTO
    
    /// Update an existing task. Subject to conflict resolution if versions mismatch.
    func updateTask(id: UUID, payload: UpdateTaskRequest) async throws -> TaskItemDTO
    func partialUpdateTask(id: UUID, payload: UpdateTaskRequest) async throws -> TaskItemDTO
    
    /// Delete a task.
    func deleteTask(id: UUID) async throws
    
    /// Atomically move multiple tasks (used for board drag & drop).
    func moveMultiple(payload: BulkMoveTaskRequest) async throws -> [TaskItemDTO]
}
