import Foundation
import SharedModels

public enum IntegrationEndpoint {
    case getAPIKeys(configuration: APIConfiguration)
    case createAPIKey(CreateAPIKeyRequest, configuration: APIConfiguration)
    case revokeAPIKey(UUID, configuration: APIConfiguration)
    
    case getWebhooks(configuration: APIConfiguration)
    case createWebhook(CreateWebhookSubscriptionRequest, configuration: APIConfiguration)
    case updateWebhook(UUID, UpdateWebhookSubscriptionRequest, configuration: APIConfiguration)
    case deleteWebhook(UUID, configuration: APIConfiguration)
    case testWebhook(UUID, configuration: APIConfiguration)
}

extension IntegrationEndpoint: APIEndpoint {
    public var baseURL: URL {
        configuration.baseURL
    }
    
    private var configuration: APIConfiguration {
        switch self {
        case .getAPIKeys(let c), .createAPIKey(_, let c), .revokeAPIKey(_, let c),
             .getWebhooks(let c), .createWebhook(_, let c), .updateWebhook(_, _, let c),
             .deleteWebhook(_, let c), .testWebhook(_, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .getAPIKeys, .createAPIKey:
            return "/api/api-keys"
        case .revokeAPIKey(let id, _):
            return "/api/api-keys/\(id.uuidString)"
        case .getWebhooks, .createWebhook:
            return "/api/webhooks"
        case .updateWebhook(let id, _, _), .deleteWebhook(let id, _):
            return "/api/webhooks/\(id.uuidString)"
        case .testWebhook(let id, _):
            return "/api/webhooks/\(id.uuidString)/test"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .getAPIKeys, .getWebhooks: return .get
        case .createAPIKey, .createWebhook, .testWebhook: return .post
        case .updateWebhook: return .patch
        case .revokeAPIKey, .deleteWebhook: return .delete
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
        case .createAPIKey(let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .createWebhook(let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .updateWebhook(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        default: return nil
        }
    }
}
