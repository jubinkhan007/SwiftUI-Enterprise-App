import SwiftUI
import DesignSystem
import SharedModels

public struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateTaskViewModel
    private let hierarchy: [HierarchyTreeDTO.SpaceNode]

    let onTaskCreated: () -> Void

    private struct ListOption: Identifiable, Hashable {
        let id: UUID
        let title: String
    }

    public init(viewModel: CreateTaskViewModel, onTaskCreated: @escaping () -> Void) {
        self.hierarchy = []
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onTaskCreated = onTaskCreated
    }

    public init(
        viewModel: CreateTaskViewModel,
        hierarchy: [HierarchyTreeDTO.SpaceNode],
        onTaskCreated: @escaping () -> Void
    ) {
        self.hierarchy = hierarchy
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onTaskCreated = onTaskCreated
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundSecondary.ignoresSafeArea()
                ScrollView {
                    formContent
                        .padding()
                }
            }
            .navigationTitle("New Task")
            .toolbar { toolbarContent }
        }
        .onChange(of: viewModel.isSuccess) {
            if viewModel.isSuccess {
                onTaskCreated()
                dismiss()
            }
        }
        .task(id: listOptions.first?.id) {
            if viewModel.listId == nil, let first = listOptions.first {
                viewModel.listId = first.id
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .foregroundColor(AppColors.brandPrimary)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button {
                Task { await viewModel.saveTask() }
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Text("Create").fontWeight(.bold)
                }
            }
            .foregroundColor(viewModel.isValid && !viewModel.isSaving ? AppColors.brandPrimary : AppColors.textTertiary)
            .disabled(!viewModel.isValid || viewModel.isSaving)
        }
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(spacing: AppSpacing.lg) {
            pickerCard(title: "List (Required)") {
                if listOptions.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("No lists available")
                            .appFont(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Go to Workspace and create/select a list, then come back.")
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.sm)
                    .background(AppColors.surfacePrimary)
                    .cornerRadius(AppRadius.small)
                } else {
                    Picker("List", selection: listIdBinding) {
                        ForEach(listOptions) { option in
                            Text(option.title).tag(Optional(option.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            AppTextField(
                "Task Title (Required)",
                text: $viewModel.title,
                validationState: viewModel.title.isEmpty ? .normal : .success
            )
            descriptionSection
            taskTypePicker
            statusPriorityRow
            if viewModel.taskType == .story || viewModel.taskType == .epic {
                AppTextField(
                    "Story Points (0–1000)",
                    text: $viewModel.storyPointsText,
                    validationState: storyPointsValidation
                )
            }
            dateField(title: "Start Date", date: $viewModel.startDate,
                      isExpanded: $viewModel.showStartDatePicker, icon: "calendar.badge.clock")
            dateField(title: "Due Date", date: $viewModel.dueDate,
                      isExpanded: $viewModel.showDueDatePicker, icon: "calendar.badge.exclamationmark")
            AppTextField("Assignee ID (Optional UUID)", text: $viewModel.assigneeIdText,
                         validationState: assigneeValidation)
            AppTextField("Labels (comma-separated)", text: $viewModel.labelsText, validationState: .normal)
            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.statusError)
                    .multilineTextAlignment(.center)
            }

            if viewModel.listId == nil {
                Text("Task must belong to a list. Select a list first.")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.statusError)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Description (Optional)")
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.sm)
            TextEdit(text: $viewModel.descriptionText)
                .frame(minHeight: 100)
                .padding()
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppRadius.medium)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColors.borderDefault, lineWidth: 1))
        }
    }

    private var statusPriorityRow: some View {
        HStack(spacing: AppSpacing.md) {
            pickerCard(title: "Status") {
                Picker("Status", selection: $viewModel.status) {
                    ForEach(TaskStatus.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }.pickerStyle(.menu)
            }
            pickerCard(title: "Priority") {
                Picker("Priority", selection: $viewModel.priority) {
                    ForEach(TaskPriority.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }.pickerStyle(.menu)
            }
        }
    }

    // MARK: - Task Type Picker

    private var taskTypePicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Type")
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    // Exclude .subtask from direct creation (subtasks are created via parent)
                    ForEach(TaskType.allCases.filter { $0 != .subtask }, id: \.self) { type in
                        taskTypeChip(type)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
            }
        }
    }

    private func taskTypeChip(_ type: TaskType) -> some View {
        Button {
            viewModel.taskType = type
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.iconName)
                    .font(.caption)
                Text(type.displayName)
                    .appFont(AppTypography.subheadline)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(viewModel.taskType == type ? AppColors.brandPrimary : AppColors.surfaceElevated)
            .foregroundColor(viewModel.taskType == type ? .white : AppColors.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(viewModel.taskType == type ? Color.clear : AppColors.borderDefault, lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private var storyPointsValidation: TextFieldValidationState {
        let text = viewModel.storyPointsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .normal }
        if let val = Int(text), (0...1000).contains(val) { return .success }
        return .error("Must be a number between 0 and 1000")
    }

    private var assigneeValidation: TextFieldValidationState {
        let text = viewModel.assigneeIdText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .normal }
        return UUID(uuidString: text) != nil ? .success : .error("Must be a valid UUID")
    }

    private var listIdBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.listId },
            set: { viewModel.listId = $0 }
        )
    }

    private func pickerCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.sm)
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppRadius.small)
        }
    }

    private func dateField(title: String, date: Binding<Date?>, isExpanded: Binding<Bool>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppColors.brandPrimary)
                Text(title)
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()

                if date.wrappedValue != nil {
                    Button {
                        withAnimation { date.wrappedValue = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                Button {
                    withAnimation {
                        isExpanded.wrappedValue.toggle()
                        if isExpanded.wrappedValue && date.wrappedValue == nil {
                            date.wrappedValue = Date()
                        }
                    }
                } label: {
                    Text(date.wrappedValue.map { formatDate($0) } ?? "Not Set")
                        .appFont(AppTypography.body)
                        .foregroundColor(date.wrappedValue != nil ? AppColors.textPrimary : AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.surfacePrimary)
                        .cornerRadius(AppRadius.small)
                }
            }

            if isExpanded.wrappedValue, let _ = date.wrappedValue {
                DatePicker(
                    title,
                    selection: Binding(
                        get: { date.wrappedValue ?? Date() },
                        set: { date.wrappedValue = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppRadius.medium)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(AppColors.surfaceElevated.opacity(0.5))
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func buildListOptions(from hierarchy: [HierarchyTreeDTO.SpaceNode]) -> [ListOption] {
        var options: [ListOption] = []
        for spaceNode in hierarchy {
            let spaceName = spaceNode.space.name
            for projectNode in spaceNode.projects {
                let projectName = projectNode.project.name
                for list in projectNode.lists {
                    options.append(ListOption(id: list.id, title: "\(spaceName) / \(projectName) / \(list.name)"))
                }
            }
        }
        return options
    }

    private var listOptions: [ListOption] {
        Self.buildListOptions(from: hierarchy)
    }
}
