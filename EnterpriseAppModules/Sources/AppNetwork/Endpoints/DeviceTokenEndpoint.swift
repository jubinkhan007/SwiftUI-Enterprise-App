import Foundation
import SharedModels

public enum DeviceTokenEndpoint {
    case register(token: String, platform: String, environment: String?, configuration: APIConfiguration)
    case unregister(token: String, configuration: APIConfiguration)
    case list(configuration: APIConfiguration)
    case testPush(entityType: String?, entityId: String?, configuration: APIConfiguration)
}

extension DeviceTokenEndpoint: APIEndpoint {
    public var baseURL: URL {
        switch self {
        case .register(_, _, _, let c),
             .unregister(_, let c),
             .list(let c),
             .testPush(_, _, let c):
            return c.baseURL
        }
    }

    public var path: String {
        switch self {
        case .register, .list:
            return "/api/me/device-tokens"
        case .unregister(let token, _):
            return "/api/me/device-tokens/\(token)"
        case .testPush:
            return "/api/me/device-tokens/test"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .register, .testPush:
            return .post
        case .list:
            return .get
        case .unregister:
            return .delete
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

    public var body: Data? {
        switch self {
        case .register(let token, let platform, let environment, _):
            let req = RegisterDeviceTokenRequest(token: token, platform: platform, environment: environment)
            return try? JSONEncoder().encode(req)
        case .testPush(let entityType, let entityId, _):
            struct TestReq: Codable {
                let entityType: String?
                let entityId: String?
            }
            return try? JSONEncoder().encode(TestReq(entityType: entityType, entityId: entityId))
        default:
            return nil
        }
    }
}
