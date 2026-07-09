import Foundation
import SharedModels

public enum MessagingEndpoint {
    case getConversations(searchQuery: String?, configuration: APIConfiguration)
    case createConversation(payload: CreateConversationRequest, configuration: APIConfiguration)
    case getConversation(id: UUID, configuration: APIConfiguration)
    case updateConversation(id: UUID, payload: UpdateConversationRequest, configuration: APIConfiguration)
    case archiveConversation(id: UUID, configuration: APIConfiguration)
    case leaveConversation(id: UUID, configuration: APIConfiguration)
    case addMembers(conversationId: UUID, payload: AddConversationMembersRequest, configuration: APIConfiguration)
    case removeMember(conversationId: UUID, memberId: UUID, configuration: APIConfiguration)
    case updatePreferences(conversationId: UUID, payload: UpdateConversationMemberPreferencesRequest, configuration: APIConfiguration)
    case getMessages(conversationId: UUID, cursor: UUID?, limit: Int, configuration: APIConfiguration)
    case getThread(messageId: UUID, configuration: APIConfiguration)
    case sendMessage(conversationId: UUID, payload: SendMessageRequest, configuration: APIConfiguration)
    case markRead(conversationId: UUID, payload: MarkReadRequest, configuration: APIConfiguration)
    case editMessage(messageId: UUID, payload: EditMessageRequest, configuration: APIConfiguration)
    case deleteMessage(messageId: UUID, configuration: APIConfiguration)
    case sendTypingIndicator(conversationId: UUID, payload: TypingIndicatorRequest, configuration: APIConfiguration)
    case updateMemberRole(conversationId: UUID, memberId: UUID, payload: UpdateChannelMemberRoleRequest, configuration: APIConfiguration)
    case approveMember(conversationId: UUID, memberId: UUID, configuration: APIConfiguration)
    case addReaction(messageId: UUID, payload: ReactionRequest, configuration: APIConfiguration)
    case removeReaction(messageId: UUID, emoji: String, configuration: APIConfiguration)
    case pinMessage(messageId: UUID, configuration: APIConfiguration)
    case unpinMessage(messageId: UUID, configuration: APIConfiguration)
    case listPins(conversationId: UUID, configuration: APIConfiguration)
    case bookmarkMessage(messageId: UUID, configuration: APIConfiguration)
    case unbookmarkMessage(messageId: UUID, configuration: APIConfiguration)
    case listBookmarks(configuration: APIConfiguration)
    case convertToTask(messageId: UUID, payload: ConvertMessageToTaskRequest, configuration: APIConfiguration)
    case globalSearch(q: String?, from: String?, `in`: String?, after: String?, configuration: APIConfiguration)
    case searchFiles(q: String?, configuration: APIConfiguration)
}

extension MessagingEndpoint: APIEndpoint {
    public var baseURL: URL {
        configuration.baseURL
    }

    private var configuration: APIConfiguration {
        switch self {
        case .getConversations(_, let c), .createConversation(_, let c),
             .getConversation(_, let c), .updateConversation(_, _, let c),
             .archiveConversation(_, let c), .leaveConversation(_, let c),
             .addMembers(_, _, let c), .removeMember(_, _, let c),
             .updatePreferences(_, _, let c), .getMessages(_, _, _, let c),
             .getThread(_, let c),
             .sendMessage(_, _, let c), .markRead(_, _, let c),
             .editMessage(_, _, let c), .deleteMessage(_, let c),
             .sendTypingIndicator(_, _, let c),
             .updateMemberRole(_, _, _, let c), .approveMember(_, _, let c),
             .addReaction(_, _, let c), .removeReaction(_, _, let c),
             .pinMessage(_, let c), .unpinMessage(_, let c),
             .listPins(_, let c),
             .bookmarkMessage(_, let c), .unbookmarkMessage(_, let c),
             .listBookmarks(let c),
             .convertToTask(_, _, let c),
             .globalSearch(_, _, _, _, let c),
             .searchFiles(_, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .getConversations, .createConversation:
            return "/api/conversations"
        case .getConversation(let id, _), .updateConversation(let id, _, _), .archiveConversation(let id, _):
            return "/api/conversations/\(id.uuidString)"
        case .leaveConversation(let id, _):
            return "/api/conversations/\(id.uuidString)/leave"
        case .addMembers(let id, _, _):
            return "/api/conversations/\(id.uuidString)/members"
        case .removeMember(let id, let memberId, _):
            return "/api/conversations/\(id.uuidString)/members/\(memberId.uuidString)"
        case .updatePreferences(let id, _, _):
            return "/api/conversations/\(id.uuidString)/preferences"
        case .getMessages(let id, _, _, _), .sendMessage(let id, _, _):
            return "/api/conversations/\(id.uuidString)/messages"
        case .markRead(let id, _, _):
            return "/api/conversations/\(id.uuidString)/read"
        case .sendTypingIndicator(let id, _, _):
            return "/api/conversations/\(id.uuidString)/typing"
        case .updateMemberRole(let id, let memberId, _, _):
            return "/api/conversations/\(id.uuidString)/members/\(memberId.uuidString)/role"
        case .approveMember(let id, let memberId, _):
            return "/api/conversations/\(id.uuidString)/members/\(memberId.uuidString)/approve"
        case .getThread(let id, _):
            return "/api/messages/\(id.uuidString)/thread"
        case .editMessage(let id, _, _), .deleteMessage(let id, _):
            return "/api/messages/\(id.uuidString)"
        case .addReaction(let id, _, _), .removeReaction(let id, _, _):
            return "/api/messages/\(id.uuidString)/reactions"
        case .pinMessage(let id, _), .unpinMessage(let id, _):
            return "/api/messages/\(id.uuidString)/pin"
        case .listPins(let id, _):
            return "/api/conversations/\(id.uuidString)/pins"
        case .bookmarkMessage(let id, _), .unbookmarkMessage(let id, _):
            return "/api/messages/\(id.uuidString)/bookmark"
        case .listBookmarks:
            return "/api/me/bookmarks"
        case .convertToTask(let id, _, _):
            return "/api/messages/\(id.uuidString)/convert-to-task"
        case .globalSearch:
            return "/api/search"
        case .searchFiles:
            return "/api/search/files"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .getConversations, .getConversation, .getMessages, .getThread,
             .listPins, .listBookmarks, .globalSearch, .searchFiles:
            return .get
        case .createConversation, .archiveConversation, .leaveConversation, .addMembers, .updatePreferences, .sendMessage, .markRead, .sendTypingIndicator, .approveMember,
             .addReaction, .pinMessage, .bookmarkMessage, .convertToTask:
            return .post
        case .updateConversation, .editMessage, .updateMemberRole:
            return .put
        case .deleteMessage, .removeMember, .removeReaction, .unpinMessage, .unbookmarkMessage:
            return .delete
        }
    }

    public var queryParameters: [String: String]? {
        switch self {
        case .getMessages(_, let cursor, let limit, _):
            var params: [String: String] = ["limit": "\(limit)"]
            if let cursor = cursor { params["cursor"] = cursor.uuidString }
            return params
        case .getConversations(let search, _):
            if let s = search, !s.isEmpty { return ["search": s] }
            return nil
        case .globalSearch(let q, let from, let `in`, let after, _):
            var params: [String: String] = [:]
            if let q, !q.isEmpty { params["q"] = q }
            if let from, !from.isEmpty { params["from"] = from }
            if let `in`, !`in`.isEmpty { params["in"] = `in` }
            if let after, !after.isEmpty { params["after"] = after }
            return params
        case .searchFiles(let q, _):
            if let q, !q.isEmpty { return ["q": q] }
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

    public var body: Data? {
        switch self {
        case .createConversation(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .updateConversation(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .addMembers(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .updatePreferences(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .sendMessage(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .markRead(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .editMessage(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .sendTypingIndicator(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .updateMemberRole(_, _, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .addReaction(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .convertToTask(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        default:
            return nil
        }
    }
}
