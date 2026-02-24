import Foundation
import SharedModels
import AppNetwork
import Domain

/// Fetches and creates activity timeline records for a given task.
public final class TaskActivityRepository: TaskActivityRepositoryProtocol {
    private let apiClient: APIClient
    private let apiConfiguration: APIConfiguration
    
    public init(apiClient: APIClient, configuration: APIConfiguration = .localVapor) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }
    
    public func getActivities(taskId: UUID) async throws -> APIResponse<[TaskActivityDTO]> {
        let endpoint = TaskEndpoint.getActivity(taskId: taskId, configuration: apiConfiguration)
        return try await apiClient.request(endpoint, responseType: APIResponse<[TaskActivityDTO]>.self)
    }
    
    public func createComment(taskId: UUID, payload: CreateCommentRequest) async throws -> TaskActivityDTO {
        let endpoint = TaskEndpoint.createComment(taskId: taskId, payload: payload, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskActivityDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
}
