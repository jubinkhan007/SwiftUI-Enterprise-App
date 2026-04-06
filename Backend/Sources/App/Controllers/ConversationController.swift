import Fluent
import SharedModels
import Vapor

struct ConversationController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let conversations = routes.grouped("conversations")
        conversations.post(use: create)
        conversations.get(use: list)
        conversations.get(":conversationID", use: show)
        conversations.put(":conversationID", use: update)
        conversations.post(":conversationID", "read", use: markRead)
        conversations.post(":conversationID", "typing", use: sendTypingIndicator)
        conversations.post(":conversationID", "archive", use: archive)
        conversations.post(":conversationID", "leave", use: leave)
        conversations.post(":conversationID", "members", use: addMembers)
        conversations.delete(":conversationID", "members", ":memberID", use: removeMember)
        conversations.post(":conversationID", "preferences", use: updatePreferences)
    }

    @Sendable
    func create(req: Request) async throws -> APIResponse<ConversationDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(CreateConversationRequest.self)

        guard payload.type == "direct" else {
            throw Abort(.badRequest, reason: "Only direct messages are supported in this version.")
        }

        guard payload.memberIds.count == 1 else {
            throw Abort(.badRequest, reason: "DM requires exactly one other member ID.")
        }

        let otherUserId = payload.memberIds[0]
        guard otherUserId != ctx.userId else {
            throw Abort(.badRequest, reason: "Cannot create a DM with yourself.")
        }

        let isMember = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$user.$id == otherUserId)
            .count() > 0
        guard isMember else {
            throw Abort(.notFound, reason: "User not found in this organization.")
        }

        let existingConvIds = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$user.$id == ctx.userId)
            .all()
            .map(\.$conversation.id)

        if !existingConvIds.isEmpty {
            let match = try await ConversationModel.query(on: req.db)
                .filter(\.$id ~~ existingConvIds)
                .filter(\.$type == "direct")
                .filter(\.$organization.$id == ctx.orgId)
                .join(ConversationMemberModel.self, on: \ConversationMemberModel.$conversation.$id == \ConversationModel.$id)
                .filter(ConversationMemberModel.self, \.$user.$id == otherUserId)
                .first()

            if let existing = match {
                return .success(try await conversationDTO(for: existing, currentUserId: ctx.userId, on: req.db))
            }
        }

        let conversation = ConversationModel(
            type: "direct",
            name: payload.name,
            description: payload.description,
            topic: payload.topic,
            createdBy: ctx.userId,
            ownerId: ctx.userId,
            orgId: ctx.orgId
        )
        try await conversation.save(on: req.db)
        let conversationID = try conversation.requireID()

        let ownerMembership = ConversationMemberModel(conversationId: conversationID, userId: ctx.userId, role: "admin")
        ownerMembership.lastSeenAt = Date()
        let peerMembership = ConversationMemberModel(conversationId: conversationID, userId: otherUserId, role: "member")
        try await ownerMembership.save(on: req.db)
        try await peerMembership.save(on: req.db)

        return .success(try await conversationDTO(for: conversation, currentUserId: ctx.userId, on: req.db))
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<[ConversationListItemDTO]> {
        let ctx = try req.orgContext
        let memberships = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$user.$id == ctx.userId)
            .all()

        let conversationIds = memberships.map(\.$conversation.id)
        guard !conversationIds.isEmpty else { return .success([]) }

        let searchQuery = try? req.query.get(String.self, at: "search")
        let conversations = try await ConversationModel.query(on: req.db)
            .filter(\.$id ~~ conversationIds)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$isArchived == false)
            .sort(\.$lastMessageAt, .descending)
            .all()

        var items: [ConversationListItemDTO] = []
        for conversation in conversations {
            let conversationID = try conversation.requireID()
            let membership = memberships.first(where: { $0.$conversation.id == conversationID })

            var displayName = conversation.name
            if conversation.type == "direct" {
                let otherMember = try await ConversationMemberModel.query(on: req.db)
                    .filter(\.$conversation.$id == conversationID)
                    .filter(\.$user.$id != ctx.userId)
                    .with(\.$user)
                    .first()
                displayName = otherMember?.user.displayName
            }

            if let search = searchQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty {
                if !(displayName?.localizedCaseInsensitiveContains(search) ?? false) {
                    continue
                }
            }

            let lastMessage = try await MessageModel.query(on: req.db)
                .filter(\.$conversation.$id == conversationID)
                .filter(\.$parent.$id == nil)
                .sort(\.$createdAt, .descending)
                .with(\.$sender)
                .first()

            let unreadCount: Int
            if let lastReadAt = membership?.lastReadAt {
                unreadCount = try await MessageModel.query(on: req.db)
                    .filter(\.$conversation.$id == conversationID)
                    .filter(\.$parent.$id == nil)
                    .filter(\.$createdAt > lastReadAt)
                    .filter(\.$sender.$id != ctx.userId)
                    .filter(\.$deletedAt == nil)
                    .count()
            } else {
                unreadCount = try await MessageModel.query(on: req.db)
                    .filter(\.$conversation.$id == conversationID)
                    .filter(\.$parent.$id == nil)
                    .filter(\.$sender.$id != ctx.userId)
                    .filter(\.$deletedAt == nil)
                    .count()
            }

            let lastMessageDTO = try await lastMessage.flatMapAsync { message in
                try await self.messageDTO(for: message, on: req.db)
            }

            items.append(
                ConversationListItemDTO(
                    id: conversationID,
                    type: conversation.type,
                    name: displayName,
                    lastMessage: lastMessageDTO,
                    unreadCount: unreadCount,
                    lastMessageAt: conversation.lastMessageAt
                )
            )
        }

        return .success(items)
    }

    @Sendable
    func show(req: Request) async throws -> APIResponse<ConversationDTO> {
        let ctx = try req.orgContext
        let conversation = try await fetchAndAuthorize(
            conversationID: try req.parameters.require("conversationID", as: UUID.self),
            userId: ctx.userId,
            orgId: ctx.orgId,
            on: req.db
        )
        return .success(try await conversationDTO(for: conversation, currentUserId: ctx.userId, on: req.db))
    }

    @Sendable
    func update(req: Request) async throws -> APIResponse<ConversationDTO> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let payload = try req.content.decode(UpdateConversationRequest.self)

        let conversation = try await fetchAndAuthorize(conversationID: conversationID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        let membership = try await requireMembership(conversationID: conversationID, userId: ctx.userId, on: req.db)
        try requireManagementAccess(conversation: conversation, membership: membership, userId: ctx.userId)

        conversation.name = payload.name ?? conversation.name
        conversation.description = payload.description ?? conversation.description
        conversation.topic = payload.topic ?? conversation.topic
        try await conversation.save(on: req.db)

        return .success(try await conversationDTO(for: conversation, currentUserId: ctx.userId, on: req.db))
    }

    @Sendable
    func markRead(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let payload = try? req.content.decode(MarkReadRequest.self)

        let membership = try await requireMembership(conversationID: conversationID, userId: ctx.userId, on: req.db)
        membership.lastReadAt = Date()
        membership.lastSeenAt = Date()
        if let lastReadMessageID = payload?.lastReadMessageId {
            membership.lastReadMessageId = lastReadMessageID
        }
        try await membership.save(on: req.db)

        return .success(EmptyResponse())
    }

    @Sendable
    func sendTypingIndicator(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)

        _ = try await requireMembership(conversationID: conversationID, userId: ctx.userId, on: req.db)

        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: ctx.orgId,
            channels: ["conversation:\(conversationID.uuidString)"],
            type: "conversation.typing_started",
            entityId: ctx.userId,
            payload: [
                "conversationId": conversationID.uuidString,
                "userId": ctx.userId.uuidString
            ]
        )

        return .success(EmptyResponse())
    }

    @Sendable
    func archive(req: Request) async throws -> APIResponse<ConversationDTO> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let conversation = try await fetchAndAuthorize(conversationID: conversationID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        let membership = try await requireMembership(conversationID: conversationID, userId: ctx.userId, on: req.db)
        try requireManagementAccess(conversation: conversation, membership: membership, userId: ctx.userId)

        conversation.isArchived = true
        try await conversation.save(on: req.db)

        return .success(try await conversationDTO(for: conversation, currentUserId: ctx.userId, on: req.db))
    }

    @Sendable
    func leave(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let conversation = try await fetchAndAuthorize(conversationID: conversationID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)

        if conversation.$owner.id == ctx.userId {
            throw Abort(.badRequest, reason: "The owner cannot leave without transferring ownership.")
        }

        let membership = try await requireMembership(conversationID: conversationID, userId: ctx.userId, on: req.db)
        try await membership.delete(on: req.db)
        return .success(EmptyResponse())
    }

    @Sendable
    func addMembers(req: Request) async throws -> APIResponse<ConversationDTO> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let payload = try req.content.decode(AddConversationMembersRequest.self)
        guard !payload.memberIds.isEmpty else {
            throw Abort(.badRequest, reason: "At least one member is required.")
        }

        let conversation = try await fetchAndAuthorize(conversationID: conversationID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        let membership = try await requireMembership(conversationID: conversationID, userId: ctx.userId, on: req.db)
        try requireManagementAccess(conversation: conversation, membership: membership, userId: ctx.userId)

        for memberId in Set(payload.memberIds) where memberId != ctx.userId {
            let orgMemberExists = try await OrganizationMemberModel.query(on: req.db)
                .filter(\.$organization.$id == ctx.orgId)
                .filter(\.$user.$id == memberId)
                .count() > 0
            guard orgMemberExists else { continue }

            let exists = try await ConversationMemberModel.query(on: req.db)
                .filter(\.$conversation.$id == conversationID)
                .filter(\.$user.$id == memberId)
                .count() > 0
            guard !exists else { continue }

            try await ConversationMemberModel(
                conversationId: conversationID,
                userId: memberId,
                role: "member"
            ).save(on: req.db)
        }

        return .success(try await conversationDTO(for: conversation, currentUserId: ctx.userId, on: req.db))
    }

    @Sendable
    func removeMember(req: Request) async throws -> APIResponse<ConversationDTO> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let memberID = try req.parameters.require("memberID", as: UUID.self)
        let conversation = try await fetchAndAuthorize(conversationID: conversationID, userId: ctx.userId, orgId: ctx.orgId, on: req.db)
        let membership = try await requireMembership(conversationID: conversationID, userId: ctx.userId, on: req.db)
        try requireManagementAccess(conversation: conversation, membership: membership, userId: ctx.userId)

        if conversation.$owner.id == memberID {
            throw Abort(.badRequest, reason: "The owner cannot be removed from the channel.")
        }

        guard let targetMembership = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$conversation.$id == conversationID)
            .filter(\.$user.$id == memberID)
            .first() else {
            throw Abort(.notFound, reason: "Member not found.")
        }

        try await targetMembership.delete(on: req.db)
        return .success(try await conversationDTO(for: conversation, currentUserId: ctx.userId, on: req.db))
    }

    @Sendable
    func updatePreferences(req: Request) async throws -> APIResponse<ConversationMemberDTO> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let payload = try req.content.decode(UpdateConversationMemberPreferencesRequest.self)
        let membership = try await requireMembership(conversationID: conversationID, userId: ctx.userId, on: req.db)
        try await membership.$user.load(on: req.db)

        if let notificationPreference = payload.notificationPreference {
            membership.notificationPreference = notificationPreference
        }
        if let isMuted = payload.isMuted {
            membership.isMuted = isMuted
        }
        membership.lastSeenAt = Date()
        try await membership.save(on: req.db)

        guard let dto = memberDTO(for: membership) else {
            throw Abort(.internalServerError, reason: "Failed to serialize conversation membership.")
        }
        return .success(dto)
    }

    private func fetchAndAuthorize(conversationID: UUID, userId: UUID, orgId: UUID, on db: Database) async throws -> ConversationModel {
        guard let conversation = try await ConversationModel.query(on: db)
            .filter(\.$id == conversationID)
            .filter(\.$organization.$id == orgId)
            .first() else {
            throw Abort(.notFound, reason: "Conversation not found.")
        }

        let isMember = try await ConversationMemberModel.query(on: db)
            .filter(\.$conversation.$id == conversationID)
            .filter(\.$user.$id == userId)
            .count() > 0
        guard isMember else {
            throw Abort(.forbidden, reason: "Not a member of this conversation.")
        }
        return conversation
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

    private func requireManagementAccess(conversation: ConversationModel, membership: ConversationMemberModel, userId: UUID) throws {
        let normalizedRole = membership.role.lowercased()
        if normalizedRole == "admin" || conversation.$owner.id == userId {
            return
        }
        throw Abort(.forbidden, reason: "Insufficient permissions for channel management.")
    }

    private func conversationDTO(for conversation: ConversationModel, currentUserId: UUID, on db: Database) async throws -> ConversationDTO {
        let conversationID = try conversation.requireID()
        let members = try await ConversationMemberModel.query(on: db)
            .filter(\.$conversation.$id == conversationID)
            .with(\.$user)
            .all()

        let memberDTOs = members.compactMap(memberDTO(for:))
        return ConversationDTO(
            id: conversationID,
            type: conversation.type,
            name: conversation.name,
            description: conversation.description,
            topic: conversation.topic,
            isArchived: conversation.isArchived,
            ownerId: conversation.$owner.id,
            lastMessageAt: conversation.lastMessageAt,
            createdAt: conversation.createdAt,
            members: memberDTOs
        )
    }

    private func memberDTO(for membership: ConversationMemberModel) -> ConversationMemberDTO? {
        guard let id = membership.id else { return nil }
        return ConversationMemberDTO(
            id: id,
            userId: membership.$user.id,
            displayName: membership.user.displayName,
            role: membership.role,
            notificationPreference: membership.notificationPreference,
            lastReadAt: membership.lastReadAt,
            lastSeenAt: membership.lastSeenAt,
            isMuted: membership.isMuted
        )
    }

    private func messageDTO(for message: MessageModel, on db: Database) async throws -> MessageDTO {
        let messageID = try message.requireID()
        let replyCount = try await MessageModel.query(on: db)
            .filter(\.$parent.$id == messageID)
            .filter(\.$deletedAt == nil)
            .count()

        let latestReply = try await MessageModel.query(on: db)
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
            threadPreviewText: latestReply?.body,
            linkedTask: nil,
            editedAt: message.editedAt,
            deletedAt: message.deletedAt,
            createdAt: message.createdAt
        )
    }
}

private extension Optional {
    func flatMapAsync<T>(_ transform: (Wrapped) async throws -> T) async rethrows -> T? {
        guard let value = self else { return nil }
        return try await transform(value)
    }
}
