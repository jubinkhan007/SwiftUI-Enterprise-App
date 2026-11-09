import SwiftUI
import DesignSystem
import Domain
import SharedModels

public struct BacklogView: View {
    @StateObject private var viewModel: BacklogViewModel
    @State private var showingCreateSprint = false
#if os(iOS)
    @State private var editMode: EditMode = .inactive
#endif

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
#if os(iOS)
        .environment(\.editMode, $editMode)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingCreateSprint = true
                } label: {
                    Label("New Sprint", systemImage: "plus.circle.fill")
                }
                .accessibilityIdentifier("backlog.newSprintButton")
                EditButton()
            }
        }
#else
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSprint = true
                } label: {
                    Label("New Sprint", systemImage: "plus.circle.fill")
                }
            }
        }
#endif
        .sheet(isPresented: $showingCreateSprint) {
            BacklogCreateSprintSheet { name, startDate, endDate, capacity in
                Task {
                    await viewModel.createSprint(
                        name: name,
                        startDate: startDate,
                        endDate: endDate,
                        capacity: capacity
                    )
                }
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
#if os(iOS)
        .listStyle(.insetGrouped)
#else
        .listStyle(.inset)
#endif
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
        let stats = viewModel.sprintStats(sprint.id)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(sprint.statusLabel) • \(sprint.name)")
                    .appFont(AppTypography.headline)
                Spacer()
                if sprint.status == .planned {
                    Button {
                        Task { await viewModel.updateSprintStatus(sprintId: sprint.id, status: .active) }
                    } label: {
                        Label("Start Sprint", systemImage: "play.fill")
                            .appFont(AppTypography.caption1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.brandPrimary.opacity(0.15))
                            .foregroundColor(AppColors.brandPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if sprint.status == .active {
                    Menu {
                        Button {
                            Task {
                                await viewModel.updateSprintStatus(
                                    sprintId: sprint.id,
                                    status: .completed,
                                    rolloverUncompletedTo: "next_sprint"
                                )
                            }
                        } label: {
                            Label("Complete & Rollover to Next Sprint", systemImage: "arrow.right.circle")
                        }
                        Button {
                            Task {
                                await viewModel.updateSprintStatus(
                                    sprintId: sprint.id,
                                    status: .completed,
                                    rolloverUncompletedTo: "backlog"
                                )
                            }
                        } label: {
                            Label("Complete & Return Open to Backlog", systemImage: "tray.and.arrow.down")
                        }
                        Button {
                            Task {
                                await viewModel.updateSprintStatus(sprintId: sprint.id, status: .completed)
                            }
                        } label: {
                            Label("Complete Sprint As-Is", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Label("Complete", systemImage: "checkmark.circle.fill")
                            .appFont(AppTypography.caption1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.statusSuccess.opacity(0.15))
                            .foregroundColor(AppColors.statusSuccess)
                            .clipShape(Capsule())
                    }
                } else if sprint.status.isClosedLike {
                    Text("Closed")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            HStack(spacing: 8) {
                Text("\(sprint.startDate.formatted(date: .abbreviated, time: .omitted)) – \(sprint.endDate.formatted(date: .abbreviated, time: .omitted))")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
                Spacer()
                Text("\(stats.completedCount)/\(stats.totalCount) done")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            if let cap = stats.capacity, cap > 0 {
                let over = stats.assignedPoints > cap
                ProgressView(value: min(stats.assignedPoints / cap, 1.0)) {
                    HStack {
                        Text(String(format: "%.0f done • %.0f/%.0f pts capacity", stats.completedPoints, stats.assignedPoints, cap))
                            .appFont(AppTypography.caption1)
                            .foregroundColor(over ? AppColors.statusError : AppColors.textSecondary)
                        Spacer()
                    }
                }
                .tint(over ? AppColors.statusError : AppColors.brandPrimary)
            } else {
                Text(String(format: "%.0f done / %.0f pts assigned", stats.completedPoints, stats.assignedPoints))
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

                HStack(spacing: 8) {
                    Text(task.status.displayName)
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                    if let sp = task.storyPoints {
                        Text("\(sp) pts")
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            Spacer()
            Image(systemName: task.taskType.iconName)
                .foregroundColor(AppColors.brandPrimary)
        }
        .contentShape(Rectangle())
        .draggable(task.id.uuidString)
        .contextMenu {
            let openSprints = viewModel.sprints.filter { !$0.status.isClosedLike }
            if !openSprints.isEmpty {
                Menu("Assign to Sprint") {
                    ForEach(openSprints) { targetSprint in
                        Button {
                            Task { await viewModel.assignTask(task, toSprintId: targetSprint.id) }
                        } label: {
                            Label("\(targetSprint.name) (\(targetSprint.statusLabel))", systemImage: "flag")
                        }
                    }
                }
            }
            if task.sprintId != nil {
                Button {
                    Task { await viewModel.assignTask(task, toSprintId: nil) }
                } label: {
                    Label("Move to Product Backlog", systemImage: "tray.and.arrow.down")
                }
            }
        }
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
#if os(iOS)
        .listStyle(.insetGrouped)
#else
        .listStyle(.inset)
#endif
    }
}

private struct BacklogCreateSprintSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var capacityText: String = "20"

    let onCreate: (String, Date, Date, Double?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Iteration Details") {
                    TextField("Sprint Name (e.g. Sprint 15)", text: $name)
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                Section("Capacity Planning") {
                    TextField("Story Points Capacity", text: $capacityText)
                    #if os(iOS)
                        .keyboardType(.decimalPad)
                    #endif
                }
            }
            .navigationTitle("Create Sprint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let cap = Double(capacityText.trimmingCharacters(in: .whitespacesAndNewlines))
                        onCreate(name, startDate, endDate, cap)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || endDate < startDate)
                }
            }
        }
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
