import Foundation
import SharedModels

public enum ReleaseEndpoint {
    case list(projectId: UUID, configuration: APIConfiguration)
    case create(projectId: UUID, payload: CreateReleaseRequest, configuration: APIConfiguration)
    case progress(releaseId: UUID, configuration: APIConfiguration)
    case finalize(releaseId: UUID, lock: Bool?, configuration: APIConfiguration)
    case issues(releaseId: UUID, configuration: APIConfiguration)
}

extension ReleaseEndpoint: APIEndpoint {
    public var baseURL: URL { configuration.baseURL }

    private var configuration: APIConfiguration {
        switch self {
        case .list(_, let c), .create(_, _, let c), .progress(_, let c), .finalize(_, _, let c), .issues(_, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .list(let projectId, _), .create(let projectId, _, _):
            return "/api/projects/\(projectId.uuidString)/releases"
        case .progress(let releaseId, _):
            return "/api/releases/\(releaseId.uuidString)/progress"
        case .finalize(let releaseId, _, _):
            return "/api/releases/\(releaseId.uuidString)/release"
        case .issues(let releaseId, _):
            return "/api/releases/\(releaseId.uuidString)/issues"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .list, .progress, .issues:
            return .get
        case .create, .finalize:
            return .post
        }
    }

    public var headers: [String: String]? {
        var h = ["Content-Type": "application/json"]
        if let token = TokenStore.shared.token { h["Authorization"] = "Bearer \(token)" }
        if let orgId = OrganizationContext.shared.orgId { h["X-Org-Id"] = orgId.uuidString }
        return h
    }

    public var body: Data? {
        switch self {
        case .create(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .finalize(_, let lock, _):
            return try? JSONCoding.encoder.encode(FinalizeReleaseRequest(lock: lock))
        default:
            return nil
        }
    }
}

