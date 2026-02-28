import SwiftUI
import SharedModels
import Domain
import DesignSystem

@MainActor
public final class ProjectSettingsViewModel: ObservableObject {
    @Published public private(set) var workflow: WorkflowBundleDTO?
    @Published public private(set) var isLoading = false
    @Published public var error: Error?

    private let projectId: UUID
    private let workflowRepository: WorkflowRepositoryProtocol

    public init(projectId: UUID, workflowRepository: WorkflowRepositoryProtocol) {
        self.projectId = projectId
        self.workflowRepository = workflowRepository
    }

    public func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            self.workflow = try await workflowRepository.getWorkflow(projectId: projectId)
        } catch {
            self.error = error
        }
    }

    public func createStatus(_ payload: CreateWorkflowStatusRequest) async {
        do {
            _ = try await workflowRepository.createStatus(projectId: projectId, payload: payload)
            await refresh()
        } catch {
            self.error = error
        }
    }

    public func deleteStatus(statusId: UUID) async {
        do {
            try await workflowRepository.deleteStatus(statusId: statusId)
            await refresh()
        } catch {
            self.error = error
        }
    }

    public func createRule(_ payload: CreateAutomationRuleRequest) async {
        do {
            _ = try await workflowRepository.createRule(projectId: projectId, payload: payload)
            await refresh()
        } catch {
            self.error = error
        }
    }

    public func toggleRule(rule: AutomationRuleDTO, isEnabled: Bool) async {
        do {
            _ = try await workflowRepository.updateRule(ruleId: rule.id, payload: UpdateAutomationRuleRequest(isEnabled: isEnabled))
            await refresh()
        } catch {
            self.error = error
        }
    }

    public func deleteRule(ruleId: UUID) async {
        do {
            try await workflowRepository.deleteRule(ruleId: ruleId)
            await refresh()
        } catch {
            self.error = error
        }
    }
}

public struct ProjectSettingsView: View {
    @StateObject private var viewModel: ProjectSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingCreateStatus = false
    @State private var showingCreateRule = false

    public init(projectId: UUID, workflowRepository: WorkflowRepositoryProtocol) {
        _viewModel = StateObject(wrappedValue: ProjectSettingsViewModel(projectId: projectId, workflowRepository: workflowRepository))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                if viewModel.isLoading && viewModel.workflow == nil {
                    ProgressView()
                } else {
                    List {
                        statusesSection
                        rulesSection
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Project Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New Status") { showingCreateStatus = true }
                        Button("New Rule") { showingCreateRule = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await viewModel.refresh() }
            .refreshable { await viewModel.refresh() }
            .sheet(isPresented: $showingCreateStatus) {
                CreateStatusSheet { payload in
                    Task { await viewModel.createStatus(payload) }
                }
            }
            .sheet(isPresented: $showingCreateRule) {
                AutomationRuleBuilder(
                    statuses: viewModel.workflow?.statuses ?? []
                ) { payload in
                    Task { await viewModel.createRule(payload) }
                }
            }
        }
    }

    private var statusesSection: some View {
        Section {
            if let statuses = viewModel.workflow?.statuses, !statuses.isEmpty {
                ForEach(statuses.sorted(by: { $0.position < $1.position })) { status in
                    HStack(spacing: AppSpacing.md) {
                        Circle()
                            .fill(Color(hex: status.color) ?? AppColors.brandPrimary)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.name)
                                .appFont(AppTypography.body)
                                .foregroundColor(AppColors.textPrimary)
                            Text("\(status.category.rawValue)\(status.isDefault ? " • Default" : "")\(status.isFinal ? " • Final" : "")")
                                .appFont(AppTypography.caption2)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()

                        if status.isLocked {
                            Text("System")
                                .appFont(AppTypography.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .swipeActions {
                        if !status.isLocked {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteStatus(statusId: status.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } else {
                Text("No statuses found.")
                    .foregroundColor(AppColors.textSecondary)
            }
        } header: {
            HStack {
                Text("Statuses")
                Spacer()
                Button("New") { showingCreateStatus = true }
            }
        }
    }

    private var rulesSection: some View {
        Section {
            if let rules = viewModel.workflow?.rules, !rules.isEmpty {
                ForEach(rules) { rule in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.name)
                                .appFont(AppTypography.body)
                            Text(rule.triggerType)
                                .appFont(AppTypography.caption2)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { rule.isEnabled },
                            set: { newValue in
                                Task { await viewModel.toggleRule(rule: rule, isEnabled: newValue) }
                            }
                        ))
                        .labelsHidden()
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteRule(ruleId: rule.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } else {
                Text("No rules yet.")
                    .foregroundColor(AppColors.textSecondary)
            }
        } header: {
            HStack {
                Text("Automations")
                Spacer()
                Button("New") { showingCreateRule = true }
            }
        }
    }
}

private struct CreateStatusSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var color: String = "#4F46E5"
    @State private var category: WorkflowStatusCategory = .backlog
    @State private var isDefault: Bool = false
    @State private var isFinal: Bool = false

    let onCreate: (CreateWorkflowStatusRequest) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $name)
                    TextField("Color (#RRGGBB)", text: $color)
                    Picker("Category", selection: $category) {
                        ForEach(WorkflowStatusCategory.allCases, id: \.self) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                }
                Section("Flags") {
                    Toggle("Default", isOn: $isDefault)
                    Toggle("Final", isOn: $isFinal)
                }
            }
            .navigationTitle("New Status")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Create") {
                        onCreate(CreateWorkflowStatusRequest(name: name, color: color, position: nil, category: category, isDefault: isDefault, isFinal: isFinal))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
