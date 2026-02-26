import Foundation

// MARK: - View Enums

public enum ViewType: String, Codable, Sendable {
    case list
    case board
    case calendar
    case timeline
}

public enum ViewScope: String, Codable, Sendable {
    case org
    case space
    case project
    case list
}

public enum BoardGroupBy: String, Codable, Sendable {
    case status
    case assignee
    case priority
}

// MARK: - Configurations

/// Configuration specific to Board (Kanban) views.
public struct BoardColumnConfigDTO: Codable, Sendable, Equatable {
    public var groupBy: BoardGroupBy
    /// Custom ordering of columns based on the groupBy value (e.g. array of status names or assignee UUIDs)
    public var columnOrder: [String]?
    /// Work-in-progress limits keyed by column identifier
    public var wipLimits: [String: Int]?

    public init(
        groupBy: BoardGroupBy = .status,
        columnOrder: [String]? = nil,
        wipLimits: [String: Int]? = nil
    ) {
        self.groupBy = groupBy
        self.columnOrder = columnOrder
        self.wipLimits = wipLimits
    }
}

// MARK: - View Config DTO

/// A saved view configuration that defines how tasks are filtered, sorted, and presented.
public struct ViewConfigDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public var name: String
    public var type: ViewType
    
    /// JSON string defining the filters (parsed on backend by TaskQueryParser)
    public var filtersJson: String?
    /// JSON string defining the sorts
    public var sortsJson: String?
    
    /// Schema version for the JSON structure, to handle future evolutions
    public var schemaVersion: Int
    
    /// Where this view is available
    public var appliesTo: ViewScope
    public var scopeId: UUID
    
    /// The user who created this view. If null, it's a built-in/system view.
    public var ownerUserId: UUID?
    
    /// Whether this view is visible to all members of the scope
    public var isPublic: Bool
    
    /// Whether this is the default view for the scope
    public var isDefault: Bool
    
    /// List of columns to show in List view, ordered
    public var visibleColumns: [String]?
    
    /// Board-specific configuration
    public var boardConfig: BoardColumnConfigDTO?
    
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        type: ViewType,
        filtersJson: String? = nil,
        sortsJson: String? = nil,
        schemaVersion: Int = 1,
        appliesTo: ViewScope,
        scopeId: UUID,
        ownerUserId: UUID? = nil,
        isPublic: Bool = false,
        isDefault: Bool = false,
        visibleColumns: [String]? = nil,
        boardConfig: BoardColumnConfigDTO? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.filtersJson = filtersJson
        self.sortsJson = sortsJson
        self.schemaVersion = schemaVersion
        self.appliesTo = appliesTo
        self.scopeId = scopeId
        self.ownerUserId = ownerUserId
        self.isPublic = isPublic
        self.isDefault = isDefault
        self.visibleColumns = visibleColumns
        self.boardConfig = boardConfig
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Requests

public struct CreateViewConfigRequest: Codable, Sendable {
    public let name: String
    public let type: ViewType
    public let filtersJson: String?
    public let sortsJson: String?
    public let appliesTo: ViewScope
    public let scopeId: UUID
    public let isPublic: Bool
    public let isDefault: Bool
    public let visibleColumns: [String]?
    public let boardConfig: BoardColumnConfigDTO?
    
    public init(name: String, type: ViewType, filtersJson: String? = nil, sortsJson: String? = nil, appliesTo: ViewScope, scopeId: UUID, isPublic: Bool = false, isDefault: Bool = false, visibleColumns: [String]? = nil, boardConfig: BoardColumnConfigDTO? = nil) {
        self.name = name
        self.type = type
        self.filtersJson = filtersJson
        self.sortsJson = sortsJson
        self.appliesTo = appliesTo
        self.scopeId = scopeId
        self.isPublic = isPublic
        self.isDefault = isDefault
        self.visibleColumns = visibleColumns
        self.boardConfig = boardConfig
    }
}

public struct UpdateViewConfigRequest: Codable, Sendable {
    public var name: String?
    public var type: ViewType?
    public var filtersJson: String?
    public var sortsJson: String?
    public var isPublic: Bool?
    public var isDefault: Bool?
    public var visibleColumns: [String]?
    public var boardConfig: BoardColumnConfigDTO?
    
    public init(name: String? = nil, type: ViewType? = nil, filtersJson: String? = nil, sortsJson: String? = nil, isPublic: Bool? = nil, isDefault: Bool? = nil, visibleColumns: [String]? = nil, boardConfig: BoardColumnConfigDTO? = nil) {
        self.name = name
        self.type = type
        self.filtersJson = filtersJson
        self.sortsJson = sortsJson
        self.isPublic = isPublic
        self.isDefault = isDefault
        self.visibleColumns = visibleColumns
        self.boardConfig = boardConfig
    }
}
