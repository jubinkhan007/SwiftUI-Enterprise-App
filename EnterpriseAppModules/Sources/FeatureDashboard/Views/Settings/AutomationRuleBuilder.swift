import SwiftUI
import SharedModels
import DesignSystem

public struct AutomationRuleBuilder: View {
    @Environment(\.dismiss) private var dismiss

    public enum Trigger: String, CaseIterable, Identifiable {
        case taskUpdated = "task.updated"
        case taskCreated = "task.created"
        case statusChanged = "task.status_changed"
        case priorityChanged = "task.priority_changed"
        case typeChanged = "task.type_changed"
        case sprintCompleted = "sprint.completed"

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .taskUpdated: return "Task Updated"
            case .taskCreated: return "Task Created"
            case .statusChanged: return "Status Changed"
            case .priorityChanged: return "Priority Changed"
            case .typeChanged: return "Type Changed"
            case .sprintCompleted: return "Sprint Completed"
            }
        }
    }

    public enum ActionType: String, CaseIterable, Identifiable {
        case setStatusId = "setStatusId"
        case setPriority = "setPriority"
        case assignUserId = "assignUserId"
        case addLabel = "addLabel"
        case removeLabel = "removeLabel"
        case moveUncompletedToNextSprint = "moveUncompletedToNextSprint"

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .setStatusId: return "Set Status"
            case .setPriority: return "Set Priority"
            case .assignUserId: return "Assign User"
            case .addLabel: return "Add Label"
            case .removeLabel: return "Remove Label"
            case .moveUncompletedToNextSprint: return "Move Uncompleted to Next Sprint"
            }
        }
    }

    public enum ConditionPreset: String, CaseIterable, Identifiable {
        case any = "any"
        case onlyBugs = "only_bugs"
        case onlyCritical = "only_critical"
        case onlyStories = "only_stories"

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .any: return "Any Matching Task"
            case .onlyBugs: return "Only Bug Issues (taskType == bug)"
            case .onlyCritical: return "Only Critical Priority (priority == critical)"
            case .onlyStories: return "Only User Stories (taskType == story)"
            }
        }

        public var json: String? {
            switch self {
            case .any:
                return nil
            case .onlyBugs:
                return #"[{"field":"taskType","op":"equals","value":"bug"}]"#
            case .onlyCritical:
                return #"[{"field":"priority","op":"equals","value":"critical"}]"#
            case .onlyStories:
                return #"[{"field":"taskType","op":"equals","value":"story"}]"#
            }
        }
    }

    private let statuses: [WorkflowStatusDTO]
    private let onCreate: (CreateAutomationRuleRequest) -> Void

    @State private var name: String = ""
    @State private var isEnabled: Bool = true
    @State private var trigger: Trigger = .statusChanged
    @State private var triggerToStatusId: UUID? = nil
    @State private var conditionPreset: ConditionPreset = .any

    @State private var actionType: ActionType = .setPriority
    @State private var actionStatusId: UUID? = nil
    @State private var actionPriority: TaskPriority = .medium
    @State private var actionUserId: String = ""
    @State private var actionLabel: String = ""

    public init(statuses: [WorkflowStatusDTO], onCreate: @escaping (CreateAutomationRuleRequest) -> Void) {
        self.statuses = statuses.sorted { $0.position < $1.position }
        self.onCreate = onCreate
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Quick Rule Presets") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                name = "Rollover Unfinished Sprint Tasks"
                                trigger = .sprintCompleted
                                conditionPreset = .any
                                actionType = .moveUncompletedToNextSprint
                            } label: {
                                Label("Sprint Rollover", systemImage: "arrow.right.circle.fill")
                                    .appFont(AppTypography.caption1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppColors.brandPrimary.opacity(0.14))
                                    .foregroundColor(AppColors.brandPrimary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                name = "Auto-Escalate New Bugs"
                                trigger = .taskCreated
                                conditionPreset = .onlyBugs
                                actionType = .setPriority
                                actionPriority = .high
                            } label: {
                                Label("Escalate Bugs", systemImage: "ladybug.fill")
                                    .appFont(AppTypography.caption1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppColors.statusWarning.opacity(0.14))
                                    .foregroundColor(AppColors.statusWarning)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                name = "Tag Critical Priority Urgent"
                                trigger = .priorityChanged
                                conditionPreset = .onlyCritical
                                actionType = .addLabel
                                actionLabel = "urgent"
                            } label: {
                                Label("Tag Critical Urgent", systemImage: "tag.fill")
                                    .appFont(AppTypography.caption1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppColors.statusError.opacity(0.14))
                                    .foregroundColor(AppColors.statusError)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Rule") {
                    TextField("Name", text: $name)
                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section("Trigger & Condition") {
                    Picker("When", selection: $trigger) {
                        ForEach(Trigger.allCases) { t in
                            Text(t.title).tag(t)
                        }
                    }

                    if trigger == .statusChanged {
                        Picker("To Status (optional)", selection: $triggerToStatusId) {
                            Text("Any").tag(Optional<UUID>.none)
                            ForEach(statuses) { s in
                                Text(s.name).tag(Optional(s.id))
                            }
                        }
                    }

                    if trigger != .sprintCompleted {
                        Picker("If Condition", selection: $conditionPreset) {
                            ForEach(ConditionPreset.allCases) { cond in
                                Text(cond.title).tag(cond)
                            }
                        }
                    }
                }

                Section("Action") {
                    actionTypePicker
                    actionDetail
                }

                Section("Preview") {
                    Text(previewSummary)
                        .appFont(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)

                    if let warning = warningText {
                        Text(warning)
                            .appFont(AppTypography.subheadline)
                            .foregroundColor(AppColors.statusError)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("triggerType: \(trigger.rawValue)")
                        if let t = triggerConfigJson { Text("triggerConfigJson: \(t)") }
                        if let c = conditionsJson { Text("conditionsJson: \(c)") }
                        if let a = actionsJson { Text("actionsJson: \(a)") }
                    }
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textTertiary)
                }
            }
            .navigationTitle("New Automation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Create") {
                        onCreate(CreateAutomationRuleRequest(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            isEnabled: isEnabled,
                            triggerType: trigger.rawValue,
                            triggerConfigJson: triggerConfigJson,
                            conditionsJson: conditionsJson,
                            actionsJson: actionsJson
                        ))
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
            .onAppear {
                if actionStatusId == nil {
                    actionStatusId = statuses.first?.id
                }
                if triggerToStatusId == nil {
                    triggerToStatusId = nil
                }
            }
        }
    }

    private var canCreate: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard actionsJson != nil else { return false }
        switch actionType {
        case .setStatusId:
            return actionStatusId != nil
        case .assignUserId:
            return UUID(uuidString: actionUserId.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        case .addLabel, .removeLabel:
            return !actionLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    private var warningText: String? {
        if trigger == .statusChanged, actionType == .setStatusId,
           let to = triggerToStatusId, let target = actionStatusId, to == target
        {
            return "This rule can re-trigger itself (trigger To Status matches action)."
        }
        return nil
    }

    private var previewSummary: String {
        let t = trigger.title
        let a = actionType.title
        return "\(t) → \(a)"
    }

    private var actionTypePicker: some View {
        Picker("Do", selection: $actionType) {
            ForEach(ActionType.allCases) { a in
                Text(a.title).tag(a)
            }
        }
    }

    @ViewBuilder
    private var actionDetail: some View {
        switch actionType {
        case .setStatusId:
            Picker("Status", selection: $actionStatusId) {
                Text("Select").tag(Optional<UUID>.none)
                ForEach(statuses) { s in
                    Text(s.name).tag(Optional(s.id))
                }
            }
        case .setPriority:
            Picker("Priority", selection: $actionPriority) {
                ForEach(TaskPriority.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
        case .assignUserId:
            TextField("User UUID", text: $actionUserId)
                .autocorrectionDisabled()
        case .addLabel, .removeLabel:
            TextField("Label", text: $actionLabel)
        case .moveUncompletedToNextSprint:
            Text("Remaining open tasks in the sprint will automatically migrate to the next planned sprint.")
                .appFont(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
                .padding(.vertical, 4)
        }
    }

    private var triggerConfigJson: String? {
        guard trigger == .statusChanged, let to = triggerToStatusId else { return nil }
        return #"{"toStatusId":"\#(to.uuidString)"}"#
    }

    private var conditionsJson: String? {
        guard trigger != .sprintCompleted else { return nil }
        return conditionPreset.json
    }

    private var actionsJson: String? {
        switch actionType {
        case .setPriority:
            return #"[{"type":"setPriority","value":"\#(actionPriority.rawValue)"}]"#
        case .setStatusId:
            guard let id = actionStatusId else { return nil }
            return #"[{"type":"setStatusId","value":"\#(id.uuidString)"}]"#
        case .assignUserId:
            guard let id = UUID(uuidString: actionUserId.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
            return #"[{"type":"assignUserId","value":"\#(id.uuidString)"}]"#
        case .addLabel:
            let label = actionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            return #"[{"type":"addLabel","value":"\#(label)"}]"#
        case .removeLabel:
            let label = actionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            return #"[{"type":"removeLabel","value":"\#(label)"}]"#
        case .moveUncompletedToNextSprint:
            return #"[{"type":"moveUncompletedToNextSprint"}]"#
        }
    }
}
