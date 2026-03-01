import Fluent
import Foundation

enum NotificationService {
    static func createMentionNotification(
        mentionedUserId: UUID,
        actorUserId: UUID,
        orgId: UUID,
        taskId: UUID,
        commentId: UUID,
        db: Database
    ) async throws {
        // Don't notify yourself.
        guard mentionedUserId != actorUserId else { return }

        let payload: [String: String] = [
            "taskId": taskId.uuidString,
            "commentId": commentId.uuidString,
            "actorUserId": actorUserId.uuidString
        ]
        let payloadJson = try? String(data: JSONSerialization.data(withJSONObject: payload, options: []), encoding: .utf8)

        let row = NotificationModel(
            userId: mentionedUserId,
            orgId: orgId,
            actorUserId: actorUserId,
            entityType: "comment",
            entityId: commentId,
            type: "mention",
            payloadJson: payloadJson,
            readAt: nil
        )
        // Rely on the DB uniqueness constraint to reject duplicates rather than doing
        // a pre-check read inside the write transaction (avoids holding the write lock longer).
        do {
            try await row.save(on: db)
        } catch {
            // Duplicate — already notified.
        }
    }
}

