import Foundation
import SharedModels

public protocol TaskRepositoryProtocol: Sendable {
    /// Fetch tasks using the provided query. Returns from local cache if offline.
    func getTasks(query: TaskQuery) async throws -> APIResponse<[TaskItemDTO]>
    
    /// Create a new task. Optimistically saves locally if offline.
    func createTask(payload: CreateTaskRequest) async throws -> TaskItemDTO
    
    /// Update an existing task. Subject to conflict resolution if versions mismatch.
    func updateTask(id: UUID, payload: UpdateTaskRequest) async throws -> TaskItemDTO
    
    /// Delete a task.
    func deleteTask(id: UUID) async throws
}
