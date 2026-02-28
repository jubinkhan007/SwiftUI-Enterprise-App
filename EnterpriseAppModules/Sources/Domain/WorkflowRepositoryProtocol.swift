import Foundation
import SharedModels

public protocol WorkflowRepositoryProtocol: Sendable {
    func getWorkflow(projectId: UUID) async throws -> WorkflowBundleDTO

    func createStatus(projectId: UUID, payload: CreateWorkflowStatusRequest) async throws -> WorkflowStatusDTO
    func updateStatus(statusId: UUID, payload: UpdateWorkflowStatusRequest) async throws -> WorkflowStatusDTO
    func deleteStatus(statusId: UUID) async throws

    func createRule(projectId: UUID, payload: CreateAutomationRuleRequest) async throws -> AutomationRuleDTO
    func updateRule(ruleId: UUID, payload: UpdateAutomationRuleRequest) async throws -> AutomationRuleDTO
    func deleteRule(ruleId: UUID) async throws
}

