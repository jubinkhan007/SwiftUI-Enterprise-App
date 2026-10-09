import Foundation
import SharedModels

public enum AIAssistantEndpoint {
    case copilot(payload: AIAssistantRequest, configuration: APIConfiguration)
    case breakdown(payload: AIAssistantRequest, configuration: APIConfiguration)
    case standup(configuration: APIConfiguration)
}

extension AIAssistantEndpoint: APIEndpoint {
    public var baseURL: URL { configuration.baseURL }

    private var configuration: APIConfiguration {
        switch self {
        case .copilot(_, let c), .breakdown(_, let c), .standup(let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .copilot:
            return "/api/ai/copilot"
        case .breakdown:
            return "/api/ai/breakdown"
        case .standup:
            return "/api/ai/standup"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .copilot, .breakdown:
            return .post
        case .standup:
            return .get
        }
    }

    public var headers: [String: String]? {
        var h: [String: String] = [:]
        if let token = TokenStore.shared.token { h["Authorization"] = "Bearer \(token)" }
        if let orgId = OrganizationContext.shared.orgId { h["X-Org-Id"] = orgId.uuidString }
        h["Accept"] = "application/json"

        switch self {
        case .copilot, .breakdown:
            h["Content-Type"] = "application/json; charset=utf-8"
        default:
            break
        }

        return h
    }

    public var body: Data? {
        switch self {
        case .copilot(let payload, _), .breakdown(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .standup:
            return nil
        }
    }
}
