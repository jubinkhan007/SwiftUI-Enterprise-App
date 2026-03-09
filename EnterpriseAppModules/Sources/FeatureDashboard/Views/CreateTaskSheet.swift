import SwiftUI
import DesignSystem
import SharedModels
import AppNetwork

public struct CreateTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateTaskViewModel
    private let hierarchy: [HierarchyTreeDTO.SpaceNode]
    private let apiClient: APIClientProtocol = APIClient()
    private let apiConfiguration: APIConfiguration = .current

    @State private var orgMembers: [OrganizationMemberDTO] = []
    @State private var isLoadingOrgMembers = false
    @State private var orgMembersLoadError: Error?
    @State private var showAssigneePicker = false

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
        .onChange(of: viewModel.taskType) { _, newValue in
            if newValue == .bug {
                let trimmed = viewModel.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    viewModel.descriptionText = bugTemplate
                }
            }
        }
        .task(id: listOptions.first?.id) {
            if viewModel.listId == nil, let first = listOptions.first {
                viewModel.listId = first.id
            }
        }
        .task {
            await loadOrgMembersIfNeeded()
        }
        .sheet(isPresented: $showAssigneePicker) {
            MemberPickerSheet(
                title: "Assign to",
                members: orgMembers,
                selectedUserId: $viewModel.assigneeUserId,
                allowUnassign: true
            )
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
            if viewModel.taskType == .bug {
                bugFieldsSection
            }
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
            pickerCard(title: "Assignee (Optional)") {
                Button {
                    showAssigneePicker = true
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let selected = selectedAssignee {
                                Text(selected.displayName)
                                    .appFont(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textPrimary)
                                Text(selected.email)
                                    .appFont(AppTypography.caption1)
                                    .foregroundColor(AppColors.textSecondary)
                            } else {
                                Text("Unassigned")
                                    .appFont(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                Text("Search by name or email")
                                    .appFont(AppTypography.caption1)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                        Spacer()
                        if isLoadingOrgMembers {
                            ProgressView().scaleEffect(0.85)
                        } else {
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoadingOrgMembers)
            }
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

            if let error = orgMembersLoadError, orgMembers.isEmpty {
                Text(error.localizedDescription)
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

    // MARK: - Bug Fields (Phase 13)

    private var bugFieldsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Toggle("Include structured bug fields", isOn: $viewModel.includeBugFields)
                .tint(AppColors.brandPrimary)
                .padding(AppSpacing.sm)
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppRadius.small)

            if viewModel.includeBugFields {
                pickerCard(title: "Severity") {
                    Picker("Severity", selection: $viewModel.bugSeverity) {
                        ForEach(BugSeverity.allCases, id: \.self) { s in
                            Text(s.rawValue.capitalized).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                }

                pickerCard(title: "Environment") {
                    Picker("Environment", selection: $viewModel.bugEnvironment) {
                        ForEach(BugEnvironment.allCases, id: \.self) { e in
                            Text(e.rawValue.uppercased()).tag(e)
                        }
                    }
                    .pickerStyle(.menu)
                }

                multilineField(title: "Expected Result", text: $viewModel.expectedResultText)
                multilineField(title: "Actual Result", text: $viewModel.actualResultText)
                multilineField(title: "Reproduction Steps", text: $viewModel.reproductionStepsText, minHeight: 120)
            } else {
                Text("Tip: Use the description template to capture repro steps if you don’t have permission to edit bug fields.")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textTertiary)
                    .padding(.horizontal, AppSpacing.sm)
            }
        }
    }

    private func multilineField(title: String, text: Binding<String>, minHeight: CGFloat = 80) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.sm)
            TextEdit(text: text)
                .frame(minHeight: minHeight)
                .padding()
                .background(AppColors.surfacePrimary)
                .cornerRadius(AppRadius.medium)
                .overlay(RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(AppColors.borderDefault, lineWidth: 1))
        }
    }

    private var bugTemplate: String {
        """
        ## Summary
        -

        ## Steps to Reproduce
        1.

        ## Expected Result
        -

        ## Actual Result
        -

        ## Environment
        - App version:
        - Device:
        - OS:
        """
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

    private var listIdBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.listId },
            set: { viewModel.listId = $0 }
        )
    }

    private var selectedAssignee: OrganizationMemberDTO? {
        guard let userId = viewModel.assigneeUserId else { return nil }
        return orgMembers.first(where: { $0.userId == userId })
    }

    private func loadOrgMembersIfNeeded() async {
        guard orgMembers.isEmpty else { return }
        guard !isLoadingOrgMembers else { return }
        guard let orgId = OrganizationContext.shared.orgId else { return }
        isLoadingOrgMembers = true
        orgMembersLoadError = nil
        defer { isLoadingOrgMembers = false }

        do {
            let endpoint = OrganizationEndpoint.listMembers(orgId: orgId, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<[OrganizationMemberDTO]>.self)
            orgMembers = response.data ?? []
        } catch {
            orgMembersLoadError = error
        }
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
