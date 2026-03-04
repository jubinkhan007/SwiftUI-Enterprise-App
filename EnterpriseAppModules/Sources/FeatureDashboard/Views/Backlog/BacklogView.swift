import SwiftUI
import DesignSystem
import Domain
import SharedModels

public struct BacklogView: View {
    @StateObject private var viewModel: BacklogViewModel
    @State private var editMode: EditMode = .inactive

    public init(
        projectId: UUID,
        taskRepository: TaskRepositoryProtocol,
        analyticsRepository: AnalyticsRepositoryProtocol
    ) {
        _viewModel = StateObject(
            wrappedValue: BacklogViewModel(
                projectId: projectId,
                taskRepository: taskRepository,
                analyticsRepository: analyticsRepository
            )
        )
    }

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.backlog.isEmpty && viewModel.sprints.isEmpty {
                skeletonList
            } else if let error = viewModel.error, viewModel.backlog.isEmpty && viewModel.sprints.isEmpty {
                ErrorStateView(error: error) {
                    Task { await viewModel.refresh() }
                }
            } else {
                contentList
            }
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .task {
            await viewModel.refresh()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var contentList: some View {
        List {
            Section(header: backlogHeader) {
                if viewModel.backlog.isEmpty {
                    Text("No backlog items")
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    ForEach(viewModel.backlog) { task in
                        taskRow(task)
                    }
                    .onMove { from, to in
                        viewModel.moveBacklog(fromOffsets: from, toOffset: to)
                    }
                }
            }

            ForEach(viewModel.sprints) { sprint in
                Section(header: sprintHeader(sprint)) {
                    let issues = viewModel.sprintIssues[sprint.id] ?? []
                    if issues.isEmpty {
                        Text(sprint.status.isClosedLike ? "No issues (closed)" : "No issues")
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        ForEach(issues) { task in
                            taskRow(task)
                        }
                        .onMove { from, to in
                            guard !sprint.status.isClosedLike else { return }
                            viewModel.moveSprintIssues(sprintId: sprint.id, fromOffsets: from, toOffset: to)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var backlogHeader: some View {
        HStack {
            Text("Backlog")
                .appFont(AppTypography.headline)
            Spacer()
            Text("Drag here to unassign")
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textTertiary)
        }
        .dropDestination(for: String.self) { items, _ in
            Task { _ = await viewModel.handleDrop(itemIds: items, toSprintId: nil) }
            return true
        }
    }

    private func sprintHeader(_ sprint: SprintDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(sprint.statusLabel) • \(sprint.name)")
                    .appFont(AppTypography.headline)
                Spacer()
                if sprint.status.isClosedLike {
                    Text("Closed")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            let points = viewModel.pointsForSprint(sprint.id)
            if let cap = points.capacity, cap > 0 {
                let over = points.assigned > cap
                ProgressView(value: min(points.assigned / cap, 1.0)) {
                    HStack {
                        Text(String(format: "%.0f/%.0f pts", points.assigned, cap))
                            .appFont(AppTypography.caption1)
                            .foregroundColor(over ? AppColors.statusError : AppColors.textSecondary)
                        Spacer()
                    }
                }
                .tint(over ? AppColors.statusError : AppColors.brandPrimary)
            } else {
                Text(String(format: "%.0f pts assigned", points.assigned))
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard !sprint.status.isClosedLike else { return false }
            Task { _ = await viewModel.handleDrop(itemIds: items, toSprintId: sprint.id) }
            return true
        }
    }

    private func taskRow(_ task: TaskItemDTO) -> some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let key = task.issueKey {
                        Text(key)
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Text(task.title)
                        .appFont(AppTypography.subheadline)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                }

                if let sp = task.storyPoints {
                    Text("\(sp) pts")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Spacer()
            Image(systemName: task.taskType.iconName)
                .foregroundColor(AppColors.brandPrimary)
        }
        .contentShape(Rectangle())
        .draggable(task.id.uuidString)
    }

    private var skeletonList: some View {
        List {
            Section(header: Text("Backlog")) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.surfaceElevated)
                            .frame(height: 18)
                    }
                    .redacted(reason: .placeholder)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private extension SprintDTO {
    var statusLabel: String {
        switch status {
        case .planned: return "Planned"
        case .active: return "Active"
        case .closed, .completed: return "Closed"
        }
    }
}

