import Foundation

// MARK: - Device Platform

public enum DevicePlatform: String, Codable, Sendable {
    case ios
    case android
    case web
}

// MARK: - Register Device Token Request

public struct RegisterDeviceTokenRequest: Codable, Sendable {
    public let token: String
    public let platform: String
    public let environment: String?

    public init(token: String, platform: String, environment: String? = nil) {
        self.token = token
        self.platform = platform
        self.environment = environment
    }
}

// MARK: - Device Token DTO

public struct DeviceTokenDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let userId: UUID
    public let token: String
    public let platform: String
    public let environment: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID = UUID(),
        userId: UUID,
        token: String,
        platform: String,
        environment: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.token = token
        self.platform = platform
        self.environment = environment
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Push Notification Payload

public struct PushNotificationPayload: Codable, Sendable {
    public let title: String
    public let body: String
    public let deepLink: String
    public let entityType: String
    public let entityId: String
    public let badge: Int?
    public let sound: String?

    public init(
        title: String,
        body: String,
        deepLink: String,
        entityType: String,
        entityId: String,
        badge: Int? = 1,
        sound: String? = "default"
    ) {
        self.title = title
        self.body = body
        self.deepLink = deepLink
        self.entityType = entityType
        self.entityId = entityId
        self.badge = badge
        self.sound = sound
    }
}
