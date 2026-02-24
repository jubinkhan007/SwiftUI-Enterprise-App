import SwiftUI
import SharedModels
import DesignSystem

/// A gate view inserted between AuthGateView and the main app content.
///
/// - If the user has 0 orgs → shows "Create Workspace" onboarding.
/// - If the user has 1 org → auto-selects it and passes through.
/// - If the user has >1 orgs → shows a selection grid.
/// - If a default org from a previous session is still valid → auto-selects it.
public struct OrganizationGateView<AuthenticatedContent: View>: View {
    @StateObject private var viewModel: OrganizationGateViewModel
    private let authenticatedContent: (OrganizationDTO) -> AuthenticatedContent

    public init(
        viewModel: OrganizationGateViewModel,
        @ViewBuilder authenticatedContent: @escaping (OrganizationDTO) -> AuthenticatedContent
    ) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.authenticatedContent = authenticatedContent
    }

    public var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let org = viewModel.selectedOrg {
                authenticatedContent(org)
            } else if viewModel.organizations.isEmpty {
                emptyStateView
            } else {
                orgSelectionView
            }
        }
        .task {
            await viewModel.fetchOrganizations()
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            createOrgSheet
        }
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
                    Text("Create your first workspace to get started.")
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

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

    // MARK: - Org Selection Grid

    private var orgSelectionView: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.brandPrimary)
                    }
                }
            }
        }
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
}
