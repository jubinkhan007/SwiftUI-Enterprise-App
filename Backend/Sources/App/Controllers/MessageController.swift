import Fluent
import SharedModels
import Vapor

struct MessageController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let conversations = routes.grouped("conversations")
        conversations.get(":conversationID", "messages", use: listMessages)
        conversations.post(":conversationID", "messages", use: sendMessage)
        conversations.get(":conversationID", "pins", use: listPins)

        let messages = routes.grouped("messages")
        messages.get(":messageID", "thread", use: getThread)
        messages.put(":messageID", use: editMessage)
        messages.delete(":messageID", use: deleteMessage)

        // Reactions
        messages.post(":messageID", "reactions", use: addReaction)
        messages.delete(":messageID", "reactions", ":emoji", use: removeReaction)

        // Pins
        messages.post(":messageID", "pin", use: pinMessage)
        messages.delete(":messageID", "pin", use: unpinMessage)

        // Bookmarks
        messages.post(":messageID", "bookmark", use: bookmarkMessage)
        messages.delete(":messageID", "bookmark", use: unbookmarkMessage)

        // Message -> task
        messages.post(":messageID", "convert-to-task", use: convertToTask)

        // Per-user bookmark list (org-scoped)
        let me = routes.grouped("me")
        me.get("bookmarks", use: listMyBookmarks)

        // Global search (org-scoped)
        routes.get("search", use: search)
    }

    // MARK: - Read

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
            try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)
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
            rootMessage: try await buildMessageDTO(message: rootMessage, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db),
            replies: try await replies.asyncMap { reply in
                try await buildMessageDTO(message: reply, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)
            }
        )
        return .success(bundle)
    }

    // MARK: - Write

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

        // Clear the matching draft (best-effort, post-write).
        await DraftController.clearAfterSend(
            userId: ctx.userId,
            conversationId: conversationID,
            parentId: payload.parentId,
            on: req.db
        )

        try await message.$sender.load(on: req.db)
        let dto = try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)

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

        let dto = try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)
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

    // MARK: - Reactions

    @Sendable
    func addReaction(req: Request) async throws -> APIResponse<MessageDTO> {
        let ctx = try req.orgContext
        let messageID = try req.parameters.require("messageID", as: UUID.self)
        let payload = try req.content.decode(ReactionRequest.self)

        let emoji = payload.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !emoji.isEmpty, emoji.count <= 16 else {
            throw Abort(.badRequest, reason: "Invalid emoji.")
        }

        guard let message = try await MessageModel.find(messageID, on: req.db) else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        _ = try await requireMembership(conversationID: message.$conversation.id, userId: ctx.userId, on: req.db)

        // Idempotent: only insert if not already there.
        let existing = try await MessageReactionModel.query(on: req.db)
            .filter(\.$message.$id == messageID)
            .filter(\.$user.$id == ctx.userId)
            .filter(\.$emoji == emoji)
            .first()

        if existing == nil {
            let reaction = MessageReactionModel(messageId: messageID, userId: ctx.userId, emoji: emoji)
            try await reaction.save(on: req.db)
        }

        try await message.$sender.load(on: req.db)
        let dto = try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)

        broadcastMessageUpdated(req: req, orgId: ctx.orgId, message: message, eventType: "message.reaction_added", extra: ["emoji": emoji])

        return .success(dto)
    }

    @Sendable
    func removeReaction(req: Request) async throws -> APIResponse<MessageDTO> {
        let ctx = try req.orgContext
        let messageID = try req.parameters.require("messageID", as: UUID.self)
        guard let emojiRaw = req.parameters.get("emoji"),
              let emoji = emojiRaw.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
              !emoji.isEmpty else {
            throw Abort(.badRequest, reason: "Missing emoji.")
        }

        guard let message = try await MessageModel.find(messageID, on: req.db) else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        _ = try await requireMembership(conversationID: message.$conversation.id, userId: ctx.userId, on: req.db)

        try await MessageReactionModel.query(on: req.db)
            .filter(\.$message.$id == messageID)
            .filter(\.$user.$id == ctx.userId)
            .filter(\.$emoji == emoji)
            .delete()

        try await message.$sender.load(on: req.db)
        let dto = try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)

        broadcastMessageUpdated(req: req, orgId: ctx.orgId, message: message, eventType: "message.reaction_removed", extra: ["emoji": emoji])

        return .success(dto)
    }

    // MARK: - Pins

    @Sendable
    func pinMessage(req: Request) async throws -> APIResponse<MessageDTO> {
        let ctx = try req.orgContext
        let messageID = try req.parameters.require("messageID", as: UUID.self)

        guard let message = try await MessageModel.find(messageID, on: req.db) else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        _ = try await requireMembership(conversationID: message.$conversation.id, userId: ctx.userId, on: req.db)

        let existing = try await MessagePinModel.query(on: req.db)
            .filter(\.$message.$id == messageID)
            .first()

        if existing == nil {
            let pin = MessagePinModel(
                messageId: messageID,
                conversationId: message.$conversation.id,
                pinnedBy: ctx.userId
            )
            try await pin.save(on: req.db)
        }

        try await message.$sender.load(on: req.db)
        let dto = try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)
        broadcastMessageUpdated(req: req, orgId: ctx.orgId, message: message, eventType: "message.pinned")
        return .success(dto)
    }

    @Sendable
    func unpinMessage(req: Request) async throws -> APIResponse<MessageDTO> {
        let ctx = try req.orgContext
        let messageID = try req.parameters.require("messageID", as: UUID.self)

        guard let message = try await MessageModel.find(messageID, on: req.db) else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        _ = try await requireMembership(conversationID: message.$conversation.id, userId: ctx.userId, on: req.db)

        try await MessagePinModel.query(on: req.db)
            .filter(\.$message.$id == messageID)
            .delete()

        try await message.$sender.load(on: req.db)
        let dto = try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)
        broadcastMessageUpdated(req: req, orgId: ctx.orgId, message: message, eventType: "message.unpinned")
        return .success(dto)
    }

    @Sendable
    func listPins(req: Request) async throws -> APIResponse<[MessageDTO]> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        _ = try await requireMembership(conversationID: conversationID, userId: ctx.userId, on: req.db)

        let pins = try await MessagePinModel.query(on: req.db)
            .filter(\.$conversation.$id == conversationID)
            .sort(\.$createdAt, .descending)
            .all()

        let messageIds = pins.map { $0.$message.id }
        let messages = try await MessageModel.query(on: req.db)
            .filter(\.$id ~~ messageIds)
            .filter(\.$deletedAt == nil)
            .with(\.$sender)
            .all()

        let orderedMessages: [MessageModel] = messageIds.compactMap { id in
            messages.first { $0.id == id }
        }

        let dtos = try await orderedMessages.asyncMap { msg in
            try await buildMessageDTO(message: msg, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)
        }
        return .success(dtos)
    }

    // MARK: - Bookmarks

    @Sendable
    func bookmarkMessage(req: Request) async throws -> APIResponse<MessageDTO> {
        let ctx = try req.orgContext
        let messageID = try req.parameters.require("messageID", as: UUID.self)

        guard let message = try await MessageModel.find(messageID, on: req.db) else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        _ = try await requireMembership(conversationID: message.$conversation.id, userId: ctx.userId, on: req.db)

        let existing = try await MessageBookmarkModel.query(on: req.db)
            .filter(\.$message.$id == messageID)
            .filter(\.$user.$id == ctx.userId)
            .first()

        if existing == nil {
            let bookmark = MessageBookmarkModel(messageId: messageID, userId: ctx.userId)
            try await bookmark.save(on: req.db)
        }

        try await message.$sender.load(on: req.db)
        let dto = try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)
        return .success(dto)
    }

    @Sendable
    func unbookmarkMessage(req: Request) async throws -> APIResponse<MessageDTO> {
        let ctx = try req.orgContext
        let messageID = try req.parameters.require("messageID", as: UUID.self)

        guard let message = try await MessageModel.find(messageID, on: req.db) else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        _ = try await requireMembership(conversationID: message.$conversation.id, userId: ctx.userId, on: req.db)

        try await MessageBookmarkModel.query(on: req.db)
            .filter(\.$message.$id == messageID)
            .filter(\.$user.$id == ctx.userId)
            .delete()

        try await message.$sender.load(on: req.db)
        let dto = try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)
        return .success(dto)
    }

    @Sendable
    func listMyBookmarks(req: Request) async throws -> APIResponse<[BookmarkDTO]> {
        let ctx = try req.orgContext

        let bookmarks = try await MessageBookmarkModel.query(on: req.db)
            .filter(\.$user.$id == ctx.userId)
            .sort(\.$createdAt, .descending)
            .all()

        let messageIds = bookmarks.map { $0.$message.id }
        let messages = try await MessageModel.query(on: req.db)
            .filter(\.$id ~~ messageIds)
            .with(\.$sender)
            .with(\.$conversation)
            .all()

        var dtos: [BookmarkDTO] = []
        dtos.reserveCapacity(bookmarks.count)
        for bookmark in bookmarks {
            guard let message = messages.first(where: { $0.id == bookmark.$message.id }) else { continue }
            // Only include messages from conversations in this org
            if message.conversation.$organization.id != ctx.orgId { continue }
            let messageDTO = try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)
            dtos.append(BookmarkDTO(
                id: try bookmark.requireID(),
                messageId: messageDTO.id,
                conversationId: message.$conversation.id,
                conversationName: message.conversation.name,
                message: messageDTO,
                createdAt: bookmark.createdAt
            ))
        }
        return .success(dtos)
    }

    // MARK: - Convert message -> task

    @Sendable
    func convertToTask(req: Request) async throws -> APIResponse<ConvertMessageToTaskResponse> {
        let ctx = try req.orgContext
        let messageID = try req.parameters.require("messageID", as: UUID.self)
        let payload = try req.content.decode(ConvertMessageToTaskRequest.self)

        guard let message = try await MessageModel.query(on: req.db)
            .filter(\.$id == messageID)
            .with(\.$sender)
            .first() else {
            throw Abort(.notFound, reason: "Message not found.")
        }
        _ = try await requireMembership(conversationID: message.$conversation.id, userId: ctx.userId, on: req.db)

        // Validate the destination list belongs to this org via its project/space.
        let listQuery = TaskListModel.query(on: req.db)
            .filter(\.$id == payload.listId)
            .with(\.$project) { project in project.with(\.$space) }
        guard let list = try await listQuery.first(),
              list.project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Target list not found.")
        }

        // Default title is first line of body, capped to 140 chars.
        let trimmedBody = message.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultTitle = trimmedBody.split(separator: "\n").first.map(String.init) ?? "Follow up on message"
        let title = payload.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? String(defaultTitle.prefix(140))
        let description = payload.description ?? trimmedBody

        let task = TaskItemModel(
            orgId: ctx.orgId,
            listId: payload.listId,
            projectId: list.$project.id,
            title: title,
            description: description,
            assigneeId: payload.assigneeId
        )
        task.dueDate = payload.dueDate

        try await req.db.transaction { db in
            task.issueKey = try await IssueKeyService.nextIssueKey(project: list.project, db: db)
            try await task.save(on: db)

            // Link the message back to the new task
            message.$linkedTask.id = task.id
            try await message.save(on: db)
        }

        try await task.$assignee.load(on: req.db)
        let messageDTO = try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)
        let taskPreview = TaskPreviewDTO(
            taskId: try task.requireID(),
            issueKey: task.issueKey,
            title: task.title,
            status: task.status.displayName,
            assigneeDisplayName: task.assignee?.displayName,
            dueDate: task.dueDate
        )

        broadcastMessageUpdated(req: req, orgId: ctx.orgId, message: message, eventType: "message.task_linked",
                                 extra: ["taskId": (try? task.requireID().uuidString) ?? ""])

        return .success(ConvertMessageToTaskResponse(task: taskPreview, message: messageDTO))
    }

    // MARK: - Helpers

    private func broadcastMessageUpdated(
        req: Request,
        orgId: UUID,
        message: MessageModel,
        eventType: String,
        extra: [String: String] = [:]
    ) {
        guard let messageId = try? message.requireID() else { return }
        var payload: [String: String] = [
            "conversationId": message.$conversation.id.uuidString,
            "messageId": messageId.uuidString
        ]
        for (k, v) in extra { payload[k] = v }
        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: orgId,
            channels: ["conversation:\(message.$conversation.id.uuidString)"],
            type: eventType,
            entityId: messageId,
            payload: payload
        )
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

    private func buildMessageDTO(
        message: MessageModel,
        orgId: UUID,
        viewerId: UUID,
        on db: Database
    ) async throws -> MessageDTO {
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

        // Reactions
        let reactionRows = try await MessageReactionModel.query(on: db)
            .filter(\.$message.$id == messageID)
            .all()
        var grouped: [String: [UUID]] = [:]
        for row in reactionRows {
            grouped[row.emoji, default: []].append(row.$user.id)
        }
        let reactions: [MessageReactionGroupDTO] = grouped
            .map { emoji, userIds in
                MessageReactionGroupDTO(
                    emoji: emoji,
                    count: userIds.count,
                    userIds: userIds,
                    didReact: userIds.contains(viewerId)
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.emoji < rhs.emoji }
                return lhs.count > rhs.count
            }

        // Pin
        let pin = try await MessagePinModel.query(on: db)
            .filter(\.$message.$id == messageID)
            .first()

        // Bookmark (viewer-scoped)
        let bookmarkExists = try await MessageBookmarkModel.query(on: db)
            .filter(\.$message.$id == messageID)
            .filter(\.$user.$id == viewerId)
            .count() > 0

        // Linked task — prefer explicit FK, else regex-resolved issue key
        let linkedTask = try await resolveLinkedTaskPreview(message: message, orgId: orgId, on: db)

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
            linkedTask: linkedTask,
            reactions: reactions,
            isPinned: pin != nil,
            pinnedBy: pin?.$pinnedBy.id,
            pinnedAt: pin?.createdAt,
            isBookmarkedByMe: bookmarkExists,
            editedAt: message.editedAt,
            deletedAt: message.deletedAt,
            createdAt: message.createdAt
        )
    }

    private func resolveLinkedTaskPreview(
        message: MessageModel,
        orgId: UUID,
        on db: Database
    ) async throws -> TaskPreviewDTO? {
        // 1. Explicit FK takes precedence
        if let linkedTaskId = message.$linkedTask.id {
            if let task = try await TaskItemModel.query(on: db)
                .filter(\.$id == linkedTaskId)
                .filter(\.$organization.$id == orgId)
                .with(\.$assignee)
                .first(),
               let taskID = task.id {
                return TaskPreviewDTO(
                    taskId: taskID,
                    issueKey: task.issueKey,
                    title: task.title,
                    status: task.status.displayName,
                    assigneeDisplayName: task.assignee?.displayName,
                    dueDate: task.dueDate
                )
            }
        }

        // 2. Fallback: detect first issue key in body
        guard let issueKey = firstIssueKey(in: message.body) else { return nil }
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

    // MARK: - Global Search

    @Sendable
    func search(req: Request) async throws -> APIResponse<[MessageSearchResultDTO]> {
        let ctx = try req.orgContext
        let queryStr = try? req.query.get(String.self, at: "q")
        let fromStr = try? req.query.get(String.self, at: "from")
        let inStr = try? req.query.get(String.self, at: "in")
        let afterStr = try? req.query.get(String.self, at: "after")

        var query = MessageModel.query(on: req.db)
            .join(ConversationModel.self, on: \MessageModel.$conversation.$id == \ConversationModel.$id)
            .join(UserModel.self, on: \MessageModel.$sender.$id == \UserModel.$id)
            .filter(ConversationModel.self, \.$organization.$id == ctx.orgId)

        if let queryStr, !queryStr.isEmpty {
            query = query.filter(\.$body ~~ queryStr)
        }

        if let fromStr, !fromStr.isEmpty {
            query = query.group(.or) { group in
                group.filter(UserModel.self, \.$displayName ~~ fromStr)
                     .filter(UserModel.self, \.$email ~~ fromStr)
            }
        }

        if let inStr, !inStr.isEmpty {
            query = query.filter(ConversationModel.self, \.$name ~~ inStr)
        }

        if let afterStr, let date = ISO8601DateFormatter().date(from: afterStr) {
            query = query.filter(\.$createdAt >= date)
        }

        let messages = try await query
            .with(\.$sender)
            .sort(\.$createdAt, .descending)
            .limit(100)
            .all()

        var results: [MessageSearchResultDTO] = []
        for message in messages {
            let conv = try message.joined(ConversationModel.self)
            let dto = try await buildMessageDTO(message: message, orgId: ctx.orgId, viewerId: ctx.userId, on: req.db)
            results.append(MessageSearchResultDTO(message: dto, conversationName: conv.name ?? "Direct Message"))
        }

        return .success(results)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
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
