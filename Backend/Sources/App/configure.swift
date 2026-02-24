import Fluent
import FluentSQLiteDriver
import JWT
import Vapor

/// Configures the application: database, migrations, middleware, and routes.
func configure(_ app: Application) throws {
    // MARK: - CORS Middleware
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .init("X-Org-Id")]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

    // MARK: - Database
    app.databases.use(.sqlite(.file("enterprise_app.db")), as: .sqlite)

    // MARK: - Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateTaskItem())
    app.migrations.add(AddVersionToTaskItem())
    app.migrations.add(CreateTaskActivity())
    app.migrations.add(AddStartDateToTaskItem())
    app.migrations.add(CreateOrganization())
    app.migrations.add(CreateOrganizationMember())
    app.migrations.add(CreateOrganizationInvite())
    app.migrations.add(AddOrgIdToTaskItem())
    app.migrations.add(CreateAuditLog())

    // Run migrations automatically in development
    try app.autoMigrate().wait()

    // MARK: - JWT
    // In production, load this from environment variables
    let jwtSecret = Environment.get("JWT_SECRET") ?? "enterprise-app-dev-secret-key-change-in-production"
    app.jwt.signers.use(.hs256(key: jwtSecret))

    // MARK: - JSON Configuration
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.dateEncodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: encoder, for: .json)

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    // MARK: - Routes
    try routes(app)
}
