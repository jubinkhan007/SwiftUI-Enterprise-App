import Fluent
import Vapor
import SharedModels

public enum PushNotificationService {
    // MARK: - Deep Link Generation

    public static func buildDeepLink(for entityType: String, entityId: String) -> String {
        switch entityType.lowercased() {
        case "task":
            return "taskflow://tasks/\(entityId)"
        case "conversation", "channel", "message":
            return "taskflow://channels/\(entityId)"
        case "meeting":
            return "taskflow://meetings/\(entityId)"
        case "call":
            return "taskflow://calls/\(entityId)"
        case "billing":
            return "taskflow://billing"
        case "inbox":
            return "taskflow://inbox"
        case "productivity", "reminder", "scheduled_message":
            return "taskflow://productivity"
        default:
            return "taskflow://inbox"
        }
    }

    // MARK: - Dispatch Notification

    public static func dispatch(
        to userId: UUID,
        title: String,
        body: String,
        entityType: String,
        entityId: String,
        on db: Database,
        logger: Logger
    ) async {
        let deepLink = buildDeepLink(for: entityType, entityId: entityId)
        let payload = PushNotificationPayload(
            title: title,
            body: body,
            deepLink: deepLink,
            entityType: entityType,
            entityId: entityId,
            badge: 1,
            sound: "default"
        )

        do {
            let tokens = try await DeviceTokenModel.query(on: db)
                .filter(\.$user.$id == userId)
                .all()

            if tokens.isEmpty {
                logger.info("PushNotificationService: No registered device tokens for user \(userId). DeepLink generated: \(deepLink)")
                return
            }

            for device in tokens {
                logger.info("PushNotificationService: Dispatching to [\(device.platform.uppercased())] token \(device.token.prefix(8))... | Title: '\(title)' | DeepLink: \(deepLink)")
                
                switch device.platform.lowercased() {
                case "ios":
                    // iOS APNs Payload structure
                    // { "aps": { "alert": { "title": title, "body": body }, "badge": 1, "sound": "default" }, "deep_link": deepLink, "entity_type": entityType, "entity_id": entityId }
                    logger.debug("Simulated APNs payload: \(payload.deepLink)")
                case "android":
                    // Android FCM Data Payload structure
                    // { "data": { "title": title, "body": body, "deep_link": deepLink, "entity_type": entityType, "entity_id": entityId } }
                    logger.debug("Simulated FCM data payload: \(payload.deepLink)")
                case "web":
                    logger.debug("Simulated Web Push payload: \(payload.deepLink)")
                default:
                    break
                }
            }
        } catch {
            logger.error("PushNotificationService: Failed to query device tokens for user \(userId): \(error)")
        }
    }
}
