import Vapor

/// Registers all application routes.
func routes(_ app: Application) throws {
    // Health check
    app.get("health") { req async -> [String: String] in
        ["status": "ok"]
    }

    // API v1 group
    let api = app.grouped("api")

    // Auth routes (public)
    try api.register(collection: AuthController())

    // Protected routes (require JWT)
    let protected = api.grouped(JWTAuthMiddleware())
    try protected.register(collection: TaskController())
}
