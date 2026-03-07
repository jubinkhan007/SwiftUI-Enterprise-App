import Foundation
import SharedModels
import AppNetwork
import Domain

public final class WorkflowRepository: WorkflowRepositoryProtocol {
    private let apiClient: APIClient
    private let apiConfiguration: APIConfiguration
    private let localStore: ProjectSettingsLocalStoreProtocol

    public init(
        apiClient: APIClient,
        localStore: ProjectSettingsLocalStoreProtocol = ProjectSettingsLocalStore(),
        configuration: APIConfiguration = .localVapor
    ) {
        self.apiClient = apiClient
        self.localStore = localStore
        self.apiConfiguration = configuration
    }

    public func getWorkflow(projectId: UUID) async throws -> WorkflowBundleDTO {
        guard let orgId = OrganizationContext.shared.orgId else {
            throw NetworkError.underlying("Missing organization context")
        }

        do {
            let endpoint = WorkflowEndpoint.getWorkflow(projectId: projectId, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<WorkflowBundleDTO>.self)
            guard let data = response.data else { throw NetworkError.underlying("No workflow data returned from server") }
            await localStore.saveWorkflowBundle(orgId: orgId, projectId: projectId, bundle: data)
            return data
        } catch let error as NetworkError {
            if error == .offline {
                if let cached = await localStore.getWorkflowBundle(orgId: orgId, projectId: projectId) {
                    return cached
                }
            }
            throw error
        }
    }

    public func createStatus(projectId: UUID, payload: CreateWorkflowStatusRequest) async throws -> WorkflowStatusDTO {
        let endpoint = WorkflowEndpoint.createStatus(projectId: projectId, payload: payload, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<WorkflowStatusDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("Failed to create status") }
        if let orgId = OrganizationContext.shared.orgId {
            await localStore.invalidateWorkflowBundle(orgId: orgId, projectId: projectId)
        }
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
