import Foundation
import SharedModels

public enum IntegrationEndpoint {
    case listAPIKeys(configuration: APIConfiguration)
    case createAPIKey(payload: CreateAPIKeyRequest, configuration: APIConfiguration)
    case revokeAPIKey(id: UUID, configuration: APIConfiguration)

    case listWebhooks(configuration: APIConfiguration)
    case createWebhook(payload: CreateWebhookSubscriptionRequest, configuration: APIConfiguration)
    case deleteWebhook(id: UUID, configuration: APIConfiguration)
    case testWebhook(id: UUID, configuration: APIConfiguration)
}

extension IntegrationEndpoint: APIEndpoint {
    public var baseURL: URL {
        switch self {
        case .listAPIKeys(let c), .createAPIKey(_, let c), .revokeAPIKey(_, let c),
             .listWebhooks(let c), .createWebhook(_, let c), .deleteWebhook(_, let c), .testWebhook(_, let c):
            return c.baseURL
        }
    }

    public var path: String {
        switch self {
        case .listAPIKeys, .createAPIKey:
            return "/api/apikeys"
        case .revokeAPIKey(let id, _):
            return "/api/apikeys/\(id.uuidString)"
        case .listWebhooks, .createWebhook:
            return "/api/webhooks"
        case .deleteWebhook(let id, _):
            return "/api/webhooks/\(id.uuidString)"
        case .testWebhook(let id, _):
            return "/api/webhooks/\(id.uuidString)/test"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .listAPIKeys, .listWebhooks:
            return .get
        case .createAPIKey, .createWebhook, .testWebhook:
            return .post
        case .revokeAPIKey:
            return .delete
        case .deleteWebhook:
            return .delete
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
        case .createAPIKey(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .createWebhook(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .listAPIKeys, .revokeAPIKey, .listWebhooks, .deleteWebhook, .testWebhook:
            return nil
        }
    }
}

