import Fluent
import FluentSQLiteDriver
import Foundation
import JWT
import Vapor

/// Configures the application: database, migrations, middleware, and routes.
func configure(_ app: Application) throws {
    // Allow larger bodies for multipart uploads (attachments). We still enforce per-file limits in controllers.
    app.routes.defaultMaxBodySize = "64mb"

    // MARK: - CORS Middleware
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .init("X-Org-Id")]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

    // MARK: - Database
    // In Docker the working directory is read-only; default to /data (mounted volume) or /tmp on Linux.
    let dbPath = resolveSQLiteDatabasePath(app: app)
    app.logger.info("Using SQLite database at \(dbPath)")
    app.databases.use(.sqlite(.file(dbPath)), as: .sqlite)

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
    app.migrations.add(AddTaskListHierarchy())
    app.migrations.add(BackfillTasksToDefaultHierarchies())
    app.migrations.add(EnforceTaskListIdOnTasks())
    app.migrations.add(AddAdvancedTaskFields())
    app.migrations.add(CreateTaskRelation())
    app.migrations.add(CreateChecklistItem())
    app.migrations.add(CreateViewConfig())
    app.migrations.add(AddViewIndexes())

    // Phase 10: Workflow & Automation
    app.migrations.add(AddWorkflowVersionToProjects())
    app.migrations.add(CreateCustomStatuses())
    app.migrations.add(AddStatusIdToTaskItems())
    app.migrations.add(CreateAutomationTables())
    app.migrations.add(BackfillTaskStatusIds())
    app.migrations.add(EnforceStatusIdOnTasks())

    // Phase 11: Collaboration
    app.migrations.add(CreateComments())
    app.migrations.add(CreateMentions())
    app.migrations.add(CreateAttachments())
    app.migrations.add(CreateNotifications())

    // Phase 12: Analytics & Reporting
    app.migrations.add(AddCompletedAtToTaskItem())
    app.migrations.add(CreateSprintsAndStats())

    // Phase 13: Agile / Jira Features
    app.migrations.add(AddAgileJiraPhase13())

    // Phase 16: Integrations (API keys + webhooks foundation)
    app.migrations.add(CreateAPIKeys())
    app.migrations.add(CreateWebhookSubscriptions())

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

    // MARK: - Commands
    app.asyncCommands.use(AggregateStatsCommand(), as: "aggregate-stats")

    // MARK: - Routes
    try routes(app)
}

private func resolveSQLiteDatabasePath(app: Application) -> String {
    // 1. Check for explicit env var override
    let configured = Environment.get("DATABASE_PATH") ?? Environment.get("SQLITE_DB_PATH")
    if let configured, !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        app.logger.info("DATABASE_PATH env var set to: \(configured)")
        let filePath = ensureParentDirectoryExists(path: configured, logger: app.logger)
        return filePath
    }

    // 2. Production Linux default: always use /data (Docker volume)
    #if os(Linux)
    let dataDir = "/data"
    let fm = FileManager.default
    if !fm.fileExists(atPath: dataDir) {
        try? fm.createDirectory(atPath: dataDir, withIntermediateDirectories: true)
    }
    let dbPath = "\(dataDir)/enterprise_app.db"
    app.logger.info("No DATABASE_PATH set. Linux detected, using: \(dbPath)")
    return dbPath
    #else
    // macOS local development
    return "enterprise_app.db"
    #endif
}

private func ensureParentDirectoryExists(path: String, logger: Logger) -> String {
    let filePath: String
    if path.lowercased().hasPrefix("file://"), let url = URL(string: path) {
        filePath = url.path
    } else {
        filePath = path
    }

    let parent = URL(fileURLWithPath: filePath).deletingLastPathComponent().path
    guard !parent.isEmpty else { return filePath }

    do {
        try FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
    } catch {
        logger.warning("Failed to create SQLite parent directory at \(parent): \(String(describing: error))")
    }

    return filePath
}

private func isWritableDirectory(_ path: String) -> Bool {
    let fm = FileManager.default
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return false }

    let probe = URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent(".write_probe_\(UUID().uuidString)")
    do {
        try Data([0x00]).write(to: probe, options: .atomic)
        try fm.removeItem(at: probe)
        return true
    } catch {
        return false
    }
}
