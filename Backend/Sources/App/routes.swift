import Vapor

/// Registers all application routes.
func routes(_ app: Application) throws {
    // Health check
    app.get("health") { req async -> [String: String] in
        [
            "status": "ok",
            "maxBodySize": "\(app.routes.defaultMaxBodySize.value)"
        ]
    }

    // API v1 group
    let api = app.grouped("api")

    let authController = AuthController()
    try api.register(collection: authController)

    // Web Admin Panel: cookie-session auth (login/refresh/logout/me)
    let adminAuthController = AdminAuthController()
    try api.register(collection: adminAuthController)

    // Web Admin Panel: super-admin platform routes (cookie auth + super-admin guard)
    let superAdminAPI = api
        .grouped("admin")
        .grouped(CookieAuthMiddleware())
        .grouped(SuperAdminMiddleware())
    let adminController = AdminController()
    try superAdminAPI.register(collection: adminController)

    // Web Admin Panel: org-admin tenant routes (cookie auth + org membership + admin role)
    let orgAdminAPI = api
        .grouped("admin", "org")
        .grouped(CookieAuthMiddleware())
        .grouped(OrgTenantMiddleware())
        .grouped(RequireOrgAdminMiddleware())
    let orgAdminController = OrgAdminController()
    try orgAdminAPI.register(collection: orgAdminController)

    // Setup authenticated API routes
    let authenticatedAPI = api.grouped(AnyAuthMiddleware())
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

    let workflowController = WorkflowController()
    try orgScopedAPI.register(collection: workflowController)

    let timeLogController = TimeLogController()
    try authenticatedAPI.register(collection: timeLogController)

    let attachmentController = AttachmentController()
    try orgScopedAPI.register(collection: attachmentController)

    // Phase 16: Integrations
    let apiKeyController = APIKeyController()
    try orgScopedAPI.register(collection: apiKeyController)
    let webhookController = WebhookController()
    try orgScopedAPI.register(collection: webhookController)

    let notificationController = NotificationController()
    try orgScopedAPI.register(collection: notificationController)

    let conversationController = ConversationController()
    try orgScopedAPI.register(collection: conversationController)

    let messageController = MessageController()
    try orgScopedAPI.register(collection: messageController)

    let presenceController = PresenceController()
    try orgScopedAPI.register(collection: presenceController)

    let meetingController = MeetingController()
    try orgScopedAPI.register(collection: meetingController)

    let meetingNotesController = MeetingNotesController()
    try orgScopedAPI.register(collection: meetingNotesController)

    let draftController = DraftController()
    try orgScopedAPI.register(collection: draftController)

    let scheduledMessageController = ScheduledMessageController()
    try orgScopedAPI.register(collection: scheduledMessageController)

    let templateController = TemplateController()
    try orgScopedAPI.register(collection: templateController)

    let reminderController = ReminderController()
    try orgScopedAPI.register(collection: reminderController)

    let callController = CallController()
    try orgScopedAPI.register(collection: callController)

    let analyticsController = AnalyticsController()
    try authenticatedAPI.register(collection: analyticsController)

    let sprintController = SprintController()
    try authenticatedAPI.register(collection: sprintController)

    let agileController = AgileController()
    try authenticatedAPI.register(collection: agileController)

    let releaseController = ReleaseController()
    try authenticatedAPI.register(collection: releaseController)

    // Phase 11: Real-time collaboration
    RealtimeController.register(on: app)
}
