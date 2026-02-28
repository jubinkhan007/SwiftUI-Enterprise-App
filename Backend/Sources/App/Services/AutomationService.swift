import Fluent
import SharedModels
import Vapor

/// Evaluates project-scoped automation rules against a single canonical task event.
/// Designed to be idempotent and loop-safe (no-op actions are skipped, execution is deduped by eventId).
struct AutomationService {
    struct TaskEvent: Sendable {
        struct Change<T: Sendable>: Sendable {
            let from: T
            let to: T
        }

        let eventId: String
        let orgId: UUID
        let projectId: UUID
        let workflowVersion: Int
        let taskId: UUID
        let userId: UUID

        let isCreated: Bool
        let statusIdChange: Change<UUID?>?
        let priorityChange: Change<TaskPriority>?
        let typeChange: Change<TaskType>?
    }

    /// Evaluate + apply rules within the caller's transaction.
    /// - Returns: number of successful rule executions.
    static func applyAutomations(
        event: TaskEvent,
        task: TaskItemModel,
        db: Database,
        logger: Logger
    ) async {
        let rules: [AutomationRuleModel]
        do {
            rules = try await AutomationRuleModel.query(on: db)
                .filter(\.$project.$id == event.projectId)
                .filter(\.$isEnabled == true)
                .all()
        } catch {
            logger.warning("AutomationService: failed to load rules: \(error)")
            return
        }

        for rule in rules {
            guard let ruleId = rule.id else { continue }
            guard matchesTrigger(rule: rule, event: event) else { continue }

            // Idempotency / dedup: rule+task+event_id is unique.
            do {
                let already = try await AutomationExecutionModel.query(on: db)
                    .filter(\.$rule.$id == ruleId)
                    .filter(\.$task.$id == event.taskId)
                    .filter(\.$eventId == event.eventId)
                    .count() > 0
                if already { continue }
            } catch {
                logger.warning("AutomationService: dedup check failed: \(error)")
                continue
            }

            let exec = AutomationExecutionModel(
                ruleId: ruleId,
                taskId: event.taskId,
                eventId: event.eventId,
                workflowVersion: event.workflowVersion,
                status: "started",
                error: nil
            )

            do {
                try await exec.save(on: db)
            } catch {
                // Likely unique constraint race; treat as already executed.
                continue
            }

            do {
                let didApply = try await applyRule(rule: rule, event: event, task: task, db: db)
                exec.status = didApply ? "success" : "skipped"
                exec.error = nil
                try await exec.save(on: db)
            } catch {
                exec.status = "failure"
                exec.error = String(describing: error)
                do { try await exec.save(on: db) } catch { /* best-effort */ }
            }
        }
    }

    // MARK: - Trigger matching

    private static func matchesTrigger(rule: AutomationRuleModel, event: TaskEvent) -> Bool {
        switch rule.triggerType {
        case "task.updated":
            return true
        case "task.created":
            return event.isCreated
        case "task.status_changed":
            return event.statusIdChange != nil
        case "task.priority_changed":
            return event.priorityChange != nil
        case "task.type_changed":
            return event.typeChange != nil
        default:
            return false
        }
    }

    // MARK: - Rule evaluation

    private struct Condition: Decodable {
        let field: String
        let op: String
        let value: String
    }

    private struct Action: Decodable {
        let type: String
        let value: String?
    }

    private static func applyRule(
        rule: AutomationRuleModel,
        event: TaskEvent,
        task: TaskItemModel,
        db: Database
    ) async throws -> Bool {
        // 1) Trigger config (optional)
        if let triggerConfigJson = rule.triggerConfigJson {
            if !matchesTriggerConfig(json: triggerConfigJson, event: event) { return false }
        }

        // 2) Conditions (optional)
        if let conditionsJson = rule.conditionsJson {
            let conditions = try decodeConditions(json: conditionsJson)
            if !conditionsMatch(conditions, task: task) { return false }
        }

        // 3) Actions (optional)
        guard let actionsJson = rule.actionsJson else { return false }
        let actions = try decodeActions(json: actionsJson)
        if actions.isEmpty { return false }

        var didMutate = false
        var activities: [TaskActivityModel] = []

        for action in actions {
            let (mutated, activity) = try await applyAction(
                action,
                ruleId: try rule.requireID(),
                eventId: event.eventId,
                projectId: event.projectId,
                task: task,
                userId: event.userId,
                db: db
            )
            if mutated { didMutate = true }
            if let activity { activities.append(activity) }
        }

        if !didMutate { return false }

        task.version += 1
        try await task.save(on: db)
        for a in activities {
            try await a.save(on: db)
        }
        return true
    }

    // MARK: - Trigger config

    private static func matchesTriggerConfig(json: String, event: TaskEvent) -> Bool {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any]
        else {
            return true // treat invalid config as "no additional constraints"
        }

        if let toStatusId = dict["toStatusId"] as? String, let expected = UUID(uuidString: toStatusId) {
            guard let actual = event.statusIdChange?.to else { return false }
            if actual != expected { return false }
        }

        if let fromStatusId = dict["fromStatusId"] as? String, let expected = UUID(uuidString: fromStatusId) {
            guard let actual = event.statusIdChange?.from else { return false }
            if actual != expected { return false }
        }

        if let priority = dict["toPriority"] as? String,
           let expected = TaskPriority(rawValue: priority) {
            guard let actual = event.priorityChange?.to else { return false }
            if actual != expected { return false }
        }

        return true
    }

    // MARK: - Conditions

    private static func decodeConditions(json: String) throws -> [Condition] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return [] }

        if trimmed.hasPrefix("[") {
            return try JSONDecoder().decode([Condition].self, from: data)
        }

        struct Wrapper: Decodable { let all: [Condition] }
        let wrapped = try JSONDecoder().decode(Wrapper.self, from: data)
        return wrapped.all
    }

    private static func conditionsMatch(_ conditions: [Condition], task: TaskItemModel) -> Bool {
        for c in conditions {
            guard conditionMatches(c, task: task) else { return false }
        }
        return true
    }

    private static func conditionMatches(_ c: Condition, task: TaskItemModel) -> Bool {
        switch c.field {
        case "taskType":
            guard let expected = TaskType(rawValue: c.value) else { return false }
            return compare(task.taskType, expected, op: c.op)
        case "priority":
            guard let expected = TaskPriority(rawValue: c.value) else { return false }
            return compare(task.priority, expected, op: c.op)
        case "statusId":
            guard let expected = UUID(uuidString: c.value) else { return false }
            return compare(task.$customStatus.id, expected, op: c.op)
        case "assigneeId":
            guard let expected = UUID(uuidString: c.value) else { return false }
            return compare(task.$assignee.id, expected, op: c.op)
        default:
            return false
        }
    }

    private static func compare<T: Equatable>(_ actual: T, _ expected: T, op: String) -> Bool {
        switch op {
        case "equals", "eq":
            return actual == expected
        case "notEquals", "neq":
            return actual != expected
        default:
            return false
        }
    }

    private static func compare<T: Equatable>(_ actual: T?, _ expected: T, op: String) -> Bool {
        switch op {
        case "equals", "eq":
            return actual == expected
        case "notEquals", "neq":
            return actual != expected
        default:
            return false
        }
    }

    // MARK: - Actions

    private static func decodeActions(json: String) throws -> [Action] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return [] }

        if trimmed.hasPrefix("[") {
            return try JSONDecoder().decode([Action].self, from: data)
        }

        struct Wrapper: Decodable { let actions: [Action] }
        let wrapped = try JSONDecoder().decode(Wrapper.self, from: data)
        return wrapped.actions
    }

    private static func applyAction(
        _ action: Action,
        ruleId: UUID,
        eventId: String,
        projectId: UUID,
        task: TaskItemModel,
        userId: UUID,
        db: Database
    ) async throws -> (mutated: Bool, activity: TaskActivityModel?) {
        switch action.type {
        case "setPriority":
            guard let raw = action.value, let newPriority = TaskPriority(rawValue: raw) else { return (false, nil) }
            guard task.priority != newPriority else { return (false, nil) }
            let from = task.priority
            task.priority = newPriority
            let md = [
                "from": from.rawValue,
                "to": newPriority.rawValue,
                "automation_rule_id": ruleId.uuidString,
                "automation_event_id": eventId
            ]
            return (true, TaskActivityModel(taskId: try task.requireID(), userId: userId, type: .priorityChanged, metadata: md))

        case "setStatusId":
            guard let raw = action.value, let newStatusId = UUID(uuidString: raw) else { return (false, nil) }
            guard task.$customStatus.id != newStatusId else { return (false, nil) }

            // Ensure the status belongs to this project.
            guard let target = try await CustomStatusModel.query(on: db)
                .filter(\.$id == newStatusId)
                .filter(\.$project.$id == projectId)
                .first()
            else { return (false, nil) }

            let oldStatusId = task.$customStatus.id
            task.$customStatus.id = newStatusId

            // Keep legacy enum in sync best-effort.
            if let legacy = target.legacyStatus, let mapped = TaskStatus(rawValue: legacy) {
                task.status = mapped
            } else {
                task.status = legacyFallback(from: target.category)
            }

            let md = [
                "from_status_id": oldStatusId?.uuidString ?? "",
                "to_status_id": newStatusId.uuidString,
                "from": oldStatusId?.uuidString ?? "",
                "to": newStatusId.uuidString,
                "automation_rule_id": ruleId.uuidString,
                "automation_event_id": eventId
            ]
            return (true, TaskActivityModel(taskId: try task.requireID(), userId: userId, type: .statusChanged, metadata: md))

        case "assignUserId":
            guard let raw = action.value, let newAssignee = UUID(uuidString: raw) else { return (false, nil) }
            guard task.$assignee.id != newAssignee else { return (false, nil) }
            task.$assignee.id = newAssignee
            let md = [
                "assignee_id": newAssignee.uuidString,
                "automation_rule_id": ruleId.uuidString,
                "automation_event_id": eventId
            ]
            return (true, TaskActivityModel(taskId: try task.requireID(), userId: userId, type: .assigned, metadata: md))

        case "addLabel":
            guard let label = action.value?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else { return (false, nil) }
            var labels = task.labels ?? []
            guard !labels.contains(label) else { return (false, nil) }
            guard labels.count < 20 else { return (false, nil) }
            labels.append(label)
            task.labels = labels
            return (true, nil)

        case "removeLabel":
            guard let label = action.value?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else { return (false, nil) }
            guard var labels = task.labels else { return (false, nil) }
            let before = labels.count
            labels.removeAll { $0 == label }
            guard labels.count != before else { return (false, nil) }
            task.labels = labels.isEmpty ? nil : labels
            return (true, nil)

        default:
            return (false, nil)
        }
    }

    private static func legacyFallback(from category: WorkflowStatusCategory) -> TaskStatus {
        switch category {
        case .backlog:
            return .todo
        case .active:
            return .inProgress
        case .completed:
            return .done
        case .cancelled:
            return .cancelled
        }
    }
}

