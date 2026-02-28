import Foundation
import SharedModels

public enum WorkflowEndpoint {
    case getWorkflow(projectId: UUID, configuration: APIConfiguration)

    case createStatus(projectId: UUID, payload: CreateWorkflowStatusRequest, configuration: APIConfiguration)
    case updateStatus(statusId: UUID, payload: UpdateWorkflowStatusRequest, configuration: APIConfiguration)
    case deleteStatus(statusId: UUID, configuration: APIConfiguration)

    case createRule(projectId: UUID, payload: CreateAutomationRuleRequest, configuration: APIConfiguration)
    case updateRule(ruleId: UUID, payload: UpdateAutomationRuleRequest, configuration: APIConfiguration)
    case deleteRule(ruleId: UUID, configuration: APIConfiguration)
}

extension WorkflowEndpoint: APIEndpoint {
    public var baseURL: URL { configuration.baseURL }

    private var configuration: APIConfiguration {
        switch self {
        case .getWorkflow(_, let c),
             .createStatus(_, _, let c), .updateStatus(_, _, let c), .deleteStatus(_, let c),
             .createRule(_, _, let c), .updateRule(_, _, let c), .deleteRule(_, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .getWorkflow(let projectId, _):
            return "/api/projects/\(projectId.uuidString)/workflow"

        case .createStatus(let projectId, _, _):
            return "/api/projects/\(projectId.uuidString)/statuses"
        case .updateStatus(let statusId, _, _), .deleteStatus(let statusId, _):
            return "/api/statuses/\(statusId.uuidString)"

        case .createRule(let projectId, _, _):
            return "/api/projects/\(projectId.uuidString)/automation-rules"
        case .updateRule(let ruleId, _, _), .deleteRule(let ruleId, _):
            return "/api/automation-rules/\(ruleId.uuidString)"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .getWorkflow:
            return .get
        case .createStatus, .createRule:
            return .post
        case .updateStatus, .updateRule:
            return .patch
        case .deleteStatus, .deleteRule:
            return .delete
        }
    }

    public var queryParameters: [String: String]? { nil }

    public var headers: [String: String]? {
        var h = ["Content-Type": "application/json"]
        if let token = TokenStore.shared.token { h["Authorization"] = "Bearer \(token)" }
        if let orgId = OrganizationContext.shared.orgId { h["X-Org-Id"] = orgId.uuidString }
        return h
    }

    public var body: Data? {
        switch self {
        case .createStatus(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .updateStatus(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .createRule(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .updateRule(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        default:
            return nil
        }
    }
}

