import Foundation

// MARK: - Presence

public enum PresenceState: String, Codable, Sendable, CaseIterable, Hashable {
    case online
    case away
    case offline
}

public struct UserPresenceDTO: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID { userId }
    public let userId: UUID
    public let state: PresenceState
    public let customStatusEmoji: String?
    public let customStatusText: String?
    public let customStatusExpiresAt: Date?
    public let lastHeartbeatAt: Date?

    public init(
        userId: UUID,
        state: PresenceState,
        customStatusEmoji: String? = nil,
        customStatusText: String? = nil,
        customStatusExpiresAt: Date? = nil,
        lastHeartbeatAt: Date? = nil
    ) {
        self.userId = userId
        self.state = state
        self.customStatusEmoji = customStatusEmoji
        self.customStatusText = customStatusText
        self.customStatusExpiresAt = customStatusExpiresAt
        self.lastHeartbeatAt = lastHeartbeatAt
    }
}

public struct PresenceHeartbeatRequest: Codable, Sendable, Hashable {
    public let state: PresenceState?

    public init(state: PresenceState? = nil) {
        self.state = state
    }
}

public struct SetCustomStatusRequest: Codable, Sendable, Hashable {
    public let emoji: String?
    public let text: String?
    public let expiresAt: Date?

    public init(emoji: String? = nil, text: String? = nil, expiresAt: Date? = nil) {
        self.emoji = emoji
        self.text = text
        self.expiresAt = expiresAt
    }
}

public struct BulkPresenceResponse: Codable, Sendable, Hashable {
    public let presences: [UserPresenceDTO]

    public init(presences: [UserPresenceDTO]) {
        self.presences = presences
    }
}
