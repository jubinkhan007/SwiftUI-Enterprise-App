import Foundation
import SharedModels

public enum AgileEndpoint {
    case getBacklog(projectId: UUID, configuration: APIConfiguration)
    case getSprintIssues(sprintId: UUID, configuration: APIConfiguration)
}

extension AgileEndpoint: APIEndpoint {
    public var baseURL: URL { configuration.baseURL }

    private var configuration: APIConfiguration {
        switch self {
        case .getBacklog(_, let c), .getSprintIssues(_, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .getBacklog(let projectId, _):
            return "/api/projects/\(projectId.uuidString)/backlog"
        case .getSprintIssues(let sprintId, _):
            return "/api/sprints/\(sprintId.uuidString)/issues"
        }
    }

    public var method: HTTPMethod { .get }

    public var headers: [String: String]? {
        var h: [String: String] = [:]
        if let token = TokenStore.shared.token { h["Authorization"] = "Bearer \(token)" }
        if let orgId = OrganizationContext.shared.orgId { h["X-Org-Id"] = orgId.uuidString }
        h["Accept"] = "application/json"
        return h
    }

    public var body: Data? { nil }
}

