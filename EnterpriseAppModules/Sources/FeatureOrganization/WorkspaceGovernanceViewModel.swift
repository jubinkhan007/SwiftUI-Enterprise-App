import Foundation
import SharedModels
import AppNetwork

@MainActor
public final class WorkspaceGovernanceViewModel: ObservableObject {
    public enum SectionTab: String, CaseIterable, Identifiable {
        case branding = "Branding & Domains"
        case sso = "Enterprise SSO"
        case compliance = "Retention & Compliance"

        public var id: String { rawValue }
    }

    public let orgId: UUID
    private let apiClient: APIClientProtocol
    private let configuration: APIConfiguration

    @Published public var selectedTab: SectionTab = .branding
    @Published public var org: OrganizationDTO?
    @Published public var isLoading = false
    @Published public var isSaving = false
    @Published public var errorMessage: String?
    @Published public var statusMessage: String?

    // Branding & Domains
    @Published public var logoUrl: String = ""
    @Published public var brandColorHex: String = "#4F46E5"
    @Published public var customDomain: String = ""
    @Published public var allowedEmailDomains: String = ""

    // SAML SSO
    @Published public var ssoEnabled: Bool = false
    @Published public var ssoIdpUrl: String = ""
    @Published public var ssoEntityId: String = ""
    @Published public var ssoCertificate: String = ""

    // Retention & Compliance
    @Published public var retentionDays: Int? = nil
    @Published public var lastPurgedCount: Int? = nil
    @Published public var exportFormat: String = "json"
    @Published public var lastExportDescriptor: ComplianceExportDescriptorDTO? = nil

    public init(
        orgId: UUID,
        apiClient: APIClientProtocol = APIClient(),
        configuration: APIConfiguration = .current
    ) {
        self.orgId = orgId
        self.apiClient = apiClient
        self.configuration = configuration
    }

    public var subscriptionTier: String {
        (org?.subscriptionTier ?? "free").lowercased()
    }

    public var isProOrEnterprise: Bool {
        subscriptionTier == "pro" || subscriptionTier == "enterprise"
    }

    public var isEnterprise: Bool {
        subscriptionTier == "enterprise"
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let showEndpoint = OrganizationEndpoint.showOrg(id: orgId, configuration: configuration)
            let response = try await apiClient.request(showEndpoint, responseType: APIResponse<OrganizationDTO>.self)
            if let data = response.data {
                applyOrg(data)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        do {
            let retEndpoint = OrganizationEndpoint.getRetentionPolicy(orgId: orgId, configuration: configuration)
            let retResp = try await apiClient.request(retEndpoint, responseType: APIResponse<RetentionPolicyPayloadDTO>.self)
            if let policy = retResp.data {
                self.retentionDays = policy.retentionDays
            }
        } catch {
            // Fall back to org.retentionDays if already loaded
        }
    }

    private func applyOrg(_ data: OrganizationDTO) {
        self.org = data
        self.logoUrl = data.logoUrl ?? ""
        self.brandColorHex = data.brandColorHex ?? "#4F46E5"
        self.customDomain = data.customDomain ?? ""
        self.allowedEmailDomains = data.allowedEmailDomains ?? ""
        self.ssoEnabled = data.ssoEnabled ?? false
        self.ssoIdpUrl = data.ssoIdpUrl ?? ""
        self.ssoEntityId = data.ssoEntityId ?? ""
        self.ssoCertificate = data.ssoCertificate ?? ""
        self.retentionDays = data.retentionDays
    }

    public func saveBranding() async {
        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        do {
            let payload = UpdateBrandingRequest(
                logoUrl: logoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : logoUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                brandColorHex: brandColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let endpoint = OrganizationEndpoint.updateBranding(orgId: orgId, payload: payload, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<OrganizationDTO>.self)
            if let updated = response.data {
                applyOrg(updated)
            }
            statusMessage = "Custom branding saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveDomainSettings() async {
        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        do {
            let payload = UpdateDomainSettingsRequest(
                customDomain: customDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customDomain.trimmingCharacters(in: .whitespacesAndNewlines),
                allowedEmailDomains: allowedEmailDomains.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : allowedEmailDomains.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let endpoint = OrganizationEndpoint.updateDomainSettings(orgId: orgId, payload: payload, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<OrganizationDTO>.self)
            if let updated = response.data {
                applyOrg(updated)
            }
            statusMessage = "Domain & auto-join provisioning settings saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveSSOSettings() async {
        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        do {
            let payload = UpdateSSOSettingsRequest(
                ssoEnabled: ssoEnabled,
                ssoIdpUrl: ssoIdpUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ssoIdpUrl.trimmingCharacters(in: .whitespacesAndNewlines),
                ssoEntityId: ssoEntityId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ssoEntityId.trimmingCharacters(in: .whitespacesAndNewlines),
                ssoCertificate: ssoCertificate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ssoCertificate.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let endpoint = OrganizationEndpoint.updateSSOSettings(orgId: orgId, payload: payload, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<OrganizationDTO>.self)
            if let updated = response.data {
                applyOrg(updated)
            }
            statusMessage = "Enterprise SAML 2.0 SSO configuration saved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func saveRetentionPolicy(days: Int?) async {
        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        do {
            let payload = RetentionPolicyPayloadDTO(retentionDays: days)
            let endpoint = OrganizationEndpoint.updateRetentionPolicy(orgId: orgId, payload: payload, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<RetentionPolicyPayloadDTO>.self)
            self.retentionDays = response.data?.retentionDays ?? days
            statusMessage = days == nil ? "Retention set to Indefinite." : "Retention policy saved (\(days!) days)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func runPurgeNow() async {
        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        do {
            let endpoint = OrganizationEndpoint.purgeExpiredMessages(orgId: orgId, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<PurgeResultPayloadDTO>.self)
            let count = response.data?.deletedCount ?? 0
            self.lastPurgedCount = count
            statusMessage = "Purge completed: \(count) expired message(s) deleted."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func generateComplianceExport() async {
        isSaving = true
        errorMessage = nil
        statusMessage = nil
        defer { isSaving = false }

        do {
            let endpoint = OrganizationEndpoint.createComplianceExport(orgId: orgId, format: exportFormat, configuration: configuration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<ComplianceExportDescriptorDTO>.self)
            if let desc = response.data {
                self.lastExportDescriptor = desc
                statusMessage = "Compliance export (\(desc.format.uppercased()), \(desc.sizeBytes) bytes) ready."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func fullExportDownloadURL(for descriptor: ComplianceExportDescriptorDTO) -> URL? {
        let path = descriptor.downloadUrl.hasPrefix("/api")
            ? descriptor.downloadUrl
            : "/api\(descriptor.downloadUrl)"
        return URL(string: path, relativeTo: configuration.baseURL)?.absoluteURL
    }
}

