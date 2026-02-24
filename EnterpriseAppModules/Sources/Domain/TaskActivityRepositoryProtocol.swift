import Foundation
import SharedModels

public protocol TaskActivityRepositoryProtocol: Sendable {
    /// Fetch activities and comments for a specific task.
    func getActivities(taskId: UUID) async throws -> APIResponse<[TaskActivityDTO]>
    
    /// Create a new comment on a task.
    func createComment(taskId: UUID, payload: CreateCommentRequest) async throws -> TaskActivityDTO
}
