import Foundation
import SharedModels

public enum HierarchyEndpoint {
    case getHierarchy(configuration: APIConfiguration)
    case createSpace(name: String, description: String?, configuration: APIConfiguration)
    case createProject(spaceId: UUID, name: String, description: String?, configuration: APIConfiguration)
    case createList(projectId: UUID, name: String, color: String?, configuration: APIConfiguration)
}

extension HierarchyEndpoint: APIEndpoint {
    public var baseURL: URL {
        switch self {
        case .getHierarchy(let config),
             .createSpace(_, _, let config),
             .createProject(_, _, _, let config),
             .createList(_, _, _, let config):
            return config.baseURL
        }
    }

    public var path: String {
        switch self {
        case .getHierarchy: return "/api/hierarchy"
        case .createSpace: return "/api/spaces"
        case .createProject(let spaceId, _, _, _): return "/api/spaces/\(spaceId.uuidString)/projects"
        case .createList(let projectId, _, _, _): return "/api/projects/\(projectId.uuidString)/lists"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .getHierarchy: return .get
        case .createSpace, .createProject, .createList: return .post
        }
    }

    public var queryParameters: [String: String]? {
        return nil
    }

    public var headers: [String: String]? {
        var h = ["Content-Type": "application/json"]
        if let token = TokenStore.shared.token {
            h["Authorization"] = "Bearer \(token)"
        }
        if let orgId = OrganizationContext.shared.orgId {
            h["X-Org-Id"] = orgId.uuidString
        }
        return h
    }

    public var body: Data? {
        switch self {
        case .createSpace(let name, let desc, _):
            let payload = ["name": name, "description": desc]
            return try? JSONSerialization.data(withJSONObject: payload)
        case .createProject(_, let name, let desc, _):
            let payload = ["name": name, "description": desc]
            return try? JSONSerialization.data(withJSONObject: payload)
        case .createList(_, let name, let color, _):
            let payload = ["name": name, "color": color]
            return try? JSONSerialization.data(withJSONObject: payload)
        default:
            return nil
        }
    }
}
