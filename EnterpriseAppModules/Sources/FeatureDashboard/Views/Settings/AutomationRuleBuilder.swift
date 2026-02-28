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

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .taskUpdated: return "Task Updated"
            case .taskCreated: return "Task Created"
            case .statusChanged: return "Status Changed"
            case .priorityChanged: return "Priority Changed"
            case .typeChanged: return "Type Changed"
            }
        }
    }

    public enum ActionType: String, CaseIterable, Identifiable {
        case setStatusId = "setStatusId"
        case setPriority = "setPriority"
        case assignUserId = "assignUserId"
        case addLabel = "addLabel"
        case removeLabel = "removeLabel"

        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .setStatusId: return "Set Status"
            case .setPriority: return "Set Priority"
            case .assignUserId: return "Assign User"
            case .addLabel: return "Add Label"
            case .removeLabel: return "Remove Label"
            }
        }
    }

    private let statuses: [WorkflowStatusDTO]
    private let onCreate: (CreateAutomationRuleRequest) -> Void

    @State private var name: String = ""
    @State private var isEnabled: Bool = true
    @State private var trigger: Trigger = .statusChanged
    @State private var triggerToStatusId: UUID? = nil

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
                Section("Rule") {
                    TextField("Name", text: $name)
                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section("Trigger") {
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
                }

                Section("Action") {
                    Picker("Do", selection: $actionType) {
                        ForEach(ActionType.allCases) { a in
                            Text(a.title).tag(a)
                        }
                    }

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
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    case .addLabel, .removeLabel:
                        TextField("Label", text: $actionLabel)
                    }
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
                            conditionsJson: nil,
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

    private var triggerConfigJson: String? {
        guard trigger == .statusChanged, let to = triggerToStatusId else { return nil }
        return #"{"toStatusId":"\#(to.uuidString)"}"#
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
        }
    }
}

