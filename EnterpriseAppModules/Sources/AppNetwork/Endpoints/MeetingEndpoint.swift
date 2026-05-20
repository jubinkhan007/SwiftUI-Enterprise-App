import Foundation
import SharedModels

public enum MeetingEndpoint {
    case createMeeting(payload: CreateMeetingRequest, configuration: APIConfiguration)
    case listMeetings(scope: String?, conversationId: UUID?, hostId: UUID?, status: String?, search: String?, from: Date?, to: Date?, configuration: APIConfiguration)
    case getMeeting(id: UUID, configuration: APIConfiguration)
    case updateMeeting(id: UUID, payload: UpdateMeetingRequest, configuration: APIConfiguration)
    case cancelMeeting(id: UUID, payload: CancelMeetingRequest, configuration: APIConfiguration)

    // Lifecycle
    case startMeeting(id: UUID, configuration: APIConfiguration)
    case endMeeting(id: UUID, configuration: APIConfiguration)
    case joinMeeting(id: UUID, configuration: APIConfiguration)
    case leaveMeeting(id: UUID, configuration: APIConfiguration)
    case heartbeat(id: UUID, configuration: APIConfiguration)

    // Participants
    case addParticipants(id: UUID, payload: AddMeetingParticipantsRequest, configuration: APIConfiguration)
    case removeParticipant(id: UUID, participantId: UUID, configuration: APIConfiguration)
    case changeRole(id: UUID, participantId: UUID, payload: ChangeMeetingRoleRequest, configuration: APIConfiguration)
    case rsvp(id: UUID, payload: MeetingRSVPRequest, configuration: APIConfiguration)
    case admit(id: UUID, participantId: UUID, configuration: APIConfiguration)
    case deny(id: UUID, participantId: UUID, configuration: APIConfiguration)

    // Notes
    case getNotes(id: UUID, configuration: APIConfiguration)
    case updateNotes(id: UUID, payload: UpdateMeetingNotesRequest, configuration: APIConfiguration)

    // Summary & action items
    case getSummary(id: UUID, configuration: APIConfiguration)
    case generateSummary(id: UUID, payload: GenerateMeetingSummaryRequest, configuration: APIConfiguration)
    case addActionItem(id: UUID, payload: CreateMeetingActionItemRequest, configuration: APIConfiguration)

    // ICS + share link
    case ics(id: UUID, configuration: APIConfiguration)
    case byJoinCode(joinCode: String, token: String, configuration: APIConfiguration)
}

extension MeetingEndpoint: APIEndpoint {
    public var baseURL: URL { configuration.baseURL }

    private var configuration: APIConfiguration {
        switch self {
        case .createMeeting(_, let c), .listMeetings(_, _, _, _, _, _, _, let c),
             .getMeeting(_, let c), .updateMeeting(_, _, let c), .cancelMeeting(_, _, let c),
             .startMeeting(_, let c), .endMeeting(_, let c),
             .joinMeeting(_, let c), .leaveMeeting(_, let c), .heartbeat(_, let c),
             .addParticipants(_, _, let c), .removeParticipant(_, _, let c),
             .changeRole(_, _, _, let c), .rsvp(_, _, let c),
             .admit(_, _, let c), .deny(_, _, let c),
             .getNotes(_, let c), .updateNotes(_, _, let c),
             .getSummary(_, let c), .generateSummary(_, _, let c),
             .addActionItem(_, _, let c),
             .ics(_, let c), .byJoinCode(_, _, let c):
            return c
        }
    }

    public var path: String {
        switch self {
        case .createMeeting, .listMeetings:
            return "/api/meetings"
        case .getMeeting(let id, _), .updateMeeting(let id, _, _), .cancelMeeting(let id, _, _):
            return "/api/meetings/\(id.uuidString)"
        case .startMeeting(let id, _):
            return "/api/meetings/\(id.uuidString)/start"
        case .endMeeting(let id, _):
            return "/api/meetings/\(id.uuidString)/end"
        case .joinMeeting(let id, _):
            return "/api/meetings/\(id.uuidString)/join"
        case .leaveMeeting(let id, _):
            return "/api/meetings/\(id.uuidString)/leave"
        case .heartbeat(let id, _):
            return "/api/meetings/\(id.uuidString)/heartbeat"
        case .addParticipants(let id, _, _):
            return "/api/meetings/\(id.uuidString)/participants"
        case .removeParticipant(let id, let pid, _):
            return "/api/meetings/\(id.uuidString)/participants/\(pid.uuidString)"
        case .changeRole(let id, let pid, _, _):
            return "/api/meetings/\(id.uuidString)/participants/\(pid.uuidString)/role"
        case .rsvp(let id, _, _):
            return "/api/meetings/\(id.uuidString)/participants/me/rsvp"
        case .admit(let id, let pid, _):
            return "/api/meetings/\(id.uuidString)/participants/\(pid.uuidString)/admit"
        case .deny(let id, let pid, _):
            return "/api/meetings/\(id.uuidString)/participants/\(pid.uuidString)/deny"
        case .getNotes(let id, _), .updateNotes(let id, _, _):
            return "/api/meetings/\(id.uuidString)/notes"
        case .getSummary(let id, _), .generateSummary(let id, _, _):
            return "/api/meetings/\(id.uuidString)/summary"
        case .addActionItem(let id, _, _):
            return "/api/meetings/\(id.uuidString)/summary/action-items"
        case .ics(let id, _):
            return "/api/meetings/\(id.uuidString)/ics"
        case .byJoinCode(let code, _, _):
            return "/api/meetings/by-code/\(code)"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .listMeetings, .getMeeting, .getNotes, .getSummary, .ics, .byJoinCode:
            return .get
        case .createMeeting, .startMeeting, .endMeeting, .joinMeeting, .leaveMeeting,
             .heartbeat, .addParticipants, .admit, .deny,
             .generateSummary, .addActionItem:
            return .post
        case .updateMeeting, .changeRole, .rsvp, .updateNotes:
            return .put
        case .cancelMeeting, .removeParticipant:
            return .delete
        }
    }

    public var queryParameters: [String: String]? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        switch self {
        case .listMeetings(let scope, let conversationId, let hostId, let status, let search, let from, let to, _):
            var params: [String: String] = [:]
            if let s = scope, !s.isEmpty { params["scope"] = s }
            if let c = conversationId { params["conversationId"] = c.uuidString }
            if let h = hostId { params["hostId"] = h.uuidString }
            if let st = status, !st.isEmpty { params["status"] = st }
            if let q = search, !q.isEmpty { params["q"] = q }
            if let f = from { params["from"] = iso.string(from: f) }
            if let t = to { params["to"] = iso.string(from: t) }
            return params.isEmpty ? nil : params
        case .byJoinCode(_, let token, _):
            return ["token": token]
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
        case .createMeeting(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .updateMeeting(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .cancelMeeting(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .addParticipants(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .changeRole(_, _, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .rsvp(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .updateNotes(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .generateSummary(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .addActionItem(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        default:
            return nil
        }
    }
}
