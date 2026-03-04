import SwiftUI
import SharedModels
import Domain
import DesignSystem

public struct EpicDetailDashboardView: View {
    @StateObject private var viewModel: EpicDetailDashboardViewModel

    private let taskRepository: TaskRepositoryProtocol
    private let activityRepository: TaskActivityRepositoryProtocol
    private let hierarchyRepository: HierarchyRepositoryProtocol
    private let workflowRepository: WorkflowRepositoryProtocol
    private let attachmentRepository: AttachmentRepositoryProtocol

    public init(
        epic: TaskItemDTO,
        taskRepository: TaskRepositoryProtocol,
        activityRepository: TaskActivityRepositoryProtocol,
        hierarchyRepository: HierarchyRepositoryProtocol,
        workflowRepository: WorkflowRepositoryProtocol,
        attachmentRepository: AttachmentRepositoryProtocol
    ) {
        _viewModel = StateObject(wrappedValue: EpicDetailDashboardViewModel(epic: epic))
        self.taskRepository = taskRepository
        self.activityRepository = activityRepository
        self.hierarchyRepository = hierarchyRepository
        self.workflowRepository = workflowRepository
        self.attachmentRepository = attachmentRepository
    }

    public var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if viewModel.isLoading && viewModel.childIssues.isEmpty {
                ProgressView().padding()
            } else if let error = viewModel.error, viewModel.childIssues.isEmpty {
                VStack(spacing: 12) {
                    Text("Couldn’t load epic dashboard.")
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
                    progressSection
                    childrenSection
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(viewModel.epic.issueKey ?? "Epic")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }

    private var progressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(viewModel.epic.title)
                    .appFont(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)

                epicProgressRow(
                    title: "Points",
                    done: viewModel.epic.epicCompletedPoints ?? 0,
                    total: viewModel.epic.epicTotalPoints ?? 0
                )
                epicProgressRow(
                    title: "Issues",
                    done: viewModel.epic.epicChildrenDoneCount ?? 0,
                    total: viewModel.epic.epicChildrenCount ?? viewModel.childIssues.count
                )
            }
            .padding(.vertical, AppSpacing.sm)
        } header: {
            Text("Progress")
        }
    }

    private func epicProgressRow(title: String, done: Int, total: Int) -> some View {
        let progress: Double = total > 0 ? Double(done) / Double(total) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(total > 0 ? "\(done)/\(total)" : "—")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textSecondary)
            }
            ProgressView(value: progress)
                .tint(AppColors.brandPrimary)
        }
    }

    private var childrenSection: some View {
        Section {
            if viewModel.childIssues.isEmpty {
                Text("No child issues yet.")
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(viewModel.childIssues) { child in
                    NavigationLink {
                        TaskDetailView(
                            viewModel: TaskDetailViewModel(
                                task: child,
                                taskRepository: taskRepository,
                                activityRepository: activityRepository,
                                hierarchyRepository: hierarchyRepository,
                                workflowRepository: workflowRepository,
                                attachmentRepository: attachmentRepository
                            )
                        )
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    if let key = child.issueKey {
                                        Text(key)
                                            .appFont(AppTypography.caption1)
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                    Text(child.title)
                                        .appFont(AppTypography.subheadline)
                                        .foregroundColor(AppColors.textPrimary)
                                        .lineLimit(1)
                                }
                                Text(child.status.displayName)
                                    .appFont(AppTypography.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            if let sp = child.storyPoints {
                                Text("\(sp) pts")
                                    .appFont(AppTypography.caption1)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Child Issues")
        }
    }
}
