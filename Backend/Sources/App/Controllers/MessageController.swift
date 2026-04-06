import Fluent
import SharedModels
import Vapor

struct MessageController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let conversations = routes.grouped("conversations")
        conversations.get(":conversationID", "messages", use: listMessages)
        conversations.post(":conversationID", "messages", use: sendMessage)

        let messages = routes.grouped("messages")
        messages.get(":messageID", "thread", use: getThread)
        messages.put(":messageID", use: editMessage)
        messages.delete(":messageID", use: deleteMessage)
    }

    @Sendable
    func listMessages(req: Request) async throws -> APIResponse<[MessageDTO]> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)

        _ = try await requireMembership(conversationID: conversationID, userId: ctx.userId, on: req.db)

        let limit = min((try? req.query.get(Int.self, at: "limit")) ?? 50, 100)
        let cursor: UUID? = try? req.query.get(UUID.self, at: "cursor")

        var query = MessageModel.query(on: req.db)
            .filter(\.$conversation.$id == conversationID)
            .filter(\.$parent.$id == nil)
            .with(\.$sender)
            .sort(\.$createdAt, .descending)
            .limit(limit)

        if let cursor,
           let cursorMessage = try await MessageModel.find(cursor, on: req.db),
           let cursorDate = cursorMessage.createdAt {
            query = query.filter(\.$createdAt < cursorDate)
        }

        let messages = try await query.all()
        let dtos = try await messages.asyncMap { message in
            try await buildMessageDTO(message: message, orgId: ctx.orgId, on: req.db)
        }
        return .success(dtos)
    }

    @Sendable
    func getThread(req: Request) async throws -> APIResponse<ThreadMessageBundleDTO> {
        let ctx = try req.orgContext
        let messageID = try req.parameters.require("messageID", as: UUID.self)

        guard let rootMessage = try await MessageModel.query(on: req.db)
            .filter(\.$id == messageID)
            .filter(\.$parent.$id == nil)
            .with(\.$sender)
            .first() else {
            throw Abort(.notFound, reason: "Thread root not found.")
        }

        _ = try await requireMembership(conversationID: rootMessage.$conversation.id, userId: ctx.userId, on: req.db)

        let replies = try await MessageModel.query(on: req.db)
            .filter(\.$parent.$id == messageID)
            .with(\.$sender)
            .sort(\.$createdAt, .ascending)
            .all()

        let bundle = ThreadMessageBundleDTO(
            rootMessage: try await buildMessageDTO(message: rootMessage, orgId: ctx.orgId, on: req.db),
            replies: try await replies.asyncMap { reply in
                try await buildMessageDTO(message: reply, orgId: ctx.orgId, on: req.db)
            }
        )
        return .success(bundle)
    }

    @Sendable
    func sendMessage(req: Request) async throws -> APIResponse<MessageDTO> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let payload = try req.content.decode(SendMessageRequest.self)

        guard !payload.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Message body cannot be empty.")
        }

        _ = try await requireMembership(conversationID: conversationID, userId: ctx.userId, on: req.db)

        if let parentID = payload.parentId {
            guard let parent = try await MessageModel.query(on: req.db)
                .filter(\.$id == parentID)
                .filter(\.$conversation.$id == conversationID)
                .first() else {
                throw Abort(.badRequest, reason: "Invalid thread parent.")
            }
            _ = parent
        }

        let message = MessageModel(
            conversationId: conversationID,
            senderId: ctx.userId,
            body: payload.body,
            messageType: payload.messageType ?? "text",
            parentId: payload.parentId
        )
        try await message.save(on: req.db)

        if let conversation = try await ConversationModel.find(conversationID, on: req.db) {
            conversation.lastMessageAt = message.createdAt ?? Date()
            try await conversation.save(on: req.db)
        }

        if let membership = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$conversation.$id == conversationID)
            .filter(\.$user.$id == ctx.userId)
            .first() {
            membership.lastReadAt = message.createdAt ?? Date()
            membership.lastReadMessageId = message.id
            membership.lastSeenAt = Date()
            try await membership.save(on: req.db)
        }

        try await message.$sender.load(on: req.db)
        let dto = try await buildMessageDTO(message: message, orgId: ctx.orgId, on: req.db)

        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: ctx.orgId,
            channels: ["conversation:\(conversationID.uuidString)"],
            type: "message.new",
            entityId: dto.id,
            payload: [
                "conversationId": conversationID.uuidString,
                "messageId": dto.id.uuidString,
                "senderId": dto.senderId.uuidString,
                "parentId": dto.parentId?.uuidString ?? ""
            ]
        )

        return .success(dto)
    }

    @Sendable
    func editMessage(req: Request) async throws -> APIResponse<MessageDTO> {
        let ctx = try req.orgContext
        let messageID = try req.parameters.require("messageID", as: UUID.self)
        let payload = try req.content.decode(EditMessageRequest.self)

        guard !payload.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Message body cannot be empty.")
        }

        guard let message = try await MessageModel.query(on: req.db)
            .filter(\.$id == messageID)
            .with(\.$sender)
            .first() else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        guard message.$sender.id == ctx.userId else {
            throw Abort(.forbidden, reason: "Cannot edit someone else's message.")
        }

        _ = try await requireMembership(conversationID: message.$conversation.id, userId: ctx.userId, on: req.db)

        message.body = payload.body
        message.editedAt = Date()
        try await message.save(on: req.db)

        let dto = try await buildMessageDTO(message: message, orgId: ctx.orgId, on: req.db)
        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: ctx.orgId,
            channels: ["conversation:\(message.$conversation.id.uuidString)"],
            type: "message.updated",
            entityId: messageID,
            payload: [
                "conversationId": message.$conversation.id.uuidString,
                "messageId": messageID.uuidString
            ]
        )
        return .success(dto)
    }

    @Sendable
    func deleteMessage(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let messageID = try req.parameters.require("messageID", as: UUID.self)

        guard let message = try await MessageModel.query(on: req.db)
            .filter(\.$id == messageID)
            .with(\.$sender)
            .first() else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        guard message.$sender.id == ctx.userId else {
            throw Abort(.forbidden, reason: "Cannot delete someone else's message.")
        }

        _ = try await requireMembership(conversationID: message.$conversation.id, userId: ctx.userId, on: req.db)

        message.deletedAt = Date()
        try await message.save(on: req.db)

        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: ctx.orgId,
            channels: ["conversation:\(message.$conversation.id.uuidString)"],
            type: "message.deleted",
            entityId: messageID,
            payload: [
                "conversationId": message.$conversation.id.uuidString,
                "messageId": messageID.uuidString
            ]
        )

        return .success(EmptyResponse())
    }

    private func requireMembership(conversationID: UUID, userId: UUID, on db: Database) async throws -> ConversationMemberModel {
        guard let membership = try await ConversationMemberModel.query(on: db)
            .filter(\.$conversation.$id == conversationID)
            .filter(\.$user.$id == userId)
            .first() else {
            throw Abort(.forbidden, reason: "Not a member of this conversation.")
        }
        return membership
    }

    private func buildMessageDTO(message: MessageModel, orgId: UUID, on db: Database) async throws -> MessageDTO {
        let messageID = try message.requireID()
        let replyCount = try await MessageModel.query(on: db)
            .filter(\.$parent.$id == messageID)
            .filter(\.$deletedAt == nil)
            .count()

        let threadPreview = try await MessageModel.query(on: db)
            .filter(\.$parent.$id == messageID)
            .filter(\.$deletedAt == nil)
            .sort(\.$createdAt, .descending)
            .first()

        return MessageDTO(
            id: messageID,
            conversationId: message.$conversation.id,
            senderId: message.$sender.id,
            senderName: message.sender.displayName,
            body: message.body,
            messageType: message.messageType,
            parentId: message.$parent.id,
            replyCount: replyCount,
            threadPreviewText: threadPreview?.body,
            linkedTask: try await resolveTaskPreview(from: message.body, orgId: orgId, on: db),
            editedAt: message.editedAt,
            deletedAt: message.deletedAt,
            createdAt: message.createdAt
        )
    }

    private func resolveTaskPreview(from body: String, orgId: UUID, on db: Database) async throws -> TaskPreviewDTO? {
        guard let issueKey = firstIssueKey(in: body) else { return nil }

        guard let task = try await TaskItemModel.query(on: db)
            .filter(\.$organization.$id == orgId)
            .filter(\.$issueKey == issueKey)
            .with(\.$assignee)
            .first(),
              let taskID = task.id else {
            return nil
        }

        return TaskPreviewDTO(
            taskId: taskID,
            issueKey: task.issueKey,
            title: task.title,
            status: task.status.displayName,
            assigneeDisplayName: task.assignee?.displayName,
            dueDate: task.dueDate
        )
    }

    private func firstIssueKey(in body: String) -> String? {
        let pattern = #"\b[A-Z][A-Z0-9]+-\d+\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let match = regex.firstMatch(in: body, options: [], range: range),
              let matchRange = Range(match.range, in: body) else {
            return nil
        }
        return String(body[matchRange])
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        results.reserveCapacity(count)
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}
