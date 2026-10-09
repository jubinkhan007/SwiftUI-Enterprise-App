import Foundation

// MARK: - Search Entity Types

public enum SearchEntityType: String, Codable, CaseIterable, Sendable {
    case task = "task"
    case message = "message"
    case meeting = "meeting"
    case member = "member"
    case doc = "doc"

    public var displayName: String {
        switch self {
        case .task: return "Tasks"
        case .message: return "Messages"
        case .meeting: return "Meetings"
        case .member: return "People"
        case .doc: return "Docs"
        }
    }

    public var systemIconName: String {
        switch self {
        case .task: return "checkmark.square.fill"
        case .message: return "bubble.left.and.bubble.right.fill"
        case .meeting: return "video.fill"
        case .member: return "person.crop.circle.fill"
        case .doc: return "doc.text.fill"
        }
    }
}

// MARK: - Search Mode

public enum SearchMode: String, Codable, CaseIterable, Sendable {
    case hybrid = "hybrid"
    case semantic = "semantic"
    case keyword = "keyword"

    public var displayName: String {
        switch self {
        case .hybrid: return "Hybrid (AI)"
        case .semantic: return "Semantic"
        case .keyword: return "Keyword"
        }
    }
}

// MARK: - Omnibar Search Result Item

public struct SearchResultItemDTO: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let entityType: SearchEntityType
    public let title: String
    public let subtitle: String
    public let deepLink: String
    public let icon: String
    public let badge: String?
    public let metadata: [String: String]?
    public let similarityScore: Double?
    public let matchType: String?
    public let highlightSnippet: String?
    public let updatedAt: Date?

    public init(
        id: String,
        entityType: SearchEntityType,
        title: String,
        subtitle: String,
        deepLink: String,
        icon: String? = nil,
        badge: String? = nil,
        metadata: [String: String]? = nil,
        similarityScore: Double? = nil,
        matchType: String? = nil,
        highlightSnippet: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.title = title
        self.subtitle = subtitle
        self.deepLink = deepLink
        self.icon = icon ?? entityType.systemIconName
        self.badge = badge
        self.metadata = metadata
        self.similarityScore = similarityScore
        self.matchType = matchType
        self.highlightSnippet = highlightSnippet
        self.updatedAt = updatedAt
    }
}

// MARK: - Search Request & Response

public struct OmnibarSearchRequest: Codable, Sendable {
    public let query: String
    public let types: [SearchEntityType]?
    public let limit: Int?
    public let mode: SearchMode?
    public let threshold: Double?

    public init(
        query: String,
        types: [SearchEntityType]? = nil,
        limit: Int? = 20,
        mode: SearchMode? = .hybrid,
        threshold: Double? = nil
    ) {
        self.query = query
        self.types = types
        self.limit = limit
        self.mode = mode
        self.threshold = threshold
    }
}

public struct OmnibarSearchResponse: Codable, Sendable {
    public let results: [SearchResultItemDTO]
    public let totalCount: Int
    public let query: String
    public let mode: SearchMode?

    public init(
        results: [SearchResultItemDTO],
        totalCount: Int,
        query: String,
        mode: SearchMode? = .hybrid
    ) {
        self.results = results
        self.totalCount = totalCount
        self.query = query
        self.mode = mode
    }
}

// MARK: - AI Copilot Actions & DTOs

public enum AIAssistantAction: String, Codable, CaseIterable, Sendable {
    case breakdownTask = "breakdown_task"
    case generateStandupSummary = "generate_standup_summary"
    case suggestNextActions = "suggest_next_actions"
    case summarizeThread = "summarize_thread"
}

public struct SuggestedTaskDTO: Codable, Identifiable, Hashable, Sendable {
    public var id: String { title }
    public let title: String
    public let description: String?
    public let priority: String?
    public let estimateHours: Double?

    public init(
        title: String,
        description: String? = nil,
        priority: String? = "medium",
        estimateHours: Double? = 2.0
    ) {
        self.title = title
        self.description = description
        self.priority = priority
        self.estimateHours = estimateHours
    }
}

public struct AIAssistantRequest: Codable, Sendable {
    public let action: AIAssistantAction
    public let contextId: String?
    public let prompt: String?
    public let entityPayload: [String: String]?

    public init(
        action: AIAssistantAction,
        contextId: String? = nil,
        prompt: String? = nil,
        entityPayload: [String: String]? = nil
    ) {
        self.action = action
        self.contextId = contextId
        self.prompt = prompt
        self.entityPayload = entityPayload
    }
}

public struct AIAssistantResponse: Codable, Sendable {
    public let action: AIAssistantAction
    public let summary: String
    public let suggestedTasks: [SuggestedTaskDTO]?
    public let actionItems: [String]?

    public init(
        action: AIAssistantAction,
        summary: String,
        suggestedTasks: [SuggestedTaskDTO]? = nil,
        actionItems: [String]? = nil
    ) {
        self.action = action
        self.summary = summary
        self.suggestedTasks = suggestedTasks
        self.actionItems = actionItems
    }
}
