import SwiftUI
import SharedModels
import DesignSystem
import Domain
import AppData
import AppNetwork

/// A gate view inserted between AuthGateView and the main app content.
///
/// - If the user has 0 orgs → shows "Create Workspace" onboarding.
/// - If the user has 1 org → auto-selects it and passes through.
/// - If the user has >1 orgs → shows a selection grid.
/// - If a default org from a previous session is still valid → auto-selects it.
public struct OrganizationGateView<AuthenticatedContent: View>: View {
    @StateObject private var viewModel: OrganizationGateViewModel
    private let authenticatedContent: (OrganizationDTO) -> AuthenticatedContent
    private let session: Domain.AuthSession
    private let authManager: AppData.AuthManager

    public init(
        session: Domain.AuthSession,
        authManager: AppData.AuthManager,
        viewModel: OrganizationGateViewModel,
        @ViewBuilder authenticatedContent: @escaping (OrganizationDTO) -> AuthenticatedContent
    ) {
        self.session = session
        self.authManager = authManager
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.authenticatedContent = authenticatedContent
    }

    public var body: some View {
        Group {
            if let org = viewModel.selectedOrg {
                authenticatedContent(org)
            } else {
                gatedNavigation
            }
        }
        .task { await viewModel.fetchOrganizations() }
        .sheet(isPresented: $viewModel.showCreateSheet) { createOrgSheet }
        .sheet(isPresented: $viewModel.showJoinSheet) { joinOrgSheet }
    }

    private var gatedNavigation: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.organizations.isEmpty {
                    emptyStateView
                } else {
                    orgSelectionView
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { accountDrawer }
            }
        }
    }

    private var accountDrawer: some View {
        Menu {
            Text("Signed in as \(session.user.displayName)")
            Divider()

            Button {
                viewModel.showJoinSheet = true
            } label: {
                Label("Join Workspace", systemImage: "person.badge.plus")
            }

            Button {
                viewModel.showCreateSheet = true
            } label: {
                Label("Create Workspace", systemImage: "plus")
            }

            Divider()

            Button("Sign Out", role: .destructive) {
                OrganizationContext.shared.clear()
                authManager.signOut()
            }
        } label: {
            Image(systemName: "person.circle")
                .font(.title3)
                .foregroundColor(AppColors.textPrimary)
        }
        .accessibilityLabel("Account")
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(AppColors.brandPrimary)
                Text("Loading your workspaces…")
                    .appFont(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // MARK: - Empty State (No Orgs)

    private var emptyStateView: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: AppSpacing.xl) {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.brandPrimary, AppColors.brandPrimary.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: AppSpacing.sm) {
                    Text("Welcome!")
                        .appFont(AppTypography.largeTitle)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Join an existing workspace or create one to get started.")
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if !viewModel.pendingInvites.isEmpty {
                    pendingInvitesSection
                        .frame(maxWidth: 360)
                }

                AppButton("Join Workspace", variant: .secondary, leadingIcon: "person.badge.plus") {
                    viewModel.showJoinSheet = true
                }
                .frame(maxWidth: 280)

                AppButton("Create Workspace", variant: .primary) {
                    viewModel.showCreateSheet = true
                }
                .frame(maxWidth: 280)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.statusError)
                }
            }
            .padding(AppSpacing.xl)
        }
    }

    private var pendingInvitesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Invitations")
                .appFont(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.pendingInvites) { invite in
                    HStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(invite.orgName)
                                .appFont(AppTypography.body.weight(.semibold))
                                .foregroundColor(AppColors.textPrimary)

                            Text("\(invite.role.displayName) • Expires \(expiryText(invite.expiresAt))")
                                .appFont(AppTypography.caption1)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        AppButton(
                            viewModel.isJoining ? "Joining…" : "Accept",
                            variant: .primary,
                            isEnabled: !viewModel.isJoining,
                            isLoading: viewModel.isJoining
                        ) {
                            Task { await viewModel.acceptInvite(inviteId: invite.id) }
                        }
                        .frame(width: 120)
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.surfaceElevated)
                    .cornerRadius(AppRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func expiryText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Org Selection Grid

    private var orgSelectionView: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Text("Select a Workspace")
                        .appFont(AppTypography.title3)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
                        ForEach(viewModel.organizations) { org in
                            orgCard(org)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Workspaces")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    private func orgCard(_ org: OrganizationDTO) -> some View {
        Button {
            viewModel.selectOrganization(org)
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Image(systemName: "building.2")
                        .font(.title2)
                        .foregroundColor(AppColors.brandPrimary)
                    Spacer()
                }

                Text(org.name)
                    .appFont(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let desc = org.description, !desc.isEmpty {
                    Text(desc)
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if let count = org.memberCount {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.caption)
                        Text("\(count) member\(count == 1 ? "" : "s")")
                            .appFont(AppTypography.caption1)
                    }
                    .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
            .background(AppColors.surfaceElevated)
            .cornerRadius(AppRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            )
        }
    }

    // MARK: - Create Org Sheet

    private var createOrgSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary.ignoresSafeArea()

                VStack(spacing: AppSpacing.lg) {
                    AppTextField("Workspace Name", text: $viewModel.newOrgName)
                    AppTextField("Description (optional)", text: $viewModel.newOrgDescription)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.statusError)
                    }

                    AppButton(
                        viewModel.isCreating ? "Creating…" : "Create Workspace",
                        variant: .primary,
                        isLoading: viewModel.isCreating
                    ) {
                        Task { await viewModel.createOrganization() }
                    }
                    .disabled(viewModel.newOrgName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isCreating)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New Workspace")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showCreateSheet = false
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Join Org Sheet

    private var joinOrgSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary.ignoresSafeArea()

                VStack(spacing: AppSpacing.lg) {
                    if !viewModel.pendingInvites.isEmpty {
                        pendingInvitesSection
                    }

                    AppTextField(
                        "Invite ID",
                        text: $viewModel.inviteIdToAccept,
                        placeholder: "Paste the invite UUID"
                    )

                    Text("Ask a workspace admin to share an invite ID with you.")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.statusError)
                    }

                    AppButton(
                        viewModel.isJoining ? "Joining…" : "Join Workspace",
                        variant: .primary,
                        isLoading: viewModel.isJoining
                    ) {
                        Task { await viewModel.acceptInvite() }
                    }
                    .disabled(viewModel.inviteIdToAccept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isJoining)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Join Workspace")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.errorMessage = nil
                        viewModel.showJoinSheet = false
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
            .task {
                await viewModel.fetchPendingInvites()
            }
        }
    }
}
