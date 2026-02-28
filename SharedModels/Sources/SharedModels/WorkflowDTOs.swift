import Foundation

// MARK: - Workflow Bundle

/// Bundle returned by `GET /api/projects/:id/workflow`.
public struct WorkflowBundleDTO: Codable, Sendable, Equatable {
    public let projectId: UUID
    public let workflowVersion: Int
    public let statuses: [WorkflowStatusDTO]
    public let rules: [AutomationRuleDTO]

    public init(projectId: UUID, workflowVersion: Int, statuses: [WorkflowStatusDTO], rules: [AutomationRuleDTO]) {
        self.projectId = projectId
        self.workflowVersion = workflowVersion
        self.statuses = statuses
        self.rules = rules
    }
}

// MARK: - Statuses

public struct WorkflowStatusDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let projectId: UUID
    public let name: String
    public let color: String
    public let position: Double
    public let category: WorkflowStatusCategory
    public let isDefault: Bool
    public let isFinal: Bool
    public let isLocked: Bool
    public let legacyStatus: String?

    public init(
        id: UUID,
        projectId: UUID,
        name: String,
        color: String,
        position: Double,
        category: WorkflowStatusCategory,
        isDefault: Bool,
        isFinal: Bool,
        isLocked: Bool,
        legacyStatus: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.color = color
        self.position = position
        self.category = category
        self.isDefault = isDefault
        self.isFinal = isFinal
        self.isLocked = isLocked
        self.legacyStatus = legacyStatus
    }
}

public struct CreateWorkflowStatusRequest: Codable, Sendable {
    public let name: String
    public let color: String?
    public let position: Double?
    public let category: WorkflowStatusCategory
    public let isDefault: Bool?
    public let isFinal: Bool?

    public init(
        name: String,
        color: String? = nil,
        position: Double? = nil,
        category: WorkflowStatusCategory,
        isDefault: Bool? = nil,
        isFinal: Bool? = nil
    ) {
        self.name = name
        self.color = color
        self.position = position
        self.category = category
        self.isDefault = isDefault
        self.isFinal = isFinal
    }
}

public struct UpdateWorkflowStatusRequest: Codable, Sendable {
    public let name: String?
    public let color: String?
    public let position: Double?
    public let category: WorkflowStatusCategory?
    public let isDefault: Bool?
    public let isFinal: Bool?

    public init(
        name: String? = nil,
        color: String? = nil,
        position: Double? = nil,
        category: WorkflowStatusCategory? = nil,
        isDefault: Bool? = nil,
        isFinal: Bool? = nil
    ) {
        self.name = name
        self.color = color
        self.position = position
        self.category = category
        self.isDefault = isDefault
        self.isFinal = isFinal
    }
}

// MARK: - Automation Rules

public struct AutomationRuleDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let projectId: UUID
    public let name: String
    public let isEnabled: Bool
    public let triggerType: String
    public let triggerConfigJson: String?
    public let conditionsJson: String?
    public let actionsJson: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        projectId: UUID,
        name: String,
        isEnabled: Bool,
        triggerType: String,
        triggerConfigJson: String? = nil,
        conditionsJson: String? = nil,
        actionsJson: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.isEnabled = isEnabled
        self.triggerType = triggerType
        self.triggerConfigJson = triggerConfigJson
        self.conditionsJson = conditionsJson
        self.actionsJson = actionsJson
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CreateAutomationRuleRequest: Codable, Sendable {
    public let name: String
    public let isEnabled: Bool?
    public let triggerType: String
    public let triggerConfigJson: String?
    public let conditionsJson: String?
    public let actionsJson: String?

    public init(
        name: String,
        isEnabled: Bool? = nil,
        triggerType: String,
        triggerConfigJson: String? = nil,
        conditionsJson: String? = nil,
        actionsJson: String? = nil
    ) {
        self.name = name
        self.isEnabled = isEnabled
        self.triggerType = triggerType
        self.triggerConfigJson = triggerConfigJson
        self.conditionsJson = conditionsJson
        self.actionsJson = actionsJson
    }
}

public struct UpdateAutomationRuleRequest: Codable, Sendable {
    public let name: String?
    public let isEnabled: Bool?
    public let triggerType: String?
    public let triggerConfigJson: String?
    public let conditionsJson: String?
    public let actionsJson: String?

    public init(
        name: String? = nil,
        isEnabled: Bool? = nil,
        triggerType: String? = nil,
        triggerConfigJson: String? = nil,
        conditionsJson: String? = nil,
        actionsJson: String? = nil
    ) {
        self.name = name
        self.isEnabled = isEnabled
        self.triggerType = triggerType
        self.triggerConfigJson = triggerConfigJson
        self.conditionsJson = conditionsJson
        self.actionsJson = actionsJson
    }
}

