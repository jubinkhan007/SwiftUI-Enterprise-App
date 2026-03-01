import SwiftUI
import SharedModels
import DesignSystem

public struct TaskTableView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var hoveredTaskId: UUID? = nil
    private var workflowStatuses: [WorkflowStatusDTO] { viewModel.workflowBundle?.statuses ?? [] }
    
    // Column configuration (fixed widths for horizontal scrolling)
    private let selectWidth: CGFloat = 40
    private let titleWidth: CGFloat = 250
    private let statusWidth: CGFloat = 120
    private let priorityWidth: CGFloat = 120
    private let dueDateWidth: CGFloat = 100
    private let assigneeWidth: CGFloat = 100
    private let storyPointsWidth: CGFloat = 80
    private let labelsWidth: CGFloat = 150
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                tableHeader
                
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.tasks) { task in
                            NavigationLink(
                                destination: TaskDetailView(
                                    viewModel: TaskDetailViewModel(
                                        task: task,
                                        taskRepository: viewModel.taskRepository,
                                        activityRepository: viewModel.activityRepository,
                                        hierarchyRepository: viewModel.hierarchyRepository,
                                        workflowRepository: viewModel.workflowRepository,
                                        attachmentRepository: viewModel.attachmentRepository
                                    )
                                )
                            ) {
                                TableRow(
                                    task: task,
                                    workflowStatuses: workflowStatuses,
                                    isSelected: viewModel.selectedTaskIds.contains(task.id),
                                    selectionAction: { viewModel.toggleSelection(for: task.id) },
                                    updateAction: { updatedTask in
                                        Task {
                                            await updateTaskInline(originalId: task.id, updatedTask: updatedTask)
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            #if os(macOS)
                            .onHover { isHovered in
                                if isHovered {
                                    hoveredTaskId = task.id
                                } else if hoveredTaskId == task.id {
                                    hoveredTaskId = nil
                                }
                            }
                            #endif
                            .background(hoveredTaskId == task.id ? AppColors.surfaceElevated : Color.clear)
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentItem: task)
                            }
                            
                            Divider()
                        }
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                }
            }
            // Ensuring the scroll view gets enough total width
            .frame(width: selectWidth + titleWidth + statusWidth + priorityWidth + dueDateWidth + assigneeWidth + storyPointsWidth + labelsWidth + (AppSpacing.md * 9))
        }
        .background(AppColors.surfacePrimary)
    }
    
    private var tableHeader: some View {
        HStack(spacing: AppSpacing.md) {
            Text("") // Selection column
                .frame(width: selectWidth, alignment: .center)
            
            Text("Title")
                .appFont(AppTypography.subheadline)
                .fontWeight(.semibold)
                .frame(width: titleWidth, alignment: .leading)
            
            Text("Status")
                .appFont(AppTypography.subheadline)
                .fontWeight(.semibold)
                .frame(width: statusWidth, alignment: .leading)
            
            Text("Priority")
                .appFont(AppTypography.subheadline)
                .fontWeight(.semibold)
                .frame(width: priorityWidth, alignment: .leading)
            
            Text("Due Date")
                .appFont(AppTypography.subheadline)
                .fontWeight(.semibold)
                .frame(width: dueDateWidth, alignment: .leading)
            
            Text("Assignee")
                .appFont(AppTypography.subheadline)
                .fontWeight(.semibold)
                .frame(width: assigneeWidth, alignment: .leading)
                
            Text("SP")
                .appFont(AppTypography.subheadline)
                .fontWeight(.semibold)
                .frame(width: storyPointsWidth, alignment: .leading)
                
            Text("Labels")
                .appFont(AppTypography.subheadline)
                .fontWeight(.semibold)
                .frame(width: labelsWidth, alignment: .leading)
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.md)
        .background(AppColors.surfaceElevated)
        .foregroundColor(AppColors.textSecondary)
        .overlay(
            Rectangle().frame(width: nil, height: 1, alignment: .bottom).foregroundColor(AppColors.borderDefault),
            alignment: .bottom
        )
    }
    
    private func updateTaskInline(originalId: UUID, updatedTask: UpdateTaskRequest) async {
        do {
            let updated = try await viewModel.taskRepository.partialUpdateTask(id: originalId, payload: updatedTask)
            viewModel.updateTaskLocally(updated)
        } catch {
            print("Failed to inline update task: \(error)")
        }
    }
}

// MARK: - Table Row

private struct TableRow: View {
    let task: TaskItemDTO
    let workflowStatuses: [WorkflowStatusDTO]
    let isSelected: Bool
    let selectionAction: () -> Void
    let updateAction: (UpdateTaskRequest) -> Void

    @State private var showingDueDatePicker = false
    @State private var pendingDueDate: Date = Date()

    private let selectWidth: CGFloat = 40
    private let titleWidth: CGFloat = 250
    private let statusWidth: CGFloat = 120
    private let priorityWidth: CGFloat = 120
    private let dueDateWidth: CGFloat = 100
    private let assigneeWidth: CGFloat = 100
    private let storyPointsWidth: CGFloat = 80
    private let labelsWidth: CGFloat = 150

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 1. Selection
            Button(action: selectionAction) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? AppColors.brandPrimary : AppColors.borderDefault)
            }
            .buttonStyle(.borderless)
            .frame(width: selectWidth, alignment: .center)
            
            // 2. Title with Type Icon
            HStack(spacing: AppSpacing.xs) {
                TaskTypeBadge(taskType: task.taskType)
                Text(task.title)
                    .appFont(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: titleWidth, alignment: .leading)
            
            // 3. Status (Inline Menu)
            Menu {
                if !workflowStatuses.isEmpty {
                    ForEach(workflowStatuses.sorted(by: { $0.position < $1.position })) { status in
                        Button(status.name) {
                            var req = UpdateTaskRequest()
                            req.statusId = status.id
                            updateAction(req)
                        }
                    }
                } else {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        Button(status.displayName) {
                            var req = UpdateTaskRequest()
                            req.status = status
                            updateAction(req)
                        }
                    }
                }
            } label: {
                Group {
                    if !workflowStatuses.isEmpty,
                       let statusId = task.statusId,
                       let status = workflowStatuses.first(where: { $0.id == statusId }) {
                        DesignSystem.StatusBadge(.custom(color: Color(hex: status.color) ?? AppColors.brandPrimary, label: status.name))
                    } else {
                        StatusBadge(status: task.status)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .frame(width: statusWidth, alignment: .leading)
            
            // 4. Priority (Inline Menu)
            Menu {
                ForEach(TaskPriority.allCases, id: \.self) { priority in
                    Button(priority.displayName) {
                        var req = UpdateTaskRequest()
                        req.priority = priority
                        updateAction(req)
                    }
                }
            } label: {
                PriorityBadge(priority: task.priority)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .frame(width: priorityWidth, alignment: .leading)
            
            // 5. Due Date — compact DatePicker popover
            Button {
                pendingDueDate = task.dueDate ?? Date()
                showingDueDatePicker = true
            } label: {
                Text(task.dueDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Set date")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(task.dueDate == nil ? AppColors.textSecondary : AppColors.textPrimary)
            }
            .buttonStyle(.borderless)
            .frame(width: dueDateWidth, alignment: .leading)
            .popover(isPresented: $showingDueDatePicker) {
                VStack(spacing: AppSpacing.md) {
                    DatePicker("Due Date", selection: $pendingDueDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                    HStack {
                        if task.dueDate != nil {
                            Button("Clear") {
                                var req = UpdateTaskRequest()
                                req.dueDate = nil
                                updateAction(req)
                                showingDueDatePicker = false
                            }
                            .foregroundColor(AppColors.statusError)
                        }
                        Spacer()
                        Button("Done") {
                            var req = UpdateTaskRequest()
                            req.dueDate = pendingDueDate
                            updateAction(req)
                            showingDueDatePicker = false
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.brandPrimary)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .frame(minWidth: 320)
            }
            
            // 6. Assignee
            HStack {
                if task.assigneeId != nil {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(AppColors.brandPrimary)
                } else {
                    Image(systemName: "person.circle")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .frame(width: assigneeWidth, alignment: .leading)
            
            // 7. Story Points
            Text(task.storyPoints != nil ? "\(task.storyPoints!)" : "-")
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: storyPointsWidth, alignment: .leading)
            
            // 8. Labels
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    if let labels = task.labels, !labels.isEmpty {
                        ForEach(labels, id: \.self) { label in
                            LabelPill(label: label)
                        }
                    } else {
                        Text("-").foregroundColor(AppColors.borderDefault)
                    }
                }
            }
            .frame(width: labelsWidth, alignment: .leading)
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.md)
    }
}
