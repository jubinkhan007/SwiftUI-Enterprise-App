import Foundation
import SharedModels

public enum SprintEndpoint {
    case list(projectId: UUID, configuration: APIConfiguration)
    case create(projectId: UUID, payload: CreateSprintRequest, configuration: APIConfiguration)
}

extension SprintEndpoint: APIEndpoint {
    public var baseURL: URL { configuration.baseURL }

    private var configuration: APIConfiguration {
        switch self {
        case .list(_, let c), .create(_, _, let c): return c
        }
    }

    public var path: String {
        switch self {
        case .list(let projectId, _):
            return "/api/projects/\(projectId.uuidString)/sprints"
        case .create(let projectId, _, _):
            return "/api/projects/\(projectId.uuidString)/sprints"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .list: return .get
        case .create: return .post
        }
    }

    public var headers: [String : String]? {
        var h: [String: String] = [:]
        if let token = TokenStore.shared.token { h["Authorization"] = "Bearer \(token)" }
        if let orgId = OrganizationContext.shared.orgId { h["X-Org-Id"] = orgId.uuidString }
        h["Accept"] = "application/json"

        switch self {
        case .create:
            h["Content-Type"] = "application/json; charset=utf-8"
        default:
            break
        }

        return h
    }

    public var body: Data? {
        switch self {
        case .create(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        default:
            return nil
        }
    }
}

