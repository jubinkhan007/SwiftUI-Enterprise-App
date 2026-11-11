import Fluent
import SharedModels
import Vapor

/// Phase 13: Release planning (versions).
struct ReleaseController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let projects = routes.grouped("projects").grouped(OrgTenantMiddleware())
        let projectReleases = projects.grouped(":projectID", "releases")
        projectReleases.get(use: list)
        projectReleases.post(use: create)

        let releases = routes.grouped("releases").grouped(OrgTenantMiddleware())
        let release = releases.grouped(":releaseID")
        release.patch(use: update)
        release.get("progress", use: progress)
        release.get("issues", use: listIssues)
        release.get("changelog", use: changelog)
        release.post("release", use: finalize)
    }

    // MARK: - PATCH /api/releases/:releaseID

    @Sendable
    func update(req: Request) async throws -> APIResponse<ReleaseDTO> {
        let ctx = try req.orgContext
        try req.requirePermission(.releasesManage)
        let release = try await requireReleaseInOrg(req: req, orgId: ctx.orgId)
        let payload = try req.content.decode(UpdateReleaseRequest.self)

        if let name = payload.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            release.name = name
        }
        if let description = payload.description {
            let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
            release.description = trimmed.isEmpty ? nil : trimmed
        }
        if let releaseDate = payload.releaseDate {
            release.releaseDate = releaseDate
        }
        if let status = payload.status {
            release.status = status
            if status == .released && release.releasedAt == nil {
                release.releasedAt = Date()
            }
        }
        if let isLocked = payload.isLocked {
            release.isLocked = isLocked
        }

        try await release.save(on: req.db)
        return .success(release.toDTO())
    }

    // MARK: - GET /api/projects/:projectID/releases

    @Sendable
    func list(req: Request) async throws -> APIResponse<[ReleaseDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.projectsRead)
        let projectId = try requireProjectId(req)
        _ = try await requireProjectInOrg(req: req, projectId: projectId, orgId: ctx.orgId)

        let rows = try await ReleaseModel.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .sort(\.$releaseDate, .ascending)
            .sort(\.$createdAt, .ascending)
            .all()

        return .success(rows.map { $0.toDTO() })
    }

    // MARK: - POST /api/projects/:projectID/releases

    @Sendable
    func create(req: Request) async throws -> APIResponse<ReleaseDTO> {
        let ctx = try req.orgContext
        try req.requirePermission(.releasesManage)
        let projectId = try requireProjectId(req)
        _ = try await requireProjectInOrg(req: req, projectId: projectId, orgId: ctx.orgId)

        let payload = try req.content.decode(CreateReleaseRequest.self)
        let name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw Abort(.badRequest, reason: "Release name is required.")
        }

        let model = ReleaseModel(
            projectId: projectId,
            name: name,
            description: payload.description,
            releaseDate: payload.releaseDate
        )
        try await model.save(on: req.db)
        return .success(model.toDTO())
    }

    // MARK: - GET /api/releases/:releaseID/progress

    @Sendable
    func progress(req: Request) async throws -> APIResponse<ReleaseProgressDTO> {
        let ctx = try req.orgContext
        try req.requirePermission(.projectsRead)
        let release = try await requireReleaseInOrg(req: req, orgId: ctx.orgId)
        let releaseId = try release.requireID()

        let issues = try await TaskItemModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$affectedVersion.$id == releaseId)
            .filter(\.$archivedAt == nil)
            .all()

        let totalIssues = issues.count
        let doneIssues = issues.filter { $0.completedAt != nil || $0.status == .done }.count
        let remainingIssues = max(totalIssues - doneIssues, 0)

        let totalPoints = issues.reduce(0) { $0 + ($1.storyPoints ?? 0) }
        let donePoints = issues.reduce(0) { acc, t in
            let isDone = t.completedAt != nil || t.status == .done
            return acc + (isDone ? (t.storyPoints ?? 0) : 0)
        }

        let bugs = issues.filter { $0.taskType == .bug }
        let criticalBugCount = bugs.filter { $0.bugSeverityRaw == BugSeverity.critical.rawValue }.count

        return .success(
            ReleaseProgressDTO(
                releaseId: releaseId,
                totalIssues: totalIssues,
                doneIssues: doneIssues,
                remainingIssues: remainingIssues,
                totalPoints: totalPoints,
                donePoints: donePoints,
                bugCount: bugs.count,
                criticalBugCount: criticalBugCount
            )
        )
    }

    // MARK: - POST /api/releases/:releaseID/release

    @Sendable
    func finalize(req: Request) async throws -> APIResponse<ReleaseDTO> {
        let ctx = try req.orgContext
        try req.requirePermission(.releasesManage)
        let release = try await requireReleaseInOrg(req: req, orgId: ctx.orgId)

        let payload = try? req.content.decode(FinalizeReleaseRequest.self)

        if release.status != .released {
            release.status = .released
        }
        if release.releasedAt == nil {
            release.releasedAt = Date()
        }
        if let lock = payload?.lock, lock {
            release.isLocked = true
        }

        try await release.save(on: req.db)
        return .success(release.toDTO())
    }

    // MARK: - GET /api/releases/:releaseID/issues

    @Sendable
    func listIssues(req: Request) async throws -> APIResponse<[TaskItemDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.projectsRead)
        let release = try await requireReleaseInOrg(req: req, orgId: ctx.orgId)
        let releaseId = try release.requireID()

        let rows = try await TaskItemModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$affectedVersion.$id == releaseId)
            .filter(\.$archivedAt == nil)
            .sort(\.$completedAt, .descending)
            .sort(\.$updatedAt, .descending)
            .all()

        return .success(rows.map { $0.toDTO() })
    }

    // MARK: - GET /api/releases/:releaseID/changelog

    @Sendable
    func changelog(req: Request) async throws -> APIResponse<ReleaseChangelogDTO> {
        let ctx = try req.orgContext
        try req.requirePermission(.projectsRead)
        let release = try await requireReleaseInOrg(req: req, orgId: ctx.orgId)
        let releaseId = try release.requireID()

        let rows = try await TaskItemModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$affectedVersion.$id == releaseId)
            .filter(\.$archivedAt == nil)
            .sort(\.$completedAt, .descending)
            .sort(\.$updatedAt, .descending)
            .all()

        let dtos = rows.map { $0.toDTO() }
        let epics = dtos.filter { $0.taskType == .epic }
        let stories = dtos.filter { $0.taskType == .story }
        let bugs = dtos.filter { $0.taskType == .bug }
        let tasks = dtos.filter { $0.taskType == .task || $0.taskType == .subtask }

        var blockers: [String] = []
        let openCriticalBugs = bugs.filter {
            ($0.completedAt == nil && $0.status != .done) &&
            ($0.bugSeverity == .critical || $0.priority == .critical)
        }
        if !openCriticalBugs.isEmpty {
            blockers.append("\(openCriticalBugs.count) unresolved critical bug(s) must be closed before release.")
        }
        let openIssues = dtos.filter { $0.completedAt == nil && $0.status != .done }
        if !openIssues.isEmpty && dtos.count == openIssues.count {
            blockers.append("0 completed issues in release scope (\(openIssues.count) still open).")
        }

        let readyToShip = blockers.isEmpty
        var lines: [String] = []
        lines.append("# Release Notes: \(release.name)")
        lines.append("")
        lines.append("- **Status**: \(release.status.rawValue.capitalized)\(release.isLocked ? " (Locked)" : "")")
        if let planned = release.releaseDate {
            lines.append("- **Target Date**: \(ISO8601DateFormatter().string(from: planned))")
        }
        if let shipped = release.releasedAt {
            lines.append("- **Shipped At**: \(ISO8601DateFormatter().string(from: shipped))")
        }
        lines.append("- **Deployment Readiness Gate**: \(readyToShip ? "READY TO SHIP" : "BLOCKED (\(blockers.joined(separator: "; ")))")")

        if let desc = release.description, !desc.isEmpty {
            lines.append("")
            lines.append("## Overview")
            lines.append(desc)
        }

        func formatSection(title: String, items: [TaskItemDTO]) {
            guard !items.isEmpty else { return }
            lines.append("")
            lines.append("## \(title) (\(items.count))")
            for item in items {
                let keyPrefix = item.issueKey.map { "`\($0)` " } ?? ""
                let stateBadge = (item.completedAt != nil || item.status == .done) ? "✅" : "⏳"
                let pts = item.storyPoints.map { " (\($0) pts)" } ?? ""
                lines.append("- \(stateBadge) \(keyPrefix)\(item.title)\(pts)")
            }
        }

        formatSection(title: "Epics & Milestones", items: epics)
        formatSection(title: "Features & User Stories", items: stories)
        formatSection(title: "Bug Fixes & Stability", items: bugs)
        formatSection(title: "Engineering Tasks", items: tasks)

        let markdown = lines.joined(separator: "\n")
        return .success(
            ReleaseChangelogDTO(
                releaseId: releaseId,
                versionName: release.name,
                generatedAt: Date(),
                markdown: markdown,
                epics: epics,
                stories: stories,
                bugs: bugs,
                tasks: tasks,
                readyToShip: readyToShip,
                blockers: blockers
            )
        )
    }

    // MARK: - Helpers

    private func requireProjectId(_ req: Request) throws -> UUID {
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        return projectId
    }

    private func requireProjectInOrg(req: Request, projectId: UUID, orgId: UUID) async throws -> ProjectModel {
        let project = try await ProjectModel.query(on: req.db)
            .filter(\.$id == projectId)
            .with(\.$space)
            .first()
        guard let project, project.space.$organization.id == orgId else {
            throw Abort(.notFound, reason: "Project not found.")
        }
        return project
    }

    private func requireReleaseInOrg(req: Request, orgId: UUID) async throws -> ReleaseModel {
        guard let releaseId = req.parameters.get("releaseID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid release ID.")
        }

        let releases = try await ReleaseModel.query(on: req.db)
            .filter(\.$id == releaseId)
            .with(\.$project) { project in project.with(\.$space) }
            .limit(1)
            .all()
        guard let release = releases.first else {
            throw Abort(.notFound, reason: "Release not found.")
        }

        guard release.project.space.$organization.id == orgId else {
            throw Abort(.notFound, reason: "Release not found.")
        }
        return release
    }
}
