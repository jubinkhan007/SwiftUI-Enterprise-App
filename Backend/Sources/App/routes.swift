import Vapor

/// Registers all application routes.
func routes(_ app: Application) throws {
    // Health check
    app.get("health") { req async -> [String: String] in
        ["status": "ok"]
    }

    // API v1 group
    let api = app.grouped("api")

    let authController = AuthController()
    try api.register(collection: authController)

    // Setup authenticated API routes
    let authenticatedAPI = api.grouped(JWTAuthMiddleware())
    // Org-scoped routes (require X-Org-Id header)
    let orgScopedAPI = authenticatedAPI.grouped(OrgTenantMiddleware())

    let taskController = TaskController()
    try orgScopedAPI.register(collection: taskController)
    
    let hierarchyController = HierarchyController()
    try orgScopedAPI.register(collection: hierarchyController)
    
    let viewConfigController = ViewConfigController()
    try authenticatedAPI.register(collection: viewConfigController)

    let organizationController = OrganizationController()
    try authenticatedAPI.register(collection: organizationController)
}
