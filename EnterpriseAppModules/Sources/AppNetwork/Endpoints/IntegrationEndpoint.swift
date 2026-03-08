import Foundation
import SharedModels

public enum IntegrationEndpoint: Endpoint {
    case getAPIKeys
    case createAPIKey(CreateAPIKeyRequest)
    case revokeAPIKey(UUID)
    
    case getWebhooks
    case createWebhook(CreateWebhookSubscriptionRequest)
    case updateWebhook(UUID, UpdateWebhookSubscriptionRequest)
    case deleteWebhook(UUID)
    case testWebhook(UUID)

    public var path: String {
        switch self {
        case .getAPIKeys, .createAPIKey:
            return "/api/api-keys"
        case .revokeAPIKey(let id):
            return "/api/api-keys/\(id.uuidString)"
        case .getWebhooks, .createWebhook:
            return "/api/webhooks"
        case .updateWebhook(let id, _), .deleteWebhook(let id):
            return "/api/webhooks/\(id.uuidString)"
        case .testWebhook(let id):
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

    public var body: Data? {
        switch self {
        case .createAPIKey(let payload): return try? JSONCoding.encoder.encode(payload)
        case .createWebhook(let payload): return try? JSONCoding.encoder.encode(payload)
        case .updateWebhook(_, let payload): return try? JSONCoding.encoder.encode(payload)
        default: return nil
        }
    }
}
