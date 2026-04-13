import Foundation
import SharedModels
import AppNetwork

@MainActor
public final class JoinWorkspaceViewModel: ObservableObject {
    // MARK: - Published State

    @Published public var searchQuery = ""
    @Published public var searchResults: [OrganizationDTO] = []
    @Published public var isSearching = false
    @Published public var requestedOrgIds = Set<UUID>()
    @Published public var isRequesting = false
    @Published public var inviteIdToAccept = ""
    @Published public var isJoining = false
    @Published public var errorMessage: String? = nil

    private let apiClient: APIClientProtocol
    private let configuration: APIConfiguration
    let onJoined: (OrganizationMemberDTO) -> Void

    public init(
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .current,
        onJoined: @escaping (OrganizationMemberDTO) -> Void
    ) {
        self.apiClient = apiClient
        self.configuration = configuration
        self.onJoined = onJoined
    }

    // MARK: - Search

    public func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let endpoint = OrganizationEndpoint.searchOrganizations(query: query, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[OrganizationDTO]>.self)
            searchResults = response.data ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Request to Join

    public func requestToJoin(orgId: UUID) async {
        isRequesting = true
        errorMessage = nil
        defer { isRequesting = false }
        do {
            let endpoint = OrganizationEndpoint.requestToJoin(orgId: orgId, configuration: configuration)
            _ = try await apiClient.request(endpoint, responseType: APIResponse<OrganizationJoinRequestDTO>.self)
            requestedOrgIds.insert(orgId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Accept Invite

    public func acceptInvite() async {
        let trimmed = inviteIdToAccept.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let inviteId = UUID(uuidString: trimmed) else {
            errorMessage = "Invite ID must be a valid UUID."
            return
        }
        isJoining = true
        errorMessage = nil
        defer { isJoining = false }
        do {
            let endpoint = OrganizationEndpoint.acceptInvite(inviteId: inviteId, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<OrganizationMemberDTO>.self)
            if let membership = response.data {
                OrganizationContext.shared.orgId = membership.orgId
                inviteIdToAccept = ""
                onJoined(membership)
            } else {
                errorMessage = "Failed to accept invite."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
