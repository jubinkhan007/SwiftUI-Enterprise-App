import SwiftUI
import SharedModels
import DesignSystem

public struct WorkspaceGovernanceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WorkspaceGovernanceViewModel

    private let colorPresets: [(String, String)] = [
        ("Indigo", "#4F46E5"),
        ("Teal", "#0D9488"),
        ("Emerald", "#059669"),
        ("Blue", "#2563EB"),
        ("Rose", "#E11D48"),
        ("Amber", "#D97706")
    ]

    private let retentionPresets: [(String, Int?)] = [
        ("30 Days", 30),
        ("90 Days", 90),
        ("1 Year", 365),
        ("Indefinite", nil)
    ]

    public init(orgId: UUID) {
        self._viewModel = StateObject(wrappedValue: WorkspaceGovernanceViewModel(orgId: orgId))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $viewModel.selectedTab) {
                    ForEach(WorkspaceGovernanceViewModel.SectionTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if let status = viewModel.statusMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.statusSuccess)
                        Text(status)
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.statusSuccess.opacity(0.12))
                }

                if let error = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.statusError)
                        Text(error)
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.statusError)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.statusError.opacity(0.10))
                }

                Form {
                    switch viewModel.selectedTab {
                    case .branding:
                        brandingSection
                    case .sso:
                        ssoSection
                    case .compliance:
                        complianceSection
                    }
                }
            }
            .navigationTitle("Branding, SSO & Compliance")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var brandingSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "paintbrush.pointed.fill")
                    .foregroundColor(AppColors.brandPrimary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.org?.name ?? "Workspace")
                        .appFont(AppTypography.headline)
                    Text("Plan Tier: \(viewModel.subscriptionTier.uppercased())")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            if !viewModel.isProOrEnterprise {
                Label("Custom branding & CNAME domains require a Pro or Enterprise plan.", systemImage: "lock.fill")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(.orange)
            }
        }

        Section("Brand Identity (Whitelabel)") {
            TextField("Logo Image URL (https://...)", text: $viewModel.logoUrl)
                #if os(iOS)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

            TextField("Brand Accent Hex (#4F46E5)", text: $viewModel.brandColorHex)
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                #endif
                .autocorrectionDisabled()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(colorPresets, id: \.1) { name, hex in
                        Button {
                            viewModel.brandColorHex = hex
                        } label: {
                            Text("\(name) (\(hex))")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    viewModel.brandColorHex.uppercased() == hex
                                        ? AppColors.brandPrimary.opacity(0.2)
                                        : Color.secondary.opacity(0.12)
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Button {
                Task { await viewModel.saveBranding() }
            } label: {
                Label("Save Brand Identity", systemImage: "checkmark.seal.fill")
            }
            .disabled(viewModel.isSaving || !viewModel.isProOrEnterprise)
        }

        Section("Custom Domain & Auto-Join Provisioning") {
            TextField("Custom Domain (e.g. tasks.acme.com)", text: $viewModel.customDomain)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

            TextField("Allowed Email Domains (e.g. acme.com, acme.co)", text: $viewModel.allowedEmailDomains)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

            Text("Users signing up with an email matching Allowed Email Domains can automatically join this workspace without manual approval.")
                .appFont(AppTypography.caption2)
                .foregroundColor(AppColors.textSecondary)

            Button {
                Task { await viewModel.saveDomainSettings() }
            } label: {
                Label("Save Domain & Auto-Join Settings", systemImage: "globe")
            }
            .disabled(viewModel.isSaving)
        }
    }

    @ViewBuilder
    private var ssoSection: some View {
        Section {
            if !viewModel.isEnterprise {
                Label("SAML 2.0 Single Sign-On requires an Enterprise subscription plan.", systemImage: "lock.shield")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(.orange)
            }
            Toggle("Enable SAML 2.0 SSO", isOn: $viewModel.ssoEnabled)
                .disabled(!viewModel.isEnterprise)
        }

        Section("Identity Provider (IdP) Configuration") {
            TextField("IdP Single Sign-On Target URL", text: $viewModel.ssoIdpUrl)
                #if os(iOS)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

            TextField("IdP Entity ID / Issuer URI", text: $viewModel.ssoEntityId)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

            VStack(alignment: .leading, spacing: 6) {
                Text("X.509 Public Certificate (PEM)")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textSecondary)
                TextEditor(text: $viewModel.ssoCertificate)
                    .font(.system(.caption2, design: .monospaced))
                    .frame(minHeight: 110)
            }

            Button {
                Task { await viewModel.saveSSOSettings() }
            } label: {
                Label("Save SAML SSO Configuration", systemImage: "key.fill")
            }
            .disabled(viewModel.isSaving || !viewModel.isEnterprise)
        }

        Section("Service Provider (SP) Endpoints") {
            LabeledContent("ACS (Consumer) URL", value: "/api/auth/sso/\(viewModel.orgId.uuidString)/acs")
                .font(.caption)
            LabeledContent("SP Entity ID", value: "urn:taskflow:sp:\(viewModel.orgId.uuidString)")
                .font(.caption)
        }
    }

    @ViewBuilder
    private var complianceSection: some View {
        Section("Automated Message Retention Policy") {
            let currentText = viewModel.retentionDays.map { "Delete messages older than \($0) days" } ?? "Retain messages indefinitely"
            LabeledContent("Current Policy", value: currentText)

            ForEach(retentionPresets, id: \.0) { label, days in
                Button {
                    Task { await viewModel.saveRetentionPolicy(days: days) }
                } label: {
                    HStack {
                        Text(label)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        if viewModel.retentionDays == days {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.brandPrimary)
                        }
                    }
                }
                .disabled(viewModel.isSaving)
            }

            Button(role: .destructive) {
                Task { await viewModel.runPurgeNow() }
            } label: {
                Label("Run Retention Purge Now", systemImage: "trash.slash.fill")
            }
            .disabled(viewModel.isSaving || viewModel.retentionDays == nil)
        }

        Section("Compliance Archive Export") {
            Picker("Export Format", selection: $viewModel.exportFormat) {
                Text("JSON Bundle (Full)").tag("json")
                Text("CSV (Messages)").tag("csv")
            }
            .pickerStyle(.segmented)

            Button {
                Task { await viewModel.generateComplianceExport() }
            } label: {
                Label("Generate Signed Compliance Export", systemImage: "arrow.down.doc.fill")
            }
            .disabled(viewModel.isSaving)

            if let desc = viewModel.lastExportDescriptor {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Export Ready (\(desc.format.uppercased()), \(desc.sizeBytes) bytes)")
                        .appFont(AppTypography.subheadline)
                        .fontWeight(.semibold)
                    Text("Expires \(desc.expiresAt.formatted(date: .omitted, time: .shortened))")
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    if let url = viewModel.fullExportDownloadURL(for: desc) {
                        Link(destination: url) {
                            Label("Download Archive", systemImage: "square.and.arrow.down")
                                .font(.caption.weight(.bold))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

