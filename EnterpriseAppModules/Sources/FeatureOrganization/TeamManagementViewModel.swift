import Foundation
import SharedModels
import AppNetwork
import Combine

/// ViewModel for managing team members and invites within the active organization.
/// All actions are gated by `PermissionSet` — if the user lacks the required permission,
/// the action is disabled in the UI.
@MainActor
public final class TeamManagementViewModel: ObservableObject {
    // MARK: - Published State

    @Published public var members: [OrganizationMemberDTO] = []
    @Published public var invites: [OrganizationInviteDTO] = []
    @Published public var currentPermissions: PermissionSet? = nil
    @Published public var currentRole: UserRole? = nil
    @Published public var isLoadingMembers = false
    @Published public var isLoadingInvites = false
    @Published public var errorMessage: String? = nil

    // Invite sheet state
    @Published public var showInviteSheet = false
    @Published public var inviteEmail = ""
    @Published public var inviteRole: UserRole = .member
    @Published public var isSendingInvite = false

    // Role editing
    @Published public var memberBeingEdited: OrganizationMemberDTO? = nil
    @Published public var editedRole: UserRole = .member

    private let apiClient: APIClientProtocol
    private let configuration: APIConfiguration
    public let orgId: UUID

    public init(
        orgId: UUID,
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .localVapor
    ) {
        self.orgId = orgId
        self.apiClient = apiClient
        self.configuration = configuration
    }

    // MARK: - Permission Helpers

    public var canInvite: Bool {
        currentPermissions?.has(.membersInvite) ?? false
    }

    public var canManageRoles: Bool {
        currentPermissions?.has(.membersManage) ?? false
    }

    public var canRemoveMembers: Bool {
        currentPermissions?.has(.membersRemove) ?? false
    }

    public var canViewInvites: Bool {
        currentPermissions?.has(.membersManage) ?? false
    }

    // MARK: - Fetch Current User Permissions

    public func fetchMyPermissions() async {
        do {
            let endpoint = OrganizationEndpoint.me(orgId: orgId, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<MeResponse>.self)
            if let me = response.data {
                currentPermissions = me.permissions
                currentRole = me.role
            }
        } catch {
            // Silent fail — permissions default to empty (most restrictive)
        }
    }

    // MARK: - Fetch Members

    public func fetchMembers() async {
        isLoadingMembers = true
        errorMessage = nil

        do {
            let endpoint = OrganizationEndpoint.listMembers(orgId: orgId, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[OrganizationMemberDTO]>.self)
            members = response.data ?? []
        } catch {
            if case NetworkError.unauthorized = error {
                TokenStore.shared.clear()
                NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoadingMembers = false
    }

    // MARK: - Fetch Invites

    public func fetchInvites() async {
        guard canViewInvites else { return }
        isLoadingInvites = true

        do {
            let endpoint = OrganizationEndpoint.listInvites(orgId: orgId, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[OrganizationInviteDTO]>.self)
            invites = response.data ?? []
        } catch {
            // Silent — invites tab just stays empty
        }

        isLoadingInvites = false
    }

    // MARK: - Send Invite

    public func sendInvite() async {
        guard !inviteEmail.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Email address is required."
            return
        }

        isSendingInvite = true
        errorMessage = nil

        do {
            let payload = CreateInviteRequest(
                email: inviteEmail.trimmingCharacters(in: .whitespaces).lowercased(),
                role: inviteRole
            )
            let endpoint = OrganizationEndpoint.createInvite(orgId: orgId, payload: payload, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<OrganizationInviteDTO>.self)

            if let invite = response.data {
                invites.insert(invite, at: 0)
                showInviteSheet = false
                inviteEmail = ""
                inviteRole = .member
            }
        } catch {
            if case NetworkError.unauthorized = error {
                TokenStore.shared.clear()
                NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isSendingInvite = false
    }

    // MARK: - Update Member Role

    public func updateMemberRole(_ member: OrganizationMemberDTO, to newRole: UserRole) async {
        errorMessage = nil

        do {
            let payload = UpdateMemberRoleRequest(role: newRole)
            let endpoint = OrganizationEndpoint.updateMemberRole(
                orgId: orgId,
                memberId: member.id,
                payload: payload,
                configuration: configuration
            )
            let response = try await apiClient.request(endpoint, responseType: APIResponse<OrganizationMemberDTO>.self)

            if let updated = response.data,
               let index = members.firstIndex(where: { $0.id == updated.id }) {
                members[index] = updated
            }
            memberBeingEdited = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Remove Member

    public func removeMember(_ member: OrganizationMemberDTO) async {
        errorMessage = nil

        do {
            let endpoint = OrganizationEndpoint.removeMember(orgId: orgId, memberId: member.id, configuration: configuration)
            // DELETE returns 204 No Content — we decode an empty response
            _ = try await apiClient.request(endpoint, responseType: EmptyResponse.self)
            members.removeAll { $0.id == member.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Revoke Invite

    public func revokeInvite(_ invite: OrganizationInviteDTO) async {
        errorMessage = nil

        do {
            let endpoint = OrganizationEndpoint.revokeInvite(orgId: orgId, inviteId: invite.id, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<OrganizationInviteDTO>.self)

            if let updated = response.data,
               let index = invites.firstIndex(where: { $0.id == updated.id }) {
                invites[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load All

    public func loadAll() async {
        await fetchMyPermissions()
        await fetchMembers()
        await fetchInvites()
    }
}
