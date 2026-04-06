import Foundation
import SharedModels

public enum MessagingEndpoint {
    case getConversations(configuration: APIConfiguration)
    case createConversation(payload: CreateConversationRequest, configuration: APIConfiguration)
    case getConversation(id: UUID, configuration: APIConfiguration)
    case getMessages(conversationId: UUID, cursor: UUID?, limit: Int, configuration: APIConfiguration)
    case sendMessage(conversationId: UUID, payload: SendMessageRequest, configuration: APIConfiguration)
    case markRead(conversationId: UUID, payload: MarkReadRequest, configuration: APIConfiguration)
}

extension MessagingEndpoint: APIEndpoint {
    public var baseURL: URL {
        configuration.baseURL
    }

    private var configuration: APIConfiguration {
        switch self {
        case .getConversations(let c), .createConversation(_, let c),
             .getConversation(_, let c), .getMessages(_, _, _, let c),
             .sendMessage(_, _, let c), .markRead(_, _, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .getConversations, .createConversation:
            return "/api/conversations"
        case .getConversation(let id, _):
            return "/api/conversations/\(id.uuidString)"
        case .getMessages(let id, _, _, _), .sendMessage(let id, _, _):
            return "/api/conversations/\(id.uuidString)/messages"
        case .markRead(let id, _, _):
            return "/api/conversations/\(id.uuidString)/read"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .getConversations, .getConversation, .getMessages:
            return .get
        case .createConversation, .sendMessage, .markRead:
            return .post
        }
    }

    public var queryParameters: [String: String]? {
        switch self {
        case .getMessages(_, let cursor, let limit, _):
            var params: [String: String] = ["limit": "\(limit)"]
            if let cursor = cursor { params["cursor"] = cursor.uuidString }
            return params
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
        case .createConversation(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .sendMessage(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .markRead(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        default:
            return nil
        }
    }
}
