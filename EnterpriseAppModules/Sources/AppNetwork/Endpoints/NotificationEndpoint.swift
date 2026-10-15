import Foundation
import SharedModels

public enum NotificationEndpoint {
    case getNotifications(unreadOnly: Bool, configuration: APIConfiguration)
    case getNotificationsFiltered(category: String?, unreadOnly: Bool, configuration: APIConfiguration)
    case markRead(id: UUID, configuration: APIConfiguration)
    case markAllRead(configuration: APIConfiguration)
    case unreadCount(configuration: APIConfiguration)
}

extension NotificationEndpoint: APIEndpoint {
    public var baseURL: URL {
        switch self {
        case .getNotifications(_, let c), .getNotificationsFiltered(_, _, let c),
             .markRead(_, let c), .markAllRead(let c), .unreadCount(let c):
            return c.baseURL
        }
    }

    public var path: String {
        switch self {
        case .getNotifications, .getNotificationsFiltered:
            return "/api/notifications"
        case .markRead(let id, _):
            return "/api/notifications/\(id.uuidString)/read"
        case .markAllRead:
            return "/api/notifications/mark-all-read"
        case .unreadCount:
            return "/api/notifications/unread-count"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .getNotifications, .getNotificationsFiltered, .unreadCount:
            return .get
        case .markRead, .markAllRead:
            return .post
        }
    }

    public var queryParameters: [String: String]? {
        switch self {
        case .getNotifications(let unreadOnly, _):
            if unreadOnly { return ["unread": "true"] }
            return nil
        case .getNotificationsFiltered(let category, let unreadOnly, _):
            var params: [String: String] = [:]
            if unreadOnly { params["unread"] = "true" }
            if let cat = category, !cat.isEmpty { params["category"] = cat }
            return params.isEmpty ? nil : params
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
