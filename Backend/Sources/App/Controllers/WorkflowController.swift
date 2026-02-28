import Fluent
import SharedModels
import Vapor

/// Project workflow (statuses) + automation rule management.
/// All routes are protected by Auth & OrgTenantMiddleware.
struct WorkflowController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("projects", ":project_id", "workflow", use: getWorkflow)

        routes.post("projects", ":project_id", "statuses", use: createStatus)
        routes.patch("statuses", ":status_id", use: updateStatus)
        routes.delete("statuses", ":status_id", use: deleteStatus)

        routes.post("projects", ":project_id", "automation-rules", use: createRule)
        routes.patch("automation-rules", ":rule_id", use: updateRule)
        routes.delete("automation-rules", ":rule_id", use: deleteRule)
    }

    // MARK: - GET /api/projects/:project_id/workflow

    @Sendable
    func getWorkflow(req: Request) async throws -> APIResponse<WorkflowBundleDTO> {
        let ctx = try req.orgContext
        let project = try await requireProject(req: req, ctx: ctx)
        let projectId = try project.requireID()

        let statuses = try await CustomStatusModel.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .sort(\.$position, .ascending)
            .all()

        let rules = try await AutomationRuleModel.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .sort(\.$createdAt, .descending)
            .all()

        let payload = WorkflowBundleDTO(
            projectId: projectId,
            workflowVersion: project.workflowVersion,
            statuses: statuses.compactMap { s in
                guard let id = s.id else { return nil }
                return WorkflowStatusDTO(
                    id: id,
                    projectId: s.$project.id,
                    name: s.name,
                    color: s.color,
                    position: s.position,
                    category: s.category,
                    isDefault: s.isDefault,
                    isFinal: s.isFinal,
                    isLocked: s.isLocked,
                    legacyStatus: s.legacyStatus
                )
            },
            rules: rules.compactMap { r in
                guard let id = r.id else { return nil }
                return SharedModels.AutomationRuleDTO(
                    id: id,
                    projectId: r.$project.id,
                    name: r.name,
                    isEnabled: r.isEnabled,
                    triggerType: r.triggerType,
                    triggerConfigJson: r.triggerConfigJson,
                    conditionsJson: r.conditionsJson,
                    actionsJson: r.actionsJson,
                    createdAt: r.createdAt,
                    updatedAt: r.updatedAt
                )
            }
        )

        return .success(payload)
    }

    // MARK: - POST /api/projects/:project_id/statuses

    @Sendable
    func createStatus(req: Request) async throws -> APIResponse<WorkflowStatusDTO> {
        let ctx = try req.orgContext
        let project = try await requireProject(req: req, ctx: ctx)
        let projectId = try project.requireID()
        let payload = try req.content.decode(CreateWorkflowStatusRequest.self)

        let trimmedName = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw Abort(.badRequest, reason: "Status name is required.")
        }

        let color = (payload.color ?? "#4F46E5").trimmingCharacters(in: .whitespacesAndNewlines)
        guard color.hasPrefix("#"), color.count == 7 else {
            throw Abort(.badRequest, reason: "Status color must be a hex string like #RRGGBB.")
        }

        // Unique name per project
        let dupe = try await CustomStatusModel.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .filter(\.$name == trimmedName)
            .count() > 0
        if dupe {
            throw Abort(.conflict, reason: "A status with this name already exists in the project.")
        }

        let status = CustomStatusModel(
            projectId: projectId,
            name: trimmedName,
            color: color,
            position: payload.position ?? 0.0,
            category: payload.category,
            isDefault: payload.isDefault ?? false,
            isFinal: payload.isFinal ?? false,
            isLocked: false,
            legacyStatus: nil
        )

        try await req.db.transaction { db in
            if status.isDefault {
                try await unsetOtherDefaults(projectId: projectId, keepStatusId: nil, db: db)
            } else {
                try await ensureAtLeastOneDefault(projectId: projectId, db: db)
            }

            try await status.save(on: db)
            try await bumpWorkflowVersion(projectId: projectId, db: db)
        }

        let dto = WorkflowStatusDTO(
            id: try status.requireID(),
            projectId: status.$project.id,
            name: status.name,
            color: status.color,
            position: status.position,
            category: status.category,
            isDefault: status.isDefault,
            isFinal: status.isFinal,
            isLocked: status.isLocked,
            legacyStatus: status.legacyStatus
        )
        return .success(dto)
    }

    // MARK: - PATCH /api/statuses/:status_id

    @Sendable
    func updateStatus(req: Request) async throws -> APIResponse<WorkflowStatusDTO> {
        let ctx = try req.orgContext
        guard let statusId = req.parameters.get("status_id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid status ID.")
        }

        let query = CustomStatusModel.query(on: req.db)
            .filter(\.$id == statusId)
            .with(\.$project) { project in
                project.with(\.$space)
            }

        guard let status = try await query.first() else {
            throw Abort(.notFound, reason: "Status not found.")
        }

        // Verify project belongs to org
        guard status.project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Status not found in this organization.")
        }

        if status.isLocked {
            // Allow only safe fields for system statuses (position/category/final/default), but not name/color/legacyStatus.
            let payload = try req.content.decode(UpdateWorkflowStatusRequest.self)
            if payload.name != nil || payload.color != nil {
                throw Abort(.forbidden, reason: "System statuses cannot be renamed or recolored.")
            }
        }

        let payload = try req.content.decode(UpdateWorkflowStatusRequest.self)

        if let name = payload.name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw Abort(.badRequest, reason: "Status name cannot be empty.") }
            if trimmed != status.name {
                let dupe = try await CustomStatusModel.query(on: req.db)
                    .filter(\.$project.$id == status.$project.id)
                    .filter(\.$name == trimmed)
                    .count() > 0
                if dupe { throw Abort(.conflict, reason: "A status with this name already exists in the project.") }
                status.name = trimmed
            }
        }

        if let color = payload.color {
            let trimmed = color.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("#"), trimmed.count == 7 else {
                throw Abort(.badRequest, reason: "Status color must be a hex string like #RRGGBB.")
            }
            status.color = trimmed
        }

        if let position = payload.position {
            status.position = position
        }
        if let category = payload.category {
            status.category = category
        }
        if let isFinal = payload.isFinal {
            status.isFinal = isFinal
        }

        let projectId = status.$project.id

        try await req.db.transaction { db in
            if let isDefault = payload.isDefault {
                status.isDefault = isDefault
                if isDefault {
                    try await unsetOtherDefaults(projectId: projectId, keepStatusId: statusId, db: db)
                } else {
                    try await ensureAtLeastOneDefault(projectId: projectId, db: db)
                }
            }

            try await status.save(on: db)
            try await bumpWorkflowVersion(projectId: projectId, db: db)
        }

        let dto = WorkflowStatusDTO(
            id: try status.requireID(),
            projectId: status.$project.id,
            name: status.name,
            color: status.color,
            position: status.position,
            category: status.category,
            isDefault: status.isDefault,
            isFinal: status.isFinal,
            isLocked: status.isLocked,
            legacyStatus: status.legacyStatus
        )
        return .success(dto)
    }

    // MARK: - DELETE /api/statuses/:status_id

    @Sendable
    func deleteStatus(req: Request) async throws -> HTTPStatus {
        let ctx = try req.orgContext
        guard let statusId = req.parameters.get("status_id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid status ID.")
        }

        let query = CustomStatusModel.query(on: req.db)
            .filter(\.$id == statusId)
            .with(\.$project) { project in
                project.with(\.$space)
            }

        guard let status = try await query.first() else {
            throw Abort(.notFound, reason: "Status not found.")
        }

        guard status.project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Status not found in this organization.")
        }

        if status.isLocked {
            throw Abort(.forbidden, reason: "System statuses cannot be deleted.")
        }

        let projectId = status.$project.id

        // Guard: cannot delete if tasks are attached
        let attached = try await TaskItemModel.query(on: req.db)
            .filter(\.$customStatus.$id == statusId)
            .count()
        if attached > 0 {
            throw Abort(.conflict, reason: "Cannot delete a status that is assigned to tasks.")
        }

        // Guard: cannot delete if it would remove last status
        let totalStatuses = try await CustomStatusModel.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .count()
        if totalStatuses <= 1 {
            throw Abort(.conflict, reason: "A project must have at least one status.")
        }

        try await req.db.transaction { db in
            // Guard: cannot delete last default
            if status.isDefault {
                let otherDefaults = try await CustomStatusModel.query(on: db)
                    .filter(\.$project.$id == projectId)
                    .filter(\.$isDefault == true)
                    .filter(\.$id != statusId)
                    .count()
                if otherDefaults == 0 {
                    throw Abort(.conflict, reason: "Cannot delete the last default status.")
                }
            } else {
                try await ensureAtLeastOneDefault(projectId: projectId, db: db)
            }

            try await status.delete(on: db)
            try await bumpWorkflowVersion(projectId: projectId, db: db)
        }

        return .noContent
    }

    // MARK: - POST /api/projects/:project_id/automation-rules

    @Sendable
    func createRule(req: Request) async throws -> APIResponse<SharedModels.AutomationRuleDTO> {
        let ctx = try req.orgContext
        let project = try await requireProject(req: req, ctx: ctx)
        let projectId = try project.requireID()
        let payload = try req.content.decode(CreateAutomationRuleRequest.self)

        let name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw Abort(.badRequest, reason: "Rule name is required.") }
        guard !payload.triggerType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "triggerType is required.")
        }

        try validateOptionalJson(payload.triggerConfigJson, label: "triggerConfigJson")
        try validateOptionalJson(payload.conditionsJson, label: "conditionsJson")
        try validateOptionalJson(payload.actionsJson, label: "actionsJson")

        let rule = AutomationRuleModel(
            projectId: projectId,
            name: name,
            isEnabled: payload.isEnabled ?? true,
            triggerType: payload.triggerType,
            triggerConfigJson: payload.triggerConfigJson,
            conditionsJson: payload.conditionsJson,
            actionsJson: payload.actionsJson
        )

        try await req.db.transaction { db in
            try await rule.save(on: db)
            try await bumpWorkflowVersion(projectId: projectId, db: db)
        }

        let dto = SharedModels.AutomationRuleDTO(
            id: try rule.requireID(),
            projectId: rule.$project.id,
            name: rule.name,
            isEnabled: rule.isEnabled,
            triggerType: rule.triggerType,
            triggerConfigJson: rule.triggerConfigJson,
            conditionsJson: rule.conditionsJson,
            actionsJson: rule.actionsJson,
            createdAt: rule.createdAt,
            updatedAt: rule.updatedAt
        )
        return .success(dto)
    }

    // MARK: - PATCH /api/automation-rules/:rule_id

    @Sendable
    func updateRule(req: Request) async throws -> APIResponse<SharedModels.AutomationRuleDTO> {
        let ctx = try req.orgContext
        guard let ruleId = req.parameters.get("rule_id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid rule ID.")
        }

        let query = AutomationRuleModel.query(on: req.db)
            .filter(\.$id == ruleId)
            .with(\.$project) { project in
                project.with(\.$space)
            }

        guard let rule = try await query.first() else {
            throw Abort(.notFound, reason: "Rule not found.")
        }

        guard rule.project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Rule not found in this organization.")
        }

        let payload = try req.content.decode(UpdateAutomationRuleRequest.self)

        if let name = payload.name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw Abort(.badRequest, reason: "Rule name cannot be empty.") }
            rule.name = trimmed
        }
        if let enabled = payload.isEnabled {
            rule.isEnabled = enabled
        }
        if let triggerType = payload.triggerType {
            let trimmed = triggerType.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw Abort(.badRequest, reason: "triggerType cannot be empty.") }
            rule.triggerType = trimmed
        }

        if payload.triggerConfigJson != nil {
            try validateOptionalJson(payload.triggerConfigJson, label: "triggerConfigJson")
            rule.triggerConfigJson = payload.triggerConfigJson
        }
        if payload.conditionsJson != nil {
            try validateOptionalJson(payload.conditionsJson, label: "conditionsJson")
            rule.conditionsJson = payload.conditionsJson
        }
        if payload.actionsJson != nil {
            try validateOptionalJson(payload.actionsJson, label: "actionsJson")
            rule.actionsJson = payload.actionsJson
        }

        let projectId = rule.$project.id
        try await req.db.transaction { db in
            try await rule.save(on: db)
            try await bumpWorkflowVersion(projectId: projectId, db: db)
        }

        let dto = SharedModels.AutomationRuleDTO(
            id: try rule.requireID(),
            projectId: rule.$project.id,
            name: rule.name,
            isEnabled: rule.isEnabled,
            triggerType: rule.triggerType,
            triggerConfigJson: rule.triggerConfigJson,
            conditionsJson: rule.conditionsJson,
            actionsJson: rule.actionsJson,
            createdAt: rule.createdAt,
            updatedAt: rule.updatedAt
        )
        return .success(dto)
    }

    // MARK: - DELETE /api/automation-rules/:rule_id

    @Sendable
    func deleteRule(req: Request) async throws -> HTTPStatus {
        let ctx = try req.orgContext
        guard let ruleId = req.parameters.get("rule_id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid rule ID.")
        }

        let query = AutomationRuleModel.query(on: req.db)
            .filter(\.$id == ruleId)
            .with(\.$project) { project in
                project.with(\.$space)
            }

        guard let rule = try await query.first() else {
            throw Abort(.notFound, reason: "Rule not found.")
        }

        guard rule.project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Rule not found in this organization.")
        }

        let projectId = rule.$project.id
        try await req.db.transaction { db in
            try await rule.delete(on: db)
            try await bumpWorkflowVersion(projectId: projectId, db: db)
        }

        return .noContent
    }

    // MARK: - Helpers

    private func requireProject(req: Request, ctx: OrgContext) async throws -> ProjectModel {
        guard let projectId = req.parameters.get("project_id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID.")
        }
        guard let project = try await ProjectModel.query(on: req.db)
            .filter(\.$id == projectId)
            .with(\.$space)
            .first() else {
            throw Abort(.notFound, reason: "Project not found.")
        }
        guard project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Project not found in this organization.")
        }
        return project
    }

    private func bumpWorkflowVersion(projectId: UUID, db: Database) async throws {
        guard let project = try await ProjectModel.query(on: db)
            .filter(\.$id == projectId)
            .first() else { return }
        project.workflowVersion += 1
        try await project.save(on: db)
    }

    private func unsetOtherDefaults(projectId: UUID, keepStatusId: UUID?, db: Database) async throws {
        let defaults = try await CustomStatusModel.query(on: db)
            .filter(\.$project.$id == projectId)
            .filter(\.$isDefault == true)
            .all()
        for s in defaults {
            if let keep = keepStatusId, s.id == keep { continue }
            s.isDefault = false
            try await s.save(on: db)
        }
    }

    private func ensureAtLeastOneDefault(projectId: UUID, db: Database) async throws {
        let defaults = try await CustomStatusModel.query(on: db)
            .filter(\.$project.$id == projectId)
            .filter(\.$isDefault == true)
            .count()
        if defaults > 0 { return }

        // Prefer the standard Todo if present, otherwise pick the lowest position status.
        if let todo = try await CustomStatusModel.query(on: db)
            .filter(\.$project.$id == projectId)
            .filter(\.$legacyStatus == TaskStatus.todo.rawValue)
            .first()
        {
            todo.isDefault = true
            try await todo.save(on: db)
            return
        }

        if let first = try await CustomStatusModel.query(on: db)
            .filter(\.$project.$id == projectId)
            .sort(\.$position, .ascending)
            .first()
        {
            first.isDefault = true
            try await first.save(on: db)
        }
    }

    private func validateOptionalJson(_ value: String?, label: String) throws {
        guard let value else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let data = trimmed.data(using: .utf8) else {
            throw Abort(.badRequest, reason: "\(label) must be valid JSON.")
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw Abort(.badRequest, reason: "\(label) must be valid JSON.")
        }
    }
}
