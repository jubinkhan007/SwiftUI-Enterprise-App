import Fluent
import FluentSQLiteDriver
import Foundation
import JWT
import Vapor

/// Configures the application: database, migrations, middleware, and routes.
func configure(_ app: Application) throws {
    // Allow larger bodies for multipart uploads (attachments). We still enforce per-file limits in controllers.
    app.routes.defaultMaxBodySize = "64mb"

    // MARK: - Metrics Tracking
    app.middleware.use(MetricsMiddleware())

    // MARK: - Error Handling
    // Ensure `Abort` and other thrown errors become valid HTTP responses instead of closing the connection.
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // MARK: - CORS Middleware
    // The web admin panel sends HttpOnly cookies, which requires credentialed CORS:
    // browsers reject `Access-Control-Allow-Origin: *` together with credentials, so
    // we echo the request Origin (`.originBased`) and enable `allowCredentials`.
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .originBased,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .init("X-Org-Id")],
        allowCredentials: true
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
    // Admin Panel: super-admin flag + org status/retention columns must exist before
    // later backfill migrations query the User/Organization models.
    app.migrations.add(AddAdminUserOrgFields())
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
    app.migrations.add(BackfillTaskStatusIds())
    app.migrations.add(EnforceStatusIdOnTasks())

    // Phase 16: Integrations (API keys + webhooks foundation)
    app.migrations.add(CreateAPIKeys())
    app.migrations.add(CreateWebhookSubscriptions())

    // Phase 17: Messaging (conversations, DMs, messages)
    app.migrations.add(CreateMessaging())
    app.migrations.add(AddMessagingPhase2Features())

    // Phase 18: Governance (workspace join requests, channel role management)
    app.migrations.add(AddGovernanceFeatures())

    // Messaging Phase 3: reactions, pins, bookmarks, presence, message->task link
    app.migrations.add(AddMessagingPhase3Features())

    // Phase 4 (Meetings slice): scheduling, waiting room, notes, summaries
    app.migrations.add(CreateMeetings())

    // Phase 4 (Productivity slice): drafts, scheduled send, templates, reminders
    app.migrations.add(CreateProductivityFeatures())

    // Phase 4-B (Calls): SFU sessions, participants, records, VoIP tokens
    app.migrations.add(CreateCalls())

    // Phase 5 (Admin Panel): super-admin flag, org status + retention
    app.migrations.add(AddAdminPanelFields())

    // Phase 14: Agile Time Tracking
    app.migrations.add(CreateTimeLogsTable())

    // Phase 15: SaaS Tenant Fields
    app.migrations.add(CreateSaaSTenantFields())

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
    app.asyncCommands.use(SeedCommand(), as: "seed")

    // Record process boot time for the admin server-health uptime metric.
    app.storage[BootDateKey.self] = Date()

    // MARK: - Routes
    try routes(app)

    // MARK: - Background runners
    Task { await app.meetingReminderRunner.start() }
    Task { await app.productivityRunner.start() }
    Task { await app.retentionPurgeRunner.start() }
    app.lifecycle.use(MeetingReminderLifecycle())
    app.lifecycle.use(ProductivityRunnerLifecycle())
    app.lifecycle.use(RetentionPurgeRunnerLifecycle())
}

private struct RetentionPurgeRunnerLifecycle: LifecycleHandler {
    func shutdownAsync(_ application: Application) async {
        await application.retentionPurgeRunner.stop()
    }
}

private struct MeetingReminderLifecycle: LifecycleHandler {
    func shutdownAsync(_ application: Application) async {
        await application.meetingReminderRunner.stop()
    }
}

private struct ProductivityRunnerLifecycle: LifecycleHandler {
    func shutdownAsync(_ application: Application) async {
        await application.productivityRunner.stop()
    }
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
