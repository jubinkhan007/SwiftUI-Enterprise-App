import Foundation
import SharedModels

public enum NotificationEndpoint {
    case getNotifications(unreadOnly: Bool, configuration: APIConfiguration)
    case markRead(id: UUID, configuration: APIConfiguration)
}

extension NotificationEndpoint: APIEndpoint {
    public var baseURL: URL {
        switch self {
        case .getNotifications(_, let c), .markRead(_, let c):
            return c.baseURL
        }
    }

    public var path: String {
        switch self {
        case .getNotifications:
            return "/api/notifications"
        case .markRead(let id, _):
            return "/api/notifications/\(id.uuidString)/read"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .getNotifications: return .get
        case .markRead: return .post
        }
    }

    public var queryParameters: [String: String]? {
        switch self {
        case .getNotifications(let unreadOnly, _):
            if unreadOnly { return ["unread": "true"] }
            return nil
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

    public var body: Data? { nil }
}
