import Foundation
import SharedModels
import AppNetwork
import Domain

public final class WorkflowRepository: WorkflowRepositoryProtocol {
    private let apiClient: APIClient
    private let apiConfiguration: APIConfiguration

    public init(apiClient: APIClient, configuration: APIConfiguration = .localVapor) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }

    public func getWorkflow(projectId: UUID) async throws -> WorkflowBundleDTO {
        let endpoint = WorkflowEndpoint.getWorkflow(projectId: projectId, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<WorkflowBundleDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("No workflow data returned from server") }
        return data
    }

    public func createStatus(projectId: UUID, payload: CreateWorkflowStatusRequest) async throws -> WorkflowStatusDTO {
        let endpoint = WorkflowEndpoint.createStatus(projectId: projectId, payload: payload, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<WorkflowStatusDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("Failed to create status") }
        return data
    }

    public func updateStatus(statusId: UUID, payload: UpdateWorkflowStatusRequest) async throws -> WorkflowStatusDTO {
        let endpoint = WorkflowEndpoint.updateStatus(statusId: statusId, payload: payload, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<WorkflowStatusDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("Failed to update status") }
        return data
    }

    public func deleteStatus(statusId: UUID) async throws {
        let endpoint = WorkflowEndpoint.deleteStatus(statusId: statusId, configuration: apiConfiguration)
        _ = try await apiClient.request(endpoint, responseType: EmptyResponse.self)
    }

    public func createRule(projectId: UUID, payload: CreateAutomationRuleRequest) async throws -> AutomationRuleDTO {
        let endpoint = WorkflowEndpoint.createRule(projectId: projectId, payload: payload, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<AutomationRuleDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("Failed to create rule") }
        return data
    }

    public func updateRule(ruleId: UUID, payload: UpdateAutomationRuleRequest) async throws -> AutomationRuleDTO {
        let endpoint = WorkflowEndpoint.updateRule(ruleId: ruleId, payload: payload, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<AutomationRuleDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("Failed to update rule") }
        return data
    }

    public func deleteRule(ruleId: UUID) async throws {
        let endpoint = WorkflowEndpoint.deleteRule(ruleId: ruleId, configuration: apiConfiguration)
        _ = try await apiClient.request(endpoint, responseType: EmptyResponse.self)
    }
}

