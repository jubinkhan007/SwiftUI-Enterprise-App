import Fluent
import SharedModels
import Vapor

/// Manages saved View Configurations (Kanban boards, Lists, etc.) for a user/org.
struct ViewConfigController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let views = routes.grouped("views").grouped(OrgTenantMiddleware())
        
        // Ensure user has base read access (we check specific permissions inside the handlers)
        views.get(use: index)
        
        let writeProtected = views.grouped(RequirePermissionMiddleware(permission: .viewsCreate))
        writeProtected.post(use: create)
        
        let viewRoute = views.grouped(":viewID")
        viewRoute.get(use: show)
        
        let updateProtected = viewRoute.grouped(RequirePermissionMiddleware(permission: .viewsUpdate))
        updateProtected.patch(use: update)
        
        let duplicateProtected = viewRoute.grouped(RequirePermissionMiddleware(permission: .viewsCreate))
        duplicateProtected.post("duplicate", use: duplicate)
        
        let defaultProtected = viewRoute.grouped(RequirePermissionMiddleware(permission: .viewsSetDefault))
        defaultProtected.patch("set-default", use: setDefault)
        
        let deleteProtected = viewRoute.grouped(RequirePermissionMiddleware(permission: .viewsDelete))
        deleteProtected.delete(use: delete)
    }
    
    // MARK: - GET /api/views
    
    @Sendable
    func index(req: Request) async throws -> APIResponse<[ViewConfigDTO]> {
        let ctx = try req.orgContext
        guard let scopeRaw: String = try? req.query.get(String.self, at: "scope"),
              let scope = ViewScope(rawValue: scopeRaw),
              let scopeId: UUID = try? req.query.get(UUID.self, at: "scopeId") else {
            throw Abort(.badRequest, reason: "Missing or invalid scope/scopeId parameters.")
        }
        
        // Scope ownership validation would go here (e.g. check if user has access to scopeId).
        // For brevity and MVP, we assume OrgTenantMiddleware + basic access is sufficient.
        
        let views = try await ViewConfigModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$appliesTo == scope)
            .filter(\.$scopeId == scopeId)
            .group(.or) { or in
                or.filter(\.$isPublic == true)
                or.filter(\.$ownerUserId == ctx.userId)
            }
            .sort(\.$name, .ascending)
            .all()
            
        return .success(try views.map { try $0.toDTO() })
    }
    
    // MARK: - POST /api/views
    
    @Sendable
    func create(req: Request) async throws -> APIResponse<ViewConfigDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(CreateViewConfigRequest.self)
        
        guard !payload.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Abort(.badRequest, reason: "Name is required.")
        }
        
        // Validate JSON via parser
        _ = try TaskQueryParser.parse(filtersJson: payload.filtersJson, sortsJson: payload.sortsJson)
        
        var boardJson: String? = nil
        if let config = payload.boardConfig {
            let data = try JSONEncoder().encode(config)
            boardJson = String(data: data, encoding: .utf8)
        }
        
        var visibleJson: String? = nil
        if let cols = payload.visibleColumns {
            let data = try JSONEncoder().encode(cols)
            visibleJson = String(data: data, encoding: .utf8)
        }
        
        if payload.isPublic {
            let hasPermission = ctx.permissions.has(.viewsShare)
            guard hasPermission else {
                throw Abort(.forbidden, reason: "You do not have permission to create public views.")
            }
        }
        
        if payload.isDefault {
            let hasPermission = ctx.permissions.has(.viewsSetDefault)
            guard hasPermission else {
                throw Abort(.forbidden, reason: "You do not have permission to set default views.")
            }
            // Unset previous defaults
            try await ViewConfigModel.query(on: req.db)
                .filter(\.$organization.$id == ctx.orgId)
                .filter(\.$appliesTo == payload.appliesTo)
                .filter(\.$scopeId == payload.scopeId)
                .set(\.$isDefault, to: false)
                .update()
        }
        
        let model = ViewConfigModel(
            orgId: ctx.orgId,
            name: payload.name,
            type: payload.type,
            filtersJson: payload.filtersJson,
            sortsJson: payload.sortsJson,
            appliesTo: payload.appliesTo,
            scopeId: payload.scopeId,
            ownerUserId: ctx.userId,
            isPublic: payload.isPublic,
            isDefault: payload.isDefault,
            visibleColumnsJson: visibleJson,
            boardConfigJson: boardJson
        )
        
        try await model.save(on: req.db)
        return .success(try model.toDTO())
    }
    
    // MARK: - GET /api/views/:id
    
    @Sendable
    func show(req: Request) async throws -> APIResponse<ViewConfigDTO> {
        let ctx = try req.orgContext
        let viewId = try req.parameters.require("viewID", as: UUID.self)
        
        guard let view = try await ViewConfigModel.query(on: req.db)
            .filter(\.$id == viewId)
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound, reason: "View not found.")
        }
        
        if !view.isPublic && view.ownerUserId != ctx.userId {
            throw Abort(.forbidden, reason: "You do not have access to this private view.")
        }
        
        return .success(try view.toDTO())
    }
    
    // MARK: - PATCH /api/views/:id
    
    @Sendable
    func update(req: Request) async throws -> APIResponse<ViewConfigDTO> {
        let ctx = try req.orgContext
        let viewId = try req.parameters.require("viewID", as: UUID.self)
        let payload = try req.content.decode(UpdateViewConfigRequest.self)
        
        guard let view = try await ViewConfigModel.query(on: req.db)
            .filter(\.$id == viewId)
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound)
        }
        
        guard view.ownerUserId == ctx.userId || ctx.permissions.has(.orgSettings) else {
            throw Abort(.forbidden, reason: "Only the owner or an admin can edit a view directly. To make changes, use 'Duplicate'.")
        }
        
        if let name = payload.name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            view.name = name.trimmingCharacters(in: .whitespaces)
        }
        if let type = payload.type {
            view.type = type
        }
        
        // If provided, validate and update JSON
        if payload.filtersJson != nil || payload.sortsJson != nil {
            let filters = payload.filtersJson ?? view.filtersJson
            let sorts = payload.sortsJson ?? view.sortsJson
            _ = try TaskQueryParser.parse(filtersJson: filters, sortsJson: sorts)
            
            if payload.filtersJson != nil { view.filtersJson = payload.filtersJson }
            if payload.sortsJson != nil { view.sortsJson = payload.sortsJson }
        }
        
        if let isPublic = payload.isPublic {
            let hasPermission = ctx.permissions.has(.viewsShare)
            guard hasPermission || !isPublic else {
                throw Abort(.forbidden, reason: "You do not have permission to share public views.")
            }
            view.isPublic = isPublic
        }
        
        if let cols = payload.visibleColumns {
            let data = try JSONEncoder().encode(cols)
            view.visibleColumnsJson = String(data: data, encoding: .utf8)
        }
        
        if let board = payload.boardConfig {
            let data = try JSONEncoder().encode(board)
            view.boardConfigJson = String(data: data, encoding: .utf8)
        }
        
        try await view.save(on: req.db)
        return .success(try view.toDTO())
    }
    
    // MARK: - POST /api/views/:id/duplicate
    
    @Sendable
    func duplicate(req: Request) async throws -> APIResponse<ViewConfigDTO> {
        let ctx = try req.orgContext
        let viewId = try req.parameters.require("viewID", as: UUID.self)
        
        guard let original = try await ViewConfigModel.query(on: req.db)
            .filter(\.$id == viewId)
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound)
        }
        
        if !original.isPublic && original.ownerUserId != ctx.userId {
            throw Abort(.forbidden, reason: "You cannot duplicate a private view that you don't own.")
        }
        
        let newView = ViewConfigModel(
            orgId: ctx.orgId,
            name: "Copy of \(original.name)",
            type: original.type,
            filtersJson: original.filtersJson,
            sortsJson: original.sortsJson,
            schemaVersion: original.schemaVersion,
            appliesTo: original.appliesTo,
            scopeId: original.scopeId,
            ownerUserId: ctx.userId, // Duplicate belongs to the user
            isPublic: false,         // Default to private
            isDefault: false,        // Never default automatically
            visibleColumnsJson: original.visibleColumnsJson,
            boardConfigJson: original.boardConfigJson
        )
        
        try await newView.save(on: req.db)
        return .success(try newView.toDTO())
    }
    
    // MARK: - PATCH /api/views/:id/set-default
    
    @Sendable
    func setDefault(req: Request) async throws -> APIResponse<ViewConfigDTO> {
        let ctx = try req.orgContext
        let viewId = try req.parameters.require("viewID", as: UUID.self)
        
        guard let view = try await ViewConfigModel.query(on: req.db)
            .filter(\.$id == viewId)
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound)
        }
        
        // Remove existing defaults for this scope
        try await ViewConfigModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$appliesTo == view.appliesTo)
            .filter(\.$scopeId == view.scopeId)
            .set(\.$isDefault, to: false)
            .update()
        
        view.isDefault = true
        try await view.save(on: req.db)
        
        return .success(try view.toDTO())
    }
    
    // MARK: - DELETE /api/views/:id
    
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let ctx = try req.orgContext
        let viewId = try req.parameters.require("viewID", as: UUID.self)
        
        guard let view = try await ViewConfigModel.query(on: req.db)
            .filter(\.$id == viewId)
            .filter(\.$organization.$id == ctx.orgId)
            .first() else {
            throw Abort(.notFound)
        }
        
        let isAdmin = ctx.permissions.has(.orgSettings)
        guard view.ownerUserId == ctx.userId || isAdmin else {
            throw Abort(.forbidden, reason: "You can only delete your own views, unless you are an admin.")
        }
        
        guard !view.isDefault else {
            throw Abort(.badRequest, reason: "Cannot delete the default view. Set another view as default first.")
        }
        
        try await view.delete(on: req.db)
        return .noContent
    }
}

/// Middleware that requires a specific permission within the current organization.
struct RequirePermissionMiddleware: AsyncMiddleware {
    let permission: Permission

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        try request.requirePermission(permission)
        return try await next.respond(to: request)
    }
}
