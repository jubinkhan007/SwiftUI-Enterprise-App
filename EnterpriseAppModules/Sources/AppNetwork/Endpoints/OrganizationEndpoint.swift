import Foundation
import SharedModels

/// API endpoints for Organization management.
public enum OrganizationEndpoint {
    case me(orgId: UUID?, configuration: APIConfiguration)
    case myInvites(configuration: APIConfiguration)
    case listOrgs(configuration: APIConfiguration)
    case createOrg(payload: CreateOrganizationRequest, configuration: APIConfiguration)
    case showOrg(id: UUID, configuration: APIConfiguration)
    case listMembers(orgId: UUID, configuration: APIConfiguration)
    case createInvite(orgId: UUID, payload: CreateInviteRequest, configuration: APIConfiguration)
    case listInvites(orgId: UUID, configuration: APIConfiguration)
    case acceptInvite(inviteId: UUID, configuration: APIConfiguration)
    case updateMemberRole(orgId: UUID, memberId: UUID, payload: UpdateMemberRoleRequest, configuration: APIConfiguration)
    case removeMember(orgId: UUID, memberId: UUID, configuration: APIConfiguration)
    case revokeInvite(orgId: UUID, inviteId: UUID, configuration: APIConfiguration)
    case auditLog(orgId: UUID, configuration: APIConfiguration)
}

extension OrganizationEndpoint: APIEndpoint {
    public var baseURL: URL {
        switch self {
        case .me(_, let c), .myInvites(let c), .listOrgs(let c), .createOrg(_, let c),
             .showOrg(_, let c), .listMembers(_, let c),
             .createInvite(_, _, let c), .listInvites(_, let c),
             .acceptInvite(_, let c), .updateMemberRole(_, _, _, let c),
             .removeMember(_, _, let c), .revokeInvite(_, _, let c),
             .auditLog(_, let c):
            return c.baseURL
        }
    }

    public var path: String {
        switch self {
        case .me(let orgId, _):
            if let orgId = orgId {
                return "/api/me?org_id=\(orgId.uuidString)"
            }
            return "/api/me"
        case .myInvites:
            return "/api/invites"
        case .listOrgs, .createOrg:
            return "/api/organizations"
        case .showOrg(let id, _):
            return "/api/organizations/\(id.uuidString)"
        case .listMembers(let orgId, _):
            return "/api/organizations/\(orgId.uuidString)/members"
        case .createInvite(let orgId, _, _):
            return "/api/organizations/\(orgId.uuidString)/invites"
        case .listInvites(let orgId, _):
            return "/api/organizations/\(orgId.uuidString)/invites"
        case .acceptInvite(let inviteId, _):
            return "/api/organizations/invites/\(inviteId.uuidString)/accept"
        case .updateMemberRole(let orgId, let memberId, _, _):
            return "/api/organizations/\(orgId.uuidString)/members/\(memberId.uuidString)/role"
        case .removeMember(let orgId, let memberId, _):
            return "/api/organizations/\(orgId.uuidString)/members/\(memberId.uuidString)"
        case .revokeInvite(let orgId, let inviteId, _):
            return "/api/organizations/\(orgId.uuidString)/invites/\(inviteId.uuidString)/revoke"
        case .auditLog(let orgId, _):
            return "/api/organizations/\(orgId.uuidString)/audit-log"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .me, .myInvites, .listOrgs, .showOrg, .listMembers, .listInvites, .auditLog:
            return .get
        case .createOrg, .createInvite, .acceptInvite, .revokeInvite:
            return .post
        case .updateMemberRole:
            return .put
        case .removeMember:
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
        case .createOrg(let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .createInvite(_, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        case .updateMemberRole(_, _, let payload, _):
            return try? JSONCoding.encoder.encode(payload)
        default:
            return nil
        }
    }
}
