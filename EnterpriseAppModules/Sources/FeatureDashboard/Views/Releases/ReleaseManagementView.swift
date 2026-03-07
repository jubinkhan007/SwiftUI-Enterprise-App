import SwiftUI
import SharedModels
import DesignSystem
import AppNetwork

public struct ReleaseManagementView: View {
    @StateObject private var viewModel: ReleaseManagementViewModel

    public init(projectId: UUID) {
        _viewModel = StateObject(wrappedValue: ReleaseManagementViewModel(projectId: projectId))
    }

    public var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if viewModel.isLoading && viewModel.releases.isEmpty {
                ProgressView().padding()
            } else if let error = viewModel.error, viewModel.releases.isEmpty {
                VStack(spacing: 12) {
                    Text("Couldn’t load releases.")
                        .appFont(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text(error.localizedDescription)
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await viewModel.refresh() } }
                        .appFont(AppTypography.headline)
                        .foregroundColor(AppColors.brandPrimary)
                }
                .padding()
            } else {
                List {
                    if viewModel.releases.isEmpty {
                        Text("No releases yet.")
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        ForEach(viewModel.releases) { release in
                            NavigationLink {
                                ReleaseDetailView(release: release)
                            } label: {
                                ReleaseRow(
                                    release: release,
                                    progress: viewModel.progressByReleaseId[release.id]
                                )
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Releases")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }
}

private struct ReleaseRow: View {
    let release: ReleaseDTO
    let progress: ReleaseProgressDTO?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(release.name)
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(release.status.rawValue.capitalized)
                    .appFont(AppTypography.caption2)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            if let progress {
                let issuesProgress = progress.totalIssues > 0 ? Double(progress.doneIssues) / Double(progress.totalIssues) : 0
                ProgressView(value: issuesProgress) {
                    HStack {
                        Text("\(progress.doneIssues)/\(progress.totalIssues) issues")
                        Spacer()
                        Text("\(progress.donePoints)/\(max(progress.totalPoints, 0)) pts")
                    }
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textSecondary)
                }
                .tint(AppColors.brandPrimary)

                HStack(spacing: 12) {
                    if progress.criticalBugCount > 0 {
                        Text("Critical bugs: \(progress.criticalBugCount)")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.statusError)
                    } else if progress.bugCount > 0 {
                        Text("Bugs: \(progress.bugCount)")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if release.isLocked {
                        Text("Locked")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            } else {
                Text("Loading progress…")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch release.status {
        case .unreleased: return AppColors.brandPrimary
        case .released: return AppColors.statusSuccess
        case .archived: return AppColors.textTertiary
        }
    }
}
