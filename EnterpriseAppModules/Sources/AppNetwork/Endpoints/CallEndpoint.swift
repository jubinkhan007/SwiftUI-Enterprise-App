import Foundation
import SharedModels

public enum CallEndpoint {
    case initiate(payload: InitiateCallRequest, configuration: APIConfiguration)
    case show(id: UUID, configuration: APIConfiguration)
    case accept(id: UUID, configuration: APIConfiguration)
    case decline(id: UUID, configuration: APIConfiguration)
    case end(id: UUID, configuration: APIConfiguration)
    case leave(id: UUID, configuration: APIConfiguration)
    case updateMyState(id: UUID, payload: UpdateParticipantStateRequest, configuration: APIConfiguration)
    case adminAction(id: UUID, payload: CallAdminEventRequest, configuration: APIConfiguration)
    case refreshToken(id: UUID, configuration: APIConfiguration)
    case createRecord(id: UUID, payload: CreateCallRecordRequest, configuration: APIConfiguration)
    case registerVoIP(payload: RegisterVoIPTokenRequest, configuration: APIConfiguration)
    case deleteVoIP(token: String, configuration: APIConfiguration)
}

extension CallEndpoint: APIEndpoint {
    public var baseURL: URL { configuration.baseURL }

    private var configuration: APIConfiguration {
        switch self {
        case .initiate(_, let c), .show(_, let c), .accept(_, let c), .decline(_, let c),
             .end(_, let c), .leave(_, let c), .updateMyState(_, _, let c),
             .adminAction(_, _, let c), .refreshToken(_, let c),
             .createRecord(_, _, let c), .registerVoIP(_, let c), .deleteVoIP(_, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .initiate: return "/api/calls/initiate"
        case .show(let id, _): return "/api/calls/\(id.uuidString)"
        case .accept(let id, _): return "/api/calls/\(id.uuidString)/accept"
        case .decline(let id, _): return "/api/calls/\(id.uuidString)/decline"
        case .end(let id, _): return "/api/calls/\(id.uuidString)/end"
        case .leave(let id, _): return "/api/calls/\(id.uuidString)/leave"
        case .updateMyState(let id, _, _): return "/api/calls/\(id.uuidString)/state"
        case .adminAction(let id, _, _): return "/api/calls/\(id.uuidString)/admin"
        case .refreshToken(let id, _): return "/api/calls/\(id.uuidString)/token"
        case .createRecord(let id, _, _): return "/api/calls/\(id.uuidString)/records"
        case .registerVoIP: return "/api/me/voip-tokens"
        case .deleteVoIP(let token, _):
            let escaped = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
            return "/api/me/voip-tokens/\(escaped)"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .show, .refreshToken: return .get
        case .updateMyState: return .put
        case .deleteVoIP: return .delete
        case .initiate, .accept, .decline, .end, .leave, .adminAction, .createRecord, .registerVoIP:
            return .post
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
        case .initiate(let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .updateMyState(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .adminAction(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .createRecord(_, let payload, _): return try? JSONCoding.encoder.encode(payload)
        case .registerVoIP(let payload, _): return try? JSONCoding.encoder.encode(payload)
        default: return nil
        }
    }
}
