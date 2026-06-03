import Fluent
import JWT
import SharedModels
import Vapor

// MARK: - Org-admin DTOs (backend-local)

struct RetentionPolicyDTO: Content {
    /// Retention window in days; `nil` means indefinite.
    let retentionDays: Int?
}

struct PurgeResultDTO: Content {
    let deletedCount: Int
}

struct ExportDescriptorDTO: Content {
    let downloadUrl: String
    let format: String
    let sizeBytes: Int
    let expiresAt: Date
}

struct ModerationChannelDTO: Content {
    let id: UUID
    let name: String?
    let type: String
    let isPrivate: Bool
    let isArchived: Bool
    let isLocked: Bool
    let memberCount: Int
    let messageCount: Int
    let lastMessageAt: Date?
    let createdAt: Date?
}

struct ModerationMessageDTO: Content {
    let id: UUID
    let conversationId: UUID
    let conversationName: String?
    let senderId: UUID
    let body: String
    let messageType: String
    let editedAt: Date?
    let deletedAt: Date?
    let createdAt: Date?
}

struct SetArchivedRequest: Content { let archived: Bool }
struct SetLockedRequest: Content { let locked: Bool }

// MARK: - Export token

struct ExportTokenPayload: JWTPayload {
    var subject: SubjectClaim   // file id
    var expiration: ExpirationClaim
    var orgId: String
    var format: String
    func verify(using signer: JWTSigner) throws { try expiration.verifyNotExpired() }
}

// MARK: - OrgAdminController

/// Tenant-level admin routes under `/api/admin/org`. Assumes the route group is
/// protected by `CookieAuthMiddleware` + `OrgTenantMiddleware` + `RequireOrgAdminMiddleware`.
struct OrgAdminController: RouteCollection {
    static let exportTTL: TimeInterval = 10 * 60  // 10-minute signed link

    func boot(routes: any RoutesBuilder) throws {
        // Retention
        routes.get("retention", use: getRetention)
        routes.put("retention", use: setRetention)
        routes.post("retention", "purge-now", use: purgeNow)

        // Compliance export
        routes.post("export", use: createExport)
        routes.get("export", "download", use: downloadExport)

        // Members
        let members = routes.grouped("members")
        members.get(use: listMembers)
        members.put(":memberID", "role", use: updateMemberRole)
        members.delete(":memberID", use: removeMember)
        routes.get("join-requests", use: listJoinRequests)
        routes.post("join-requests", ":reqID", "respond", use: respondJoinRequest)

        // Moderation
        let channels = routes.grouped("channels")
        channels.get(use: listChannels)
        channels.post(":cid", "archive", use: setArchived)
        channels.post(":cid", "lock", use: setLocked)
        channels.delete(":cid", use: deleteChannel)
        routes.get("moderation", "messages", use: moderationMessages)
    }

    // MARK: - Retention

    @Sendable
    func getRetention(req: Request) async throws -> APIResponse<RetentionPolicyDTO> {
        let ctx = try req.orgContext
        guard let org = try await OrganizationModel.find(ctx.orgId, on: req.db) else {
            throw Abort(.notFound, reason: "Organization not found.")
        }
        return .success(RetentionPolicyDTO(retentionDays: org.retentionDays))
    }

    @Sendable
    func setRetention(req: Request) async throws -> APIResponse<RetentionPolicyDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(RetentionPolicyDTO.self)
        if let days = payload.retentionDays, days < 1 {
            throw Abort(.badRequest, reason: "Retention days must be at least 1, or null for indefinite.")
        }
        guard let org = try await OrganizationModel.find(ctx.orgId, on: req.db) else {
            throw Abort(.notFound, reason: "Organization not found.")
        }
        org.retentionDays = payload.retentionDays
        try await org.save(on: req.db)
        try await audit(req: req, ctx: ctx, action: "org.retention_changed", resourceType: "org",
                        resourceId: ctx.orgId, details: "retention_days=\(payload.retentionDays.map(String.init) ?? "indefinite")")
        return .success(RetentionPolicyDTO(retentionDays: org.retentionDays))
    }

    @Sendable
    func purgeNow(req: Request) async throws -> APIResponse<PurgeResultDTO> {
        let ctx = try req.orgContext
        guard let org = try await OrganizationModel.find(ctx.orgId, on: req.db),
              let days = org.retentionDays, days > 0 else {
            return .success(PurgeResultDTO(deletedCount: 0))
        }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        let conversations = try await ConversationModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId).all()
        let convIds = conversations.compactMap { $0.id }
        var deleted = 0
        if !convIds.isEmpty {
            let expired = try await MessageModel.query(on: req.db)
                .filter(\.$conversation.$id ~~ convIds)
                .filter(\.$createdAt < cutoff)
                .all()
            for m in expired { try await m.delete(force: true, on: req.db) }
            deleted = expired.count
        }
        try await audit(req: req, ctx: ctx, action: "org.retention_purged", resourceType: "org",
                        resourceId: ctx.orgId, details: "deleted=\(deleted)")
        return .success(PurgeResultDTO(deletedCount: deleted))
    }

    // MARK: - Members

    @Sendable
    func listMembers(req: Request) async throws -> APIResponse<[OrganizationMemberDTO]> {
        let ctx = try req.orgContext
        let members = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .with(\.$user)
            .all()
        return .success(members.map { $0.toDTO(displayName: $0.user.displayName, email: $0.user.email) })
    }

    @Sendable
    func updateMemberRole(req: Request) async throws -> APIResponse<OrganizationMemberDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(ChangeRoleRequest.self)
        guard let memberId = req.parameters.get("memberID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid member ID.")
        }
        guard let member = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$id == memberId)
            .filter(\.$organization.$id == ctx.orgId)
            .with(\.$user)
            .first() else {
            throw Abort(.notFound, reason: "Member not found.")
        }
        member.role = payload.role
        try await member.save(on: req.db)
        try await audit(req: req, ctx: ctx, action: "member.role_changed", resourceType: "member",
                        resourceId: member.id, details: "user=\(member.user.email) role=\(payload.role.rawValue)")
        return .success(member.toDTO(displayName: member.user.displayName, email: member.user.email))
    }

    @Sendable
    func removeMember(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        guard let memberId = req.parameters.get("memberID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid member ID.")
        }
        guard let member = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$id == memberId)
            .filter(\.$organization.$id == ctx.orgId)
            .with(\.$user)
            .first() else {
            throw Abort(.notFound, reason: "Member not found.")
        }
        guard member.$user.id != ctx.userId else {
            throw Abort(.badRequest, reason: "You cannot remove yourself.")
        }
        let email = member.user.email
        try await member.delete(on: req.db)
        try await audit(req: req, ctx: ctx, action: "member.removed", resourceType: "member",
                        resourceId: member.id, details: "user=\(email)")
        return .empty()
    }

    @Sendable
    func listJoinRequests(req: Request) async throws -> APIResponse<[OrganizationJoinRequestDTO]> {
        let ctx = try req.orgContext
        let requests = try await OrganizationJoinRequestModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$status == "pending")
            .with(\.$organization)
            .with(\.$user)
            .sort(\.$createdAt, .descending)
            .all()
        return .success(requests.map {
            $0.toDTO(orgName: $0.organization.name, userName: $0.user.displayName, userEmail: $0.user.email)
        })
    }

    @Sendable
    func respondJoinRequest(req: Request) async throws -> APIResponse<OrganizationJoinRequestDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(RespondToJoinRequestRequest.self)
        guard payload.action == "accept" || payload.action == "reject" else {
            throw Abort(.badRequest, reason: "Action must be 'accept' or 'reject'.")
        }
        guard let reqId = req.parameters.get("reqID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid request ID.")
        }
        guard let joinRequest = try await OrganizationJoinRequestModel.query(on: req.db)
            .filter(\.$id == reqId)
            .filter(\.$organization.$id == ctx.orgId)
            .with(\.$organization)
            .with(\.$user)
            .first() else {
            throw Abort(.notFound, reason: "Join request not found.")
        }
        guard joinRequest.status == "pending" else {
            throw Abort(.badRequest, reason: "This join request has already been resolved.")
        }

        if payload.action == "accept" {
            joinRequest.status = "accepted"
            joinRequest.respondedBy = ctx.userId
            try await joinRequest.save(on: req.db)
            let alreadyMember = try await OrganizationMemberModel.query(on: req.db)
                .filter(\.$organization.$id == ctx.orgId)
                .filter(\.$user.$id == joinRequest.$user.id)
                .count() > 0
            if !alreadyMember {
                try await OrganizationMemberModel(orgId: ctx.orgId, userId: joinRequest.$user.id, role: .member)
                    .save(on: req.db)
            }
        } else {
            joinRequest.status = "rejected"
            joinRequest.respondedBy = ctx.userId
            try await joinRequest.save(on: req.db)
        }
        try await audit(req: req, ctx: ctx, action: "join_request.\(payload.action)ed", resourceType: "join_request",
                        resourceId: joinRequest.id, details: "user=\(joinRequest.user.email)")
        return .success(joinRequest.toDTO(orgName: joinRequest.organization.name,
                                          userName: joinRequest.user.displayName,
                                          userEmail: joinRequest.user.email))
    }

    // MARK: - Compliance export

    @Sendable
    func createExport(req: Request) async throws -> APIResponse<ExportDescriptorDTO> {
        let ctx = try req.orgContext
        let format = (try? req.query.get(String.self, at: "format"))?.lowercased() ?? "json"
        guard format == "json" || format == "csv" else {
            throw Abort(.badRequest, reason: "format must be 'json' or 'csv'.")
        }

        let bundle = try await buildExportBundle(orgId: ctx.orgId, on: req)
        let data: Data
        if format == "csv" {
            data = Data(Self.messagesCSV(bundle).utf8)
        } else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            data = try encoder.encode(bundle)
        }

        let fileId = UUID()
        let url = try Self.exportFileURL(for: fileId, format: format, app: req.application)
        try data.write(to: url, options: .atomic)

        let expiresAt = Date().addingTimeInterval(Self.exportTTL)
        let token = ExportTokenPayload(
            subject: .init(value: fileId.uuidString),
            expiration: .init(value: expiresAt),
            orgId: ctx.orgId.uuidString,
            format: format
        )
        let signed = try req.jwt.sign(token)
        try await audit(req: req, ctx: ctx, action: "org.compliance_export", resourceType: "org",
                        resourceId: ctx.orgId, details: "format=\(format) bytes=\(data.count)")

        return .success(ExportDescriptorDTO(
            downloadUrl: "/api/admin/org/export/download?token=\(signed)",
            format: format,
            sizeBytes: data.count,
            expiresAt: expiresAt
        ))
    }

    @Sendable
    func downloadExport(req: Request) async throws -> Response {
        let ctx = try req.orgContext
        guard let raw = try? req.query.get(String.self, at: "token") else {
            throw Abort(.badRequest, reason: "Missing token.")
        }
        let payload: ExportTokenPayload
        do {
            payload = try req.jwt.verify(raw, as: ExportTokenPayload.self)
        } catch {
            throw Abort(.unauthorized, reason: "Export link expired.")
        }
        guard payload.orgId == ctx.orgId.uuidString, let fileId = UUID(uuidString: payload.subject.value) else {
            throw Abort(.forbidden, reason: "Export does not belong to this workspace.")
        }
        let url = try Self.exportFileURL(for: fileId, format: payload.format, app: req.application)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw Abort(.notFound, reason: "Export no longer available.")
        }
        let response = req.fileio.streamFile(at: url.path)
        let ext = payload.format == "csv" ? "csv" : "json"
        let mime = payload.format == "csv" ? "text/csv" : "application/json"
        response.headers.replaceOrAdd(name: .contentType, value: mime)
        response.headers.replaceOrAdd(name: .contentDisposition,
                                      value: "attachment; filename=\"compliance-export-\(fileId.uuidString).\(ext)\"")
        return response
    }

    // MARK: - Moderation

    @Sendable
    func listChannels(req: Request) async throws -> APIResponse<[ModerationChannelDTO]> {
        let ctx = try req.orgContext
        let conversations = try await ConversationModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .sort(\.$lastMessageAt, .descending)
            .all()
        var result: [ModerationChannelDTO] = []
        for conv in conversations {
            guard let cid = conv.id else { continue }
            let memberCount = try await ConversationMemberModel.query(on: req.db)
                .filter(\.$conversation.$id == cid).count()
            let messageCount = try await MessageModel.query(on: req.db)
                .filter(\.$conversation.$id == cid).count()
            result.append(ModerationChannelDTO(
                id: cid, name: conv.name, type: conv.type, isPrivate: conv.isPrivate,
                isArchived: conv.isArchived, isLocked: conv.isLocked,
                memberCount: memberCount, messageCount: messageCount,
                lastMessageAt: conv.lastMessageAt, createdAt: conv.createdAt
            ))
        }
        return .success(result)
    }

    @Sendable
    func setArchived(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(SetArchivedRequest.self)
        let conv = try await loadOrgChannel(req: req, orgId: ctx.orgId)
        conv.isArchived = payload.archived
        try await conv.save(on: req.db)
        try await audit(req: req, ctx: ctx, action: payload.archived ? "channel.archived" : "channel.unarchived",
                        resourceType: "channel", resourceId: conv.id)
        return .empty()
    }

    @Sendable
    func setLocked(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(SetLockedRequest.self)
        let conv = try await loadOrgChannel(req: req, orgId: ctx.orgId)
        conv.isLocked = payload.locked
        try await conv.save(on: req.db)
        try await audit(req: req, ctx: ctx, action: payload.locked ? "channel.locked" : "channel.unlocked",
                        resourceType: "channel", resourceId: conv.id)
        return .empty()
    }

    @Sendable
    func deleteChannel(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let conv = try await loadOrgChannel(req: req, orgId: ctx.orgId)
        let cid = conv.id
        try await conv.delete(on: req.db)
        try await audit(req: req, ctx: ctx, action: "channel.deleted", resourceType: "channel", resourceId: cid)
        return .empty()
    }

    @Sendable
    func moderationMessages(req: Request) async throws -> APIResponse<[ModerationMessageDTO]> {
        let ctx = try req.orgContext
        let limit = min((try? req.query.get(Int.self, at: "limit")) ?? 100, 500)
        let conversations = try await ConversationModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId).all()
        let nameById = Dictionary(uniqueKeysWithValues: conversations.compactMap { c in c.id.map { ($0, c.name) } })
        let convIds = conversations.compactMap { $0.id }
        guard !convIds.isEmpty else { return .success([]) }

        // Flagged = edited or soft-deleted messages.
        let messages = try await MessageModel.query(on: req.db)
            .filter(\.$conversation.$id ~~ convIds)
            .group(.or) { group in
                group.filter(\.$editedAt != nil).filter(\.$deletedAt != nil)
            }
            .sort(\.$createdAt, .descending)
            .range(..<limit)
            .all()

        let dtos = messages.compactMap { m -> ModerationMessageDTO? in
            guard let id = m.id else { return nil }
            return ModerationMessageDTO(
                id: id, conversationId: m.$conversation.id,
                conversationName: nameById[m.$conversation.id] ?? nil,
                senderId: m.$sender.id, body: m.body, messageType: m.messageType,
                editedAt: m.editedAt, deletedAt: m.deletedAt, createdAt: m.createdAt
            )
        }
        return .success(dtos)
    }

    // MARK: - Helpers

    private func loadOrgChannel(req: Request, orgId: UUID) async throws -> ConversationModel {
        guard let conv = try await ConversationModel.find(req.parameters.get("cid"), on: req.db) else {
            throw Abort(.notFound, reason: "Channel not found.")
        }
        guard conv.$organization.id == orgId else {
            throw Abort(.forbidden, reason: "Channel does not belong to this workspace.")
        }
        return conv
    }

    private func audit(req: Request, ctx: OrgContext, action: String, resourceType: String,
                       resourceId: UUID?, details: String? = nil) async throws {
        let email = (try? await UserModel.find(ctx.userId, on: req.db))?.email ?? "unknown"
        try await AuditLogModel.log(on: req.db, orgId: ctx.orgId, userId: ctx.userId, userEmail: email,
                                    action: action, resourceType: resourceType, resourceId: resourceId, details: details)
    }

    private static func exportFileURL(for fileId: UUID, format: String, app: Application) throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("compliance-exports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = format == "csv" ? "csv" : "json"
        return dir.appendingPathComponent("\(fileId.uuidString).\(ext)")
    }

    // MARK: - Export bundle

    private func buildExportBundle(orgId: UUID, on req: Request) async throws -> ExportBundle {
        guard let org = try await OrganizationModel.find(orgId, on: req.db) else {
            throw Abort(.notFound, reason: "Organization not found.")
        }
        // Members
        let memberships = try await OrganizationMemberModel.query(on: req.db)
            .filter(\.$organization.$id == orgId).with(\.$user).all()
        let members = memberships.map {
            ExportMember(userId: $0.$user.id, email: $0.user.email, displayName: $0.user.displayName,
                         role: $0.role.rawValue, joinedAt: $0.joinedAt)
        }
        // Messages
        let conversations = try await ConversationModel.query(on: req.db)
            .filter(\.$organization.$id == orgId).all()
        let nameById = Dictionary(uniqueKeysWithValues: conversations.compactMap { c in c.id.map { ($0, c.name) } })
        let convIds = conversations.compactMap { $0.id }
        var messages: [ExportMessage] = []
        if !convIds.isEmpty {
            let rows = try await MessageModel.query(on: req.db)
                .filter(\.$conversation.$id ~~ convIds)
                .sort(\.$createdAt, .ascending)
                .all()
            messages = rows.compactMap { m in
                m.id.map {
                    ExportMessage(id: $0, conversationId: m.$conversation.id,
                                  conversationName: nameById[m.$conversation.id] ?? nil,
                                  senderId: m.$sender.id, body: m.body, messageType: m.messageType,
                                  editedAt: m.editedAt, deletedAt: m.deletedAt, createdAt: m.createdAt)
                }
            }
        }
        // Media logs (attachments)
        let attachments = try await AttachmentModel.query(on: req.db)
            .filter(\.$organization.$id == orgId).all()
        let mediaLogs = attachments.compactMap { a in
            a.id.map {
                ExportMedia(id: $0, filename: a.filename, mimeType: a.mimeType, fileType: a.fileType,
                            sizeBytes: Int(a.size), createdAt: a.createdAt)
            }
        }
        return ExportBundle(
            exportedAt: Date(),
            organization: ExportOrg(id: orgId, name: org.name, slug: org.slug, retentionDays: org.retentionDays),
            members: members,
            messages: messages,
            mediaLogs: mediaLogs
        )
    }

    private static func messagesCSV(_ bundle: ExportBundle) -> String {
        var lines = ["id,conversation_id,conversation_name,sender_id,message_type,created_at,edited_at,deleted_at,body"]
        let iso = ISO8601DateFormatter()
        func esc(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        func d(_ date: Date?) -> String { date.map { iso.string(from: $0) } ?? "" }
        for m in bundle.messages {
            lines.append([
                m.id.uuidString, m.conversationId.uuidString, esc(m.conversationName ?? ""),
                m.senderId.uuidString, m.messageType, d(m.createdAt), d(m.editedAt), d(m.deletedAt), esc(m.body)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Export bundle models

struct ExportOrg: Content {
    let id: UUID
    let name: String
    let slug: String
    let retentionDays: Int?
}

struct ExportMember: Content {
    let userId: UUID
    let email: String
    let displayName: String
    let role: String
    let joinedAt: Date?
}

struct ExportMessage: Content {
    let id: UUID
    let conversationId: UUID
    let conversationName: String?
    let senderId: UUID
    let body: String
    let messageType: String
    let editedAt: Date?
    let deletedAt: Date?
    let createdAt: Date?
}

struct ExportMedia: Content {
    let id: UUID
    let filename: String
    let mimeType: String
    let fileType: String
    let sizeBytes: Int
    let createdAt: Date?
}

struct ExportBundle: Content {
    let exportedAt: Date
    let organization: ExportOrg
    let members: [ExportMember]
    let messages: [ExportMessage]
    let mediaLogs: [ExportMedia]
}
