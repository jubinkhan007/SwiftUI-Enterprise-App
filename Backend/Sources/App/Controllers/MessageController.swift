import Fluent
import SharedModels
import Vapor

/// Handles message history retrieval and sending new messages.
struct MessageController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let conversations = routes.grouped("conversations")
        conversations.get(":conversationID", "messages", use: listMessages)
        conversations.post(":conversationID", "messages", use: sendMessage)
        
        let messages = routes.grouped("messages")
        messages.put(":messageID", use: editMessage)
        messages.delete(":messageID", use: deleteMessage)
    }

    // MARK: - GET /api/conversations/:conversationID/messages

    /// Paginated message history. Returns newest first. Supports cursor-based pagination.
    @Sendable
    func listMessages(req: Request) async throws -> APIResponse<[MessageDTO]> {
        let ctx = try req.orgContext
        guard let convId = req.parameters.get("conversationID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID.")
        }

        // Verify membership
        let isMember = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$conversation.$id == convId)
            .filter(\.$user.$id == ctx.userId)
            .count() > 0
        guard isMember else {
            throw Abort(.forbidden, reason: "Not a member of this conversation.")
        }

        let limit = min((try? req.query.get(Int.self, at: "limit")) ?? 50, 100)
        let cursor: UUID? = try? req.query.get(UUID.self, at: "cursor")

        var query = MessageModel.query(on: req.db)
            .filter(\.$conversation.$id == convId)
            .with(\.$sender)
            .sort(\.$createdAt, .descending)
            .limit(limit)

        // Cursor: fetch messages older than the cursor message
        if let cursor {
            if let cursorMsg = try await MessageModel.find(cursor, on: req.db) {
                if let cursorDate = cursorMsg.createdAt {
                    query = query.filter(\.$createdAt < cursorDate)
                }
            }
        }

        let messages = try await query.all()

        let dtos = messages.map { msg in
            MessageDTO(
                id: msg.id ?? UUID(),
                conversationId: msg.$conversation.id,
                senderId: msg.$sender.id,
                senderName: msg.sender.displayName,
                body: msg.body,
                messageType: msg.messageType,
                editedAt: msg.editedAt,
                deletedAt: msg.deletedAt,
                createdAt: msg.createdAt
            )
        }

        return .success(dtos)
    }

    // MARK: - POST /api/conversations/:conversationID/messages

    /// Send a new message. Updates lastMessageAt on the conversation and broadcasts via WebSocket.
    @Sendable
    func sendMessage(req: Request) async throws -> APIResponse<MessageDTO> {
        let ctx = try req.orgContext
        guard let convId = req.parameters.get("conversationID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID.")
        }

        let payload = try req.content.decode(SendMessageRequest.self)

        guard !payload.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Message body cannot be empty.")
        }

        // Verify membership
        let isMember = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$conversation.$id == convId)
            .filter(\.$user.$id == ctx.userId)
            .count() > 0
        guard isMember else {
            throw Abort(.forbidden, reason: "Not a member of this conversation.")
        }

        // Create the message
        let message = MessageModel(
            conversationId: convId,
            senderId: ctx.userId,
            body: payload.body,
            messageType: payload.messageType ?? "text"
        )
        try await message.save(on: req.db)

        // Update conversation's lastMessageAt
        if let conv = try await ConversationModel.find(convId, on: req.db) {
            conv.lastMessageAt = message.createdAt ?? Date()
            try await conv.save(on: req.db)
        }

        // Auto-update sender's read marker
        if let membership = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$conversation.$id == convId)
            .filter(\.$user.$id == ctx.userId)
            .first()
        {
            membership.lastReadAt = message.createdAt ?? Date()
            membership.lastReadMessageId = message.id
            try await membership.save(on: req.db)
        }

        // Load sender for DTO
        let sender = try await UserModel.find(ctx.userId, on: req.db)

        let dto = MessageDTO(
            id: try message.requireID(),
            conversationId: convId,
            senderId: ctx.userId,
            senderName: sender?.displayName ?? "Unknown",
            body: message.body,
            messageType: message.messageType,
            editedAt: nil,
            deletedAt: nil,
            createdAt: message.createdAt
        )

        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: ctx.orgId,
            channels: ["conversation:\(convId.uuidString)"],
            type: "message.new",
            entityId: dto.id,
            payload: [
                "conversationId": convId.uuidString,
                "messageId": dto.id.uuidString,
                "senderId": dto.senderId.uuidString
            ]
        )

        return .success(dto)
    }

    // MARK: - PUT /api/messages/:messageID

    @Sendable
    func editMessage(req: Request) async throws -> APIResponse<MessageDTO> {
        let ctx = try req.orgContext
        guard let messageId = req.parameters.get("messageID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid message ID.")
        }
        let payload = try req.content.decode(EditMessageRequest.self)
        guard !payload.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Message body cannot be empty.")
        }

        guard let message = try await MessageModel.query(on: req.db)
            .filter(\.$id == messageId)
            .with(\.$sender)
            .first() else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        guard message.$sender.id == ctx.userId else {
            throw Abort(.forbidden, reason: "Cannot edit someone else's message.")
        }

        message.body = payload.body
        message.editedAt = Date()
        try await message.save(on: req.db)

        let dto = MessageDTO(
            id: messageId,
            conversationId: message.$conversation.id,
            senderId: message.$sender.id,
            senderName: message.sender.displayName,
            body: message.body,
            messageType: message.messageType,
            editedAt: message.editedAt,
            deletedAt: message.deletedAt,
            createdAt: message.createdAt
        )

        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: ctx.orgId,
            channels: ["conversation:\(message.$conversation.id.uuidString)"],
            type: "message.updated",
            entityId: messageId,
            payload: [
                "conversationId": message.$conversation.id.uuidString,
                "messageId": messageId.uuidString,
                "body": message.body,
                "editedAt": ISO8601DateFormatter().string(from: message.editedAt!)
            ]
        )

        return .success(dto)
    }

    // MARK: - DELETE /api/messages/:messageID

    @Sendable
    func deleteMessage(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        guard let messageId = req.parameters.get("messageID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid message ID.")
        }

        guard let message = try await MessageModel.query(on: req.db)
            .filter(\.$id == messageId)
            .with(\.$sender)
            .first() else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        guard message.$sender.id == ctx.userId else {
            throw Abort(.forbidden, reason: "Cannot delete someone else's message.")
        }

        message.deletedAt = Date()
        try await message.save(on: req.db)

        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: ctx.orgId,
            channels: ["conversation:\(message.$conversation.id.uuidString)"],
            type: "message.deleted",
            entityId: messageId,
            payload: [
                "conversationId": message.$conversation.id.uuidString,
                "messageId": messageId.uuidString,
                "deletedAt": ISO8601DateFormatter().string(from: message.deletedAt!)
            ]
        )

        return .success(EmptyResponse())
    }
}
