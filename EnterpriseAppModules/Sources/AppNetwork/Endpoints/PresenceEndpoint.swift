import Foundation
import SharedModels

public enum PresenceEndpoint {
    case heartbeat(payload: PresenceHeartbeatRequest, configuration: APIConfiguration)
    case setStatus(payload: SetCustomStatusRequest, configuration: APIConfiguration)
    case clearStatus(configuration: APIConfiguration)
    case getMyPresence(configuration: APIConfiguration)
    case getUserPresence(userId: UUID, configuration: APIConfiguration)
    case getBulkPresence(userIds: [UUID], configuration: APIConfiguration)
}

extension PresenceEndpoint: APIEndpoint {
    public var baseURL: URL { configuration.baseURL }

    private var configuration: APIConfiguration {
        switch self {
        case .heartbeat(_, let c), .setStatus(_, let c), .clearStatus(let c),
             .getMyPresence(let c), .getUserPresence(_, let c), .getBulkPresence(_, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .heartbeat:
            return "/api/me/presence/heartbeat"
        case .setStatus, .clearStatus:
            return "/api/me/status"
        case .getMyPresence:
            return "/api/me/presence"
        case .getUserPresence(let id, _):
            return "/api/users/\(id.uuidString)/presence"
        case .getBulkPresence:
            return "/api/presence"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .heartbeat: return .post
        case .setStatus: return .put
        case .clearStatus: return .delete
        case .getMyPresence, .getUserPresence, .getBulkPresence: return .get
        }
    }

    public var queryParameters: [String: String]? {
        switch self {
        case .getBulkPresence(let ids, _):
            guard !ids.isEmpty else { return nil }
            return ["userIds": ids.map { $0.uuidString }.joined(separator: ",")]
        default:
            return nil
        }
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
        case .heartbeat(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .setStatus(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        default:
            return nil
        }
    }
}
