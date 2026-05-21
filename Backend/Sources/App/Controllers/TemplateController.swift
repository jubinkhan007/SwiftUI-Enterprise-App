import Fluent
import SharedModels
import Vapor

/// Phase 4 (Productivity): message templates. User-scoped (private to creator)
/// or org-scoped (visible to all org members; admin-only to edit/delete).
struct TemplateController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let templates = routes.grouped("templates")
        templates.get(use: list)
        templates.post(use: create)
        templates.put(":templateID", use: update)
        templates.delete(":templateID", use: delete)
        templates.post(":templateID", "render", use: render)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<[MessageTemplateDTO]> {
        let ctx = try req.orgContext
        let scopeFilter = (try? req.query.get(String.self, at: "scope")) ?? "all"

        var q = MessageTemplateModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
        switch scopeFilter.lowercased() {
        case "user":
            q = q.filter(\.$scope == "user").filter(\.$ownerUser.$id == ctx.userId)
        case "org":
            q = q.filter(\.$scope == "org")
        default:
            // "all" = my user templates + all org templates
            let userTemplates = try await MessageTemplateModel.query(on: req.db)
                .filter(\.$organization.$id == ctx.orgId)
                .filter(\.$scope == "user")
                .filter(\.$ownerUser.$id == ctx.userId)
                .all()
            let orgTemplates = try await MessageTemplateModel.query(on: req.db)
                .filter(\.$organization.$id == ctx.orgId)
                .filter(\.$scope == "org")
                .all()
            let combined = (userTemplates + orgTemplates)
                .sorted { lhs, rhs in lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending }
            return .success(combined.map(Self.toDTO))
        }

        let rows = try await q.sort(\.$name, .ascending).all()
        return .success(rows.map(Self.toDTO))
    }

    @Sendable
    func create(req: Request) async throws -> APIResponse<MessageTemplateDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(CreateTemplateRequest.self)

        try Self.validate(name: payload.name, body: payload.body, shortcut: payload.shortcut)

        if payload.scope == .org {
            try Self.requireOrgAdmin(ctx: ctx)
        }

        let row = MessageTemplateModel(
            orgId: ctx.orgId,
            ownerUserId: payload.scope == .user ? ctx.userId : nil,
            scope: payload.scope.rawValue,
            name: payload.name.trimmingCharacters(in: .whitespacesAndNewlines),
            shortcut: payload.shortcut?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            body: payload.body
        )
        try await row.save(on: req.db)

        if payload.scope == .org, let id = row.id {
            try? await AuditLogModel(
                orgId: ctx.orgId,
                userId: ctx.userId,
                userEmail: (try? await UserModel.find(ctx.userId, on: req.db))?.email ?? "",
                action: "template.created",
                resourceType: "template",
                resourceId: id,
                details: payload.name
            ).save(on: req.db)
        }

        return .success(Self.toDTO(row))
    }

    @Sendable
    func update(req: Request) async throws -> APIResponse<MessageTemplateDTO> {
        let ctx = try req.orgContext
        let templateID = try req.parameters.require("templateID", as: UUID.self)
        let payload = try req.content.decode(UpdateTemplateRequest.self)

        let row = try await Self.fetchEditable(templateID: templateID, ctx: ctx, on: req.db)

        if let name = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            row.name = name
        }
        if let shortcut = payload.shortcut {
            row.shortcut = shortcut.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        if let body = payload.body {
            guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw Abort(.badRequest, reason: "Body cannot be empty.")
            }
            row.body = body
        }
        try await row.save(on: req.db)

        if row.scope == "org", let id = row.id {
            try? await AuditLogModel(
                orgId: ctx.orgId,
                userId: ctx.userId,
                userEmail: (try? await UserModel.find(ctx.userId, on: req.db))?.email ?? "",
                action: "template.updated",
                resourceType: "template",
                resourceId: id,
                details: row.name
            ).save(on: req.db)
        }

        return .success(Self.toDTO(row))
    }

    @Sendable
    func delete(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let templateID = try req.parameters.require("templateID", as: UUID.self)
        let row = try await Self.fetchEditable(templateID: templateID, ctx: ctx, on: req.db)

        if row.scope == "org", let id = row.id {
            try? await AuditLogModel(
                orgId: ctx.orgId,
                userId: ctx.userId,
                userEmail: (try? await UserModel.find(ctx.userId, on: req.db))?.email ?? "",
                action: "template.deleted",
                resourceType: "template",
                resourceId: id,
                details: row.name
            ).save(on: req.db)
        }

        try await row.delete(on: req.db)
        return .success(EmptyResponse())
    }

    @Sendable
    func render(req: Request) async throws -> APIResponse<RenderedTemplateDTO> {
        let ctx = try req.orgContext
        let templateID = try req.parameters.require("templateID", as: UUID.self)
        let payload = (try? req.content.decode(RenderTemplateRequest.self)) ?? RenderTemplateRequest()

        guard let row = try await MessageTemplateModel.query(on: req.db)
            .filter(\.$id == templateID)
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound, reason: "Template not found.")
        }
        // Visibility: own user-template OR any org-template.
        if row.scope == "user", row.$ownerUser.id != ctx.userId {
            throw Abort(.forbidden, reason: "This template belongs to another user.")
        }

        let user = try await UserModel.find(ctx.userId, on: req.db)
        let org = try await OrganizationModel.find(ctx.orgId, on: req.db)

        var convName: String? = nil
        if let cid = payload.conversationId,
           let conv = try await ConversationModel.find(cid, on: req.db) {
            convName = conv.name
        }

        let rendered = Self.expand(
            body: row.body,
            userName: user?.displayName ?? "",
            userEmail: user?.email ?? "",
            orgName: org?.name ?? "",
            conversationName: convName ?? "",
            now: Date()
        )

        return .success(RenderedTemplateDTO(templateId: templateID, body: rendered))
    }

    // MARK: - Helpers

    static func validate(name: String, body: String, shortcut: String?) throws {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, n.count <= 80 else {
            throw Abort(.badRequest, reason: "Name is required and must be 80 chars or fewer.")
        }
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Body is required.")
        }
        if let shortcut, !shortcut.isEmpty {
            let trimmed = shortcut.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count <= 24 else {
                throw Abort(.badRequest, reason: "Shortcut must be 24 chars or fewer.")
            }
            guard trimmed.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
                throw Abort(.badRequest, reason: "Shortcut may only contain letters, digits, underscore, and hyphen.")
            }
        }
    }

    static func requireOrgAdmin(ctx: OrgContext) throws {
        guard ctx.role == .admin || ctx.role == .owner else {
            throw Abort(.forbidden, reason: "Only org admins can manage shared templates.")
        }
    }

    static func fetchEditable(templateID: UUID, ctx: OrgContext, on db: Database) async throws -> MessageTemplateModel {
        guard let row = try await MessageTemplateModel.query(on: db)
            .filter(\.$id == templateID)
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound, reason: "Template not found.")
        }
        if row.scope == "user" {
            if row.$ownerUser.id != ctx.userId {
                throw Abort(.forbidden, reason: "You can only edit your own templates.")
            }
        } else {
            try requireOrgAdmin(ctx: ctx)
        }
        return row
    }

    static func toDTO(_ row: MessageTemplateModel) -> MessageTemplateDTO {
        MessageTemplateDTO(
            id: row.id ?? UUID(),
            orgId: row.$organization.id,
            ownerUserId: row.$ownerUser.id,
            scope: TemplateScope(rawValue: row.scope) ?? .user,
            name: row.name,
            shortcut: row.shortcut,
            body: row.body,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }

    /// Lightweight `{{var}}` expansion. Unknown placeholders are left as-is.
    static func expand(
        body: String,
        userName: String,
        userEmail: String,
        orgName: String,
        conversationName: String,
        now: Date
    ) -> String {
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .none
        let tf = DateFormatter(); tf.dateStyle = .none; tf.timeStyle = .short
        var result = body
        let mappings: [String: String] = [
            "{{user.name}}": userName,
            "{{user.email}}": userEmail,
            "{{org.name}}": orgName,
            "{{conversation.name}}": conversationName,
            "{{date}}": df.string(from: now),
            "{{time}}": tf.string(from: now)
        ]
        for (k, v) in mappings {
            result = result.replacingOccurrences(of: k, with: v)
        }
        return result
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
