import Foundation
import SharedModels

/// Self-service endpoints for the signed-in user's login sessions.
/// Backed by `UserSessionController.listMySessions` / `revokeMySession`.
public enum SessionEndpoint {
    case listMine(configuration: APIConfiguration)
    case revokeMine(sessionId: UUID, configuration: APIConfiguration)
}

extension SessionEndpoint: APIEndpoint {
    public var baseURL: URL {
        switch self {
        case .listMine(let c), .revokeMine(_, let c):
            return c.baseURL
        }
    }

    public var path: String {
        switch self {
        case .listMine:
            return "/api/me/sessions"
        case .revokeMine(let sessionId, _):
            return "/api/me/sessions/\(sessionId.uuidString)"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .listMine: return .get
        case .revokeMine: return .delete
        }
    }

    public var queryParameters: [String: String]? { nil }

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

    public var body: Data? { nil }
}

