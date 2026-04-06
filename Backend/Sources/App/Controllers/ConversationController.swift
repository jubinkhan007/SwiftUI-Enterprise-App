import Fluent
import SharedModels
import Vapor

/// Handles conversation CRUD — DM creation (find-or-create), listing with unread counts, and mark-read.
struct ConversationController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let conversations = routes.grouped("conversations")
        conversations.post(use: create)
        conversations.get(use: list)
        conversations.get(":conversationID", use: show)
        conversations.post(":conversationID", "read", use: markRead)
    }

    // MARK: - POST /api/conversations

    /// Create a new DM conversation. For DMs, find-or-create to prevent duplicate pairs.
    @Sendable
    func create(req: Request) async throws -> APIResponse<ConversationDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(CreateConversationRequest.self)

        guard payload.type == "direct" else {
            // Groups/channels deferred to Phase 2
            throw Abort(.badRequest, reason: "Only direct messages are supported in this version.")
        }

        guard payload.memberIds.count == 1 else {
            throw Abort(.badRequest, reason: "DM requires exactly one other member ID.")
        }

        let otherUserId = payload.memberIds[0]
        guard otherUserId != ctx.userId else {
            throw Abort(.badRequest, reason: "Cannot create a DM with yourself.")
        }

        // Verify the other user is in the same org
        let isMember = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$user.$id == otherUserId)
            .count() > 0
        guard isMember else {
            throw Abort(.notFound, reason: "User not found in this organization.")
        }

        // Find existing DM between these two users in this org
        let existingConvIds = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$user.$id == ctx.userId)
            .all()
            .map { $0.$conversation.id }

        if !existingConvIds.isEmpty {
            let match = try await ConversationModel.query(on: req.db)
                .filter(\.$id ~~ existingConvIds)
                .filter(\.$type == "direct")
                .filter(\.$organization.$id == ctx.orgId)
                .join(ConversationMemberModel.self, on: \ConversationMemberModel.$conversation.$id == \ConversationModel.$id)
                .filter(ConversationMemberModel.self, \.$user.$id == otherUserId)
                .first()

            if let existing = match {
                let dto = try await conversationDTO(for: existing, currentUserId: ctx.userId, on: req.db)
                return .success(dto)
            }
        }

        // Create new DM
        let conversation = ConversationModel(
            type: "direct",
            createdBy: ctx.userId,
            orgId: ctx.orgId
        )
        try await conversation.save(on: req.db)
        let convId = try conversation.requireID()

        // Add both members
        let member1 = ConversationMemberModel(conversationId: convId, userId: ctx.userId, role: "admin")
        let member2 = ConversationMemberModel(conversationId: convId, userId: otherUserId, role: "member")
        try await member1.save(on: req.db)
        try await member2.save(on: req.db)

        let dto = try await conversationDTO(for: conversation, currentUserId: ctx.userId, on: req.db)
        return .success(dto)
    }

    // MARK: - GET /api/conversations

    /// List all conversations for the current user, with last message preview and unread count.
    @Sendable
    func list(req: Request) async throws -> APIResponse<[ConversationListItemDTO]> {
        let ctx = try req.orgContext

        // Get all conversation IDs the user is a member of
        let memberships = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$user.$id == ctx.userId)
            .all()

        let conversationIds = memberships.map { $0.$conversation.id }
        guard !conversationIds.isEmpty else {
            return .success([])
        }

        let conversations = try await ConversationModel.query(on: req.db)
            .filter(\.$id ~~ conversationIds)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$isArchived == false)
            .sort(\.$lastMessageAt, .descending)
            .all()

        var items: [ConversationListItemDTO] = []
        for conv in conversations {
            let convId = try conv.requireID()
            let membership = memberships.first(where: { $0.$conversation.id == convId })

            // Last message (non-deleted)
            let lastMessage = try await MessageModel.query(on: req.db)
                .filter(\.$conversation.$id == convId)
                .filter(\.$deletedAt == nil)
                .sort(\.$createdAt, .descending)
                .with(\.$sender)
                .first()

            // Unread count
            let unreadCount: Int
            if let lastReadAt = membership?.lastReadAt {
                unreadCount = try await MessageModel.query(on: req.db)
                    .filter(\.$conversation.$id == convId)
                    .filter(\.$createdAt > lastReadAt)
                    .filter(\.$sender.$id != ctx.userId)
                    .filter(\.$deletedAt == nil)
                    .count()
            } else {
                unreadCount = try await MessageModel.query(on: req.db)
                    .filter(\.$conversation.$id == convId)
                    .filter(\.$sender.$id != ctx.userId)
                    .filter(\.$deletedAt == nil)
                    .count()
            }

            // For DMs, resolve the other user's name
            var displayName = conv.name
            if conv.type == "direct" {
                let otherMember = try await ConversationMemberModel.query(on: req.db)
                    .filter(\.$conversation.$id == convId)
                    .filter(\.$user.$id != ctx.userId)
                    .with(\.$user)
                    .first()
                displayName = otherMember?.user.displayName
            }

            let lastMessageDTO: MessageDTO? = lastMessage.map { msg in
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

            items.append(ConversationListItemDTO(
                id: convId,
                type: conv.type,
                name: displayName,
                lastMessage: lastMessageDTO,
                unreadCount: unreadCount,
                lastMessageAt: conv.lastMessageAt
            ))
        }

        return .success(items)
    }

    // MARK: - GET /api/conversations/:conversationID

    @Sendable
    func show(req: Request) async throws -> APIResponse<ConversationDTO> {
        let ctx = try req.orgContext
        guard let convId = req.parameters.get("conversationID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID.")
        }

        let conv = try await fetchAndAuthorize(convId: convId, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        let dto = try await conversationDTO(for: conv, currentUserId: ctx.userId, on: req.db)
        return .success(dto)
    }

    // MARK: - POST /api/conversations/:conversationID/read

    @Sendable
    func markRead(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        guard let convId = req.parameters.get("conversationID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid conversation ID.")
        }

        let payload = try? req.content.decode(MarkReadRequest.self)

        guard let membership = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$conversation.$id == convId)
            .filter(\.$user.$id == ctx.userId)
            .first()
        else {
            throw Abort(.notFound, reason: "Not a member of this conversation.")
        }

        membership.lastReadAt = Date()
        if let messageId = payload?.lastReadMessageId {
            membership.lastReadMessageId = messageId
        }
        try await membership.save(on: req.db)

        return .success(EmptyResponse())
    }

    // MARK: - Helpers

    private func fetchAndAuthorize(convId: UUID, userId: UUID, orgId: UUID, on db: Database) async throws -> ConversationModel {
        guard let conv = try await ConversationModel.query(on: db)
            .filter(\.$id == convId)
            .filter(\.$organization.$id == orgId)
            .first()
        else {
            throw Abort(.notFound, reason: "Conversation not found.")
        }

        let isMember = try await ConversationMemberModel.query(on: db)
            .filter(\.$conversation.$id == convId)
            .filter(\.$user.$id == userId)
            .count() > 0
        guard isMember else {
            throw Abort(.forbidden, reason: "Not a member of this conversation.")
        }

        return conv
    }

    private func conversationDTO(for conv: ConversationModel, currentUserId: UUID, on db: Database) async throws -> ConversationDTO {
        let convId = try conv.requireID()
        let memberRows = try await ConversationMemberModel.query(on: db)
            .filter(\.$conversation.$id == convId)
            .with(\.$user)
            .all()

        let memberDTOs = memberRows.compactMap { m -> ConversationMemberDTO? in
            guard let id = m.id else { return nil }
            return ConversationMemberDTO(
                id: id,
                userId: m.$user.id,
                displayName: m.user.displayName,
                role: m.role,
                lastReadAt: m.lastReadAt
            )
        }

        return ConversationDTO(
            id: convId,
            type: conv.type,
            name: conv.name,
            isArchived: conv.isArchived,
            lastMessageAt: conv.lastMessageAt,
            createdAt: conv.createdAt,
            members: memberDTOs
        )
    }
}
