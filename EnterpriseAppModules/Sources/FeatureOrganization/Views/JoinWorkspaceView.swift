import SwiftUI
import SharedModels
import DesignSystem
import AppNetwork

/// A searchable sheet for discovering and joining workspaces.
/// Surfaces two paths: (1) search-and-request for discoverable orgs,
/// and (2) a legacy invite-code field for private invites.
public struct JoinWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: JoinWorkspaceViewModel

    public init(viewModel: JoinWorkspaceViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            List {
                searchResultsSection
                inviteCodeSection
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle("Join Workspace")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $viewModel.searchQuery, prompt: "Search workspaces by name")
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .onChange(of: viewModel.searchQuery) { _, query in
                if query.isEmpty { viewModel.searchResults = [] }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsSection: some View {
        if viewModel.isSearching {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.brandPrimary)
                    Spacer()
                }
            }
        } else if !viewModel.searchResults.isEmpty {
            Section("Workspaces") {
                ForEach(viewModel.searchResults) { org in
                    orgResultRow(org)
                }
            }
        } else if !viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isSearching {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.textTertiary)
                        Text("No workspaces found")
                            .appFont(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.vertical, AppSpacing.lg)
                    Spacer()
                }
            }
        }
    }

    private func orgResultRow(_ org: OrganizationDTO) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(AppColors.brandPrimary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(String(org.name.prefix(1)).uppercased())
                    .appFont(AppTypography.headline)
                    .foregroundColor(AppColors.brandPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(org.name)
                    .appFont(AppTypography.body.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)

                if let description = org.description, !description.isEmpty {
                    Text(description)
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                if let count = org.memberCount {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.caption2)
                        Text("\(count) member\(count == 1 ? "" : "s")")
                            .appFont(AppTypography.caption1)
                    }
                    .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            requestButton(for: org)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func requestButton(for org: OrganizationDTO) -> some View {
        let alreadyRequested = viewModel.requestedOrgIds.contains(org.id)

        if alreadyRequested {
            Label("Requested", systemImage: "checkmark.circle.fill")
                .appFont(AppTypography.caption1.weight(.semibold))
                .foregroundColor(AppColors.statusSuccess)
                .labelStyle(.titleAndIcon)
        } else {
            Button {
                Task { await viewModel.requestToJoin(orgId: org.id) }
            } label: {
                Text("Request")
                    .appFont(AppTypography.caption1.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.brandPrimary)
                    .cornerRadius(AppRadius.small)
            }
            .disabled(viewModel.isRequesting)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Invite Code

    private var inviteCodeSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                TextField("Paste invite UUID", text: $viewModel.inviteIdToAccept)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                Button {
                    Task { await viewModel.acceptInvite() }
                } label: {
                    if viewModel.isJoining {
                        HStack {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                            Text("Joining…")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Join via Invite Code")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.brandPrimary)
                .disabled(viewModel.inviteIdToAccept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isJoining)
            }
            .padding(.vertical, AppSpacing.xs)
        } header: {
            Text("Have an Invite Code?")
        } footer: {
            Text("Ask a workspace admin to share an invite ID with you.")
                .appFont(AppTypography.caption1)
        }
    }
}
