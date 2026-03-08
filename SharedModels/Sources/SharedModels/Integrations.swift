import Foundation

// MARK: - API Keys

public enum APIKeyScope: String, Codable, Sendable, CaseIterable, Equatable {
    case tasksRead = "tasks.read"
    case tasksWrite = "tasks.write"
    case webhooksManage = "webhooks.manage"
    case apiKeysManage = "apikeys.manage"
    case admin = "admin"
}

public struct APIKeyDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let orgId: UUID
    public let userId: UUID
    public let name: String
    /// Display-only prefix (not secret), e.g. `"abcd1234"`.
    public let keyPrefix: String
    public let scopes: [APIKeyScope]
    public let lastUsedAt: Date?
    public let expiresAt: Date?
    public let isRevoked: Bool
    public let createdAt: Date?

    public init(
        id: UUID,
        orgId: UUID,
        userId: UUID,
        name: String,
        keyPrefix: String,
        scopes: [APIKeyScope],
        lastUsedAt: Date? = nil,
        expiresAt: Date? = nil,
        isRevoked: Bool = false,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.orgId = orgId
        self.userId = userId
        self.name = name
        self.keyPrefix = keyPrefix
        self.scopes = scopes
        self.lastUsedAt = lastUsedAt
        self.expiresAt = expiresAt
        self.isRevoked = isRevoked
        self.createdAt = createdAt
    }
}

public struct CreateAPIKeyRequest: Codable, Sendable {
    public let name: String
    public let scopes: [APIKeyScope]
    public let expiresAt: Date?

    public init(name: String, scopes: [APIKeyScope], expiresAt: Date? = nil) {
        self.name = name
        self.scopes = scopes
        self.expiresAt = expiresAt
    }
}

public struct CreateAPIKeyResponse: Codable, Sendable, Equatable, Identifiable {
    /// The raw API key (shown once). Store it securely.
    public let rawKey: String
    public let apiKey: APIKeyDTO
    public var id: UUID { apiKey.id }

    public init(rawKey: String, apiKey: APIKeyDTO) {
        self.rawKey = rawKey
        self.apiKey = apiKey
    }
}

// MARK: - Webhooks

public struct WebhookSubscriptionDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let orgId: UUID
    public let targetUrl: String
    public let secret: String
    public let events: [String]
    public let isActive: Bool
    public let failureCount: Int
    public let createdAt: Date?

    public init(
        id: UUID,
        orgId: UUID,
        targetUrl: String,
        secret: String,
        events: [String],
        isActive: Bool = true,
        failureCount: Int = 0,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.orgId = orgId
        self.targetUrl = targetUrl
        self.secret = secret
        self.events = events
        self.isActive = isActive
        self.failureCount = failureCount
        self.createdAt = createdAt
    }
}

public struct CreateWebhookSubscriptionRequest: Codable, Sendable {
    public let targetUrl: String
    public let events: [String]
    public let secret: String?

    public init(targetUrl: String, events: [String], secret: String? = nil) {
        self.targetUrl = targetUrl
        self.events = events
        self.secret = secret
    }
}

public struct WebhookTestResponse: Codable, Sendable, Equatable {
    public let delivered: Bool
    public let statusCode: Int?

    public init(delivered: Bool, statusCode: Int? = nil) {
        self.delivered = delivered
        self.statusCode = statusCode
    }
}

public struct UpdateWebhookSubscriptionRequest: Codable, Sendable {
    public let targetUrl: String?
    public let secret: String?
    public let events: [String]?
    public let isActive: Bool?

    public init(targetUrl: String? = nil, secret: String? = nil, events: [String]? = nil, isActive: Bool? = nil) {
        self.targetUrl = targetUrl
        self.secret = secret
        self.events = events
        self.isActive = isActive
    }
}
