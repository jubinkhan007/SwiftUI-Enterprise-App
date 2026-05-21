import Fluent
import SharedModels
import Vapor

/// Phase 4 (Productivity): per-user, per-conversation drafts.
/// One row per (user_id, conversation_id, parent_id) — see migration uniques.
struct DraftController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let conversations = routes.grouped("conversations")
        conversations.get(":conversationID", "draft", use: getDraft)
        conversations.put(":conversationID", "draft", use: upsertDraft)
        conversations.delete(":conversationID", "draft", use: deleteDraft)

        let me = routes.grouped("me")
        me.get("drafts", use: listMyDrafts)
    }

    @Sendable
    func getDraft(req: Request) async throws -> APIResponse<MessageDraftDTO> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let parentID: UUID? = try? req.query.get(UUID.self, at: "parentId")

        try await Self.requireConversationMembership(conversationId: conversationID, userId: ctx.userId, on: req.db)

        guard let row = try await Self.fetch(userId: ctx.userId, conversationId: conversationID, parentId: parentID, on: req.db) else {
            // Return an empty placeholder so clients don't have to handle 404 specially.
            return .success(MessageDraftDTO(
                id: UUID(),
                userId: ctx.userId,
                conversationId: conversationID,
                parentId: parentID,
                body: "",
                updatedAt: nil
            ))
        }
        return .success(Self.toDTO(row))
    }

    @Sendable
    func upsertDraft(req: Request) async throws -> APIResponse<MessageDraftDTO> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let payload = try req.content.decode(UpsertDraftRequest.self)

        try await Self.requireConversationMembership(conversationId: conversationID, userId: ctx.userId, on: req.db)

        let row: MessageDraftModel
        if let existing = try await Self.fetch(userId: ctx.userId, conversationId: conversationID, parentId: payload.parentId, on: req.db) {
            existing.body = payload.body
            try await existing.save(on: req.db)
            row = existing
        } else {
            let fresh = MessageDraftModel(
                userId: ctx.userId,
                conversationId: conversationID,
                parentId: payload.parentId,
                body: payload.body
            )
            try await fresh.save(on: req.db)
            row = fresh
        }

        if let id = row.id {
            RealtimeBroadcaster.broadcast(
                app: req.application,
                orgId: ctx.orgId,
                channels: ["user:\(ctx.userId.uuidString)"],
                type: "draft.updated",
                entityId: id,
                payload: [
                    "conversationId": conversationID.uuidString,
                    "parentId": payload.parentId?.uuidString ?? ""
                ]
            )
        }

        return .success(Self.toDTO(row))
    }

    @Sendable
    func deleteDraft(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let conversationID = try req.parameters.require("conversationID", as: UUID.self)
        let parentID: UUID? = try? req.query.get(UUID.self, at: "parentId")

        try await Self.requireConversationMembership(conversationId: conversationID, userId: ctx.userId, on: req.db)

        if let existing = try await Self.fetch(userId: ctx.userId, conversationId: conversationID, parentId: parentID, on: req.db) {
            try await existing.delete(on: req.db)
        }
        return .success(EmptyResponse())
    }

    @Sendable
    func listMyDrafts(req: Request) async throws -> APIResponse<[MessageDraftDTO]> {
        let ctx = try req.orgContext
        // Org scoping: only return drafts whose conversation is in this org.
        let rows = try await MessageDraftModel.query(on: req.db)
            .filter(\.$user.$id == ctx.userId)
            .join(ConversationModel.self, on: \MessageDraftModel.$conversation.$id == \ConversationModel.$id)
            .filter(ConversationModel.self, \.$organization.$id == ctx.orgId)
            .sort(\.$updatedAt, .descending)
            .all()
        return .success(rows.map(Self.toDTO))
    }

    // MARK: - Helpers (shared with MessageController.sendMessage for clear-on-send)

    static func fetch(userId: UUID, conversationId: UUID, parentId: UUID?, on db: Database) async throws -> MessageDraftModel? {
        let q = MessageDraftModel.query(on: db)
            .filter(\.$user.$id == userId)
            .filter(\.$conversation.$id == conversationId)
        if let parentId {
            return try await q.filter(\.$parent.$id == parentId).first()
        } else {
            return try await q.filter(\.$parent.$id == nil).first()
        }
    }

    /// Called from MessageController on successful send to drop the matching draft.
    static func clearAfterSend(userId: UUID, conversationId: UUID, parentId: UUID?, on db: Database) async {
        do {
            if let existing = try await fetch(userId: userId, conversationId: conversationId, parentId: parentId, on: db) {
                try await existing.delete(on: db)
            }
        } catch {
            // Non-fatal — draft cleanup is best-effort.
        }
    }

    static func toDTO(_ row: MessageDraftModel) -> MessageDraftDTO {
        MessageDraftDTO(
            id: row.id ?? UUID(),
            userId: row.$user.id,
            conversationId: row.$conversation.id,
            parentId: row.$parent.id,
            body: row.body,
            updatedAt: row.updatedAt
        )
    }

    static func requireConversationMembership(conversationId: UUID, userId: UUID, on db: Database) async throws {
        let isMember = try await ConversationMemberModel.query(on: db)
            .filter(\.$conversation.$id == conversationId)
            .filter(\.$user.$id == userId)
            .count() > 0
        if !isMember {
            throw Abort(.forbidden, reason: "Not a member of this conversation.")
        }
    }
}

