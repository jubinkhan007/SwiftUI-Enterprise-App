import Foundation
import SwiftUI
import Combine
import SharedModels
import AppNetwork

@MainActor
public final class BillingSettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var org: OrganizationDTO?
    @Published public var currentTier: String = "free"
    @Published public var memberCount: Int = 1
    @Published public var subscriptionStatus: String = "active"
    @Published public var isLoading: Bool = false
    @Published public var isRedirecting: Bool = false
    @Published public var redirectURL: URL? = nil
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil

    public let orgId: UUID
    private let apiClient: APIClientProtocol
    private let configuration: APIConfiguration

    public init(
        orgId: UUID,
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .current
    ) {
        self.orgId = orgId
        self.apiClient = apiClient
        self.configuration = configuration
    }

    // MARK: - Computed Helpers

    public var isPro: Bool {
        let t = currentTier.lowercased()
        return t == "pro" || t == "enterprise"
    }

    public var isEnterprise: Bool {
        currentTier.lowercased() == "enterprise"
    }

    public var isFree: Bool {
        !isPro && !isEnterprise
    }

    public var memberLimit: Int {
        if isPro || isEnterprise {
            return 100
        }
        return 5
    }

    public var memberQuotaFraction: Double {
        if isPro || isEnterprise {
            return min(Double(memberCount) / 100.0, 1.0)
        }
        return min(Double(memberCount) / 5.0, 1.0)
    }

    // MARK: - Actions

    public func loadBillingInfo() async {
        isLoading = true
        errorMessage = nil
        do {
            let endpoint = OrganizationEndpoint.showOrg(id: orgId, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<OrganizationDTO>.self)
            if let org = response.data {
                self.org = org
                self.currentTier = org.subscriptionTier?.lowercased() ?? "free"
                self.memberCount = org.memberCount ?? 1
                self.subscriptionStatus = org.subscriptionStatus ?? "active"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func upgradeToPro() async -> URL? {
        isRedirecting = true
        errorMessage = nil
        defer { isRedirecting = false }

        do {
            let endpoint = OrganizationEndpoint.billingCheckout(orgId: orgId, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<BillingRedirectDTO>.self)
            if let redirect = response.data, let url = URL(string: redirect.url) {
                self.redirectURL = url
                return url
            } else {
                errorMessage = "Invalid redirect URL received from server."
                return nil
            }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func manageSubscription() async -> URL? {
        isRedirecting = true
        errorMessage = nil
        defer { isRedirecting = false }

        do {
            let endpoint = OrganizationEndpoint.billingPortal(orgId: orgId, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<BillingRedirectDTO>.self)
            if let redirect = response.data, let url = URL(string: redirect.url) {
                self.redirectURL = url
                return url
            } else {
                errorMessage = "Invalid portal URL received from server."
                return nil
            }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
