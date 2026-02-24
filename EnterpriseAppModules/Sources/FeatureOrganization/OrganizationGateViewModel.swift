import Foundation
import SharedModels
import AppNetwork
import Combine

/// ViewModel for OrganizationGateView.
/// Fetches the user's orgs, resolves their default workspace, and manages selection state.
@MainActor
public final class OrganizationGateViewModel: ObservableObject {
    // MARK: - Published State

    @Published public var organizations: [OrganizationDTO] = []
    @Published public var selectedOrg: OrganizationDTO? = nil
    @Published public var isLoading = true
    @Published public var errorMessage: String? = nil
    @Published public var showCreateSheet = false
    @Published public var newOrgName = ""
    @Published public var newOrgDescription = ""
    @Published public var isCreating = false

    private let apiClient: APIClientProtocol
    private let configuration: APIConfiguration

    public init(apiClient: APIClientProtocol = APIClient(), configuration: APIConfiguration = .localVapor) {
        self.apiClient = apiClient
        self.configuration = configuration
    }

    // MARK: - Fetch Organizations

    public func fetchOrganizations() async {
        isLoading = true
        errorMessage = nil

        do {
            let endpoint = OrganizationEndpoint.me(orgId: nil, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<MeResponse>.self)

            guard let me = response.data else {
                errorMessage = "Failed to load workspaces."
                isLoading = false
                return
            }

            organizations = me.organizations

            // Auto-selection logic
            if organizations.isEmpty {
                // No orgs — show create flow
                selectedOrg = nil
            } else if organizations.count == 1 {
                // Auto-select the only org
                selectOrganization(organizations[0])
            } else if let savedOrgId = OrganizationContext.shared.orgId,
                      let savedOrg = organizations.first(where: { $0.id == savedOrgId }) {
                // Restore last-used org
                selectOrganization(savedOrg)
            }
            // else: multiple orgs, no saved default — user must pick
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Select Organization

    public func selectOrganization(_ org: OrganizationDTO) {
        // Cancel old org requests
        if let oldOrgId = OrganizationContext.shared.orgId, oldOrgId != org.id {
            RequestRegistry.shared.cancelAll(for: oldOrgId)
        }

        OrganizationContext.shared.orgId = org.id
        selectedOrg = org
    }

    // MARK: - Create Organization

    public func createOrganization() async {
        guard !newOrgName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Organization name is required."
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            let payload = CreateOrganizationRequest(
                name: newOrgName.trimmingCharacters(in: .whitespaces),
                description: newOrgDescription.isEmpty ? nil : newOrgDescription.trimmingCharacters(in: .whitespaces)
            )
            let endpoint = OrganizationEndpoint.createOrg(payload: payload, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<OrganizationDTO>.self)

            if let org = response.data {
                organizations.append(org)
                selectOrganization(org)
                showCreateSheet = false
                newOrgName = ""
                newOrgDescription = ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isCreating = false
    }

    // MARK: - Switch Organization (clears state)

    public func switchOrganization(to org: OrganizationDTO) {
        selectOrganization(org)
    }
}
