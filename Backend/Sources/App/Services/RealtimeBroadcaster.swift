import Foundation
import SharedModels
import Vapor

enum RealtimeBroadcaster {
    struct ServerEvent: Codable, Sendable {
        let eventId: String
        let orgId: UUID
        let type: String
        let entityId: UUID
        let updatedAt: Date
        let payload: [String: String]?
    }

    static func broadcastCommentCreated(app: Application, orgId: UUID, task: TaskItemModel, commentId: UUID) {
        let taskId = (try? task.requireID()) ?? task.id ?? UUID()
        let listId = task.$list.id
        let projectId = task.list?.$project.id
        broadcast(
            app: app,
            orgId: orgId,
            type: "comment.created",
            entityId: commentId,
            payload: [
                "taskId": taskId.uuidString,
                "listId": listId?.uuidString ?? "",
                "projectId": projectId?.uuidString ?? ""
            ]
        )
    }

    static func broadcastAttachmentCreated(app: Application, orgId: UUID, task: TaskItemModel, attachmentId: UUID) {
        let taskId = (try? task.requireID()) ?? task.id ?? UUID()
        let listId = task.$list.id
        let projectId = task.list?.$project.id
        broadcast(
            app: app,
            orgId: orgId,
            type: "attachment.created",
            entityId: attachmentId,
            payload: [
                "taskId": taskId.uuidString,
                "listId": listId?.uuidString ?? "",
                "projectId": projectId?.uuidString ?? ""
            ]
        )
    }

    private static func broadcast(app: Application, orgId: UUID, type: String, entityId: UUID, payload: [String: String]) {
        let event = ServerEvent(
            eventId: UUID().uuidString,
            orgId: orgId,
            type: type,
            entityId: entityId,
            updatedAt: Date(),
            payload: payload
        )
        guard let data = try? JSONEncoder().encode(event),
              let text = String(data: data, encoding: .utf8)
        else { return }

        app.realtimeHub.broadcast(channel: "org:\(orgId.uuidString)", text: text)
        if let projectId = payload["projectId"], !projectId.isEmpty {
            app.realtimeHub.broadcast(channel: "project:\(projectId)", text: text)
        }
        if let listId = payload["listId"], !listId.isEmpty {
            app.realtimeHub.broadcast(channel: "list:\(listId)", text: text)
        }
    }
}
