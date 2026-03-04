import Fluent
import SharedModels
import Vapor

/// Handles KPI and Analytics calculations for a project, establishing Enterprise Trust.
struct AnalyticsController: RouteCollection {
    private static var utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return cal
    }()

    func boot(routes: any RoutesBuilder) throws {
        let projects = routes.grouped("projects").grouped(OrgTenantMiddleware())
        let analytics = projects.grouped(":projectID", "analytics")

        analytics.get("lead-time", use: getLeadTime)
        analytics.get("cycle-time", use: getCycleTime)
        analytics.get("velocity", use: getVelocity)
        analytics.get("throughput", use: getThroughput)
        analytics.get("burndown", use: getBurndown)
        analytics.get("weekly-throughput", use: getWeeklyThroughput)
        analytics.get("sprint-velocity", use: getSprintVelocity)
        analytics.get("report", use: getReportPayload)
        analytics.get("export", "burndown", use: exportBurndownCSV)
    }

    // MARK: - GET /api/projects/:projectID/analytics/export/burndown

    @Sendable
    func exportBurndownCSV(req: Request) async throws -> Response {
        let ctx = try req.orgContext
        let canExport = ctx.permissions.has(.reportsExport) || ctx.permissions.has(.analyticsExport)
        guard canExport else {
            throw Abort(.forbidden, reason: "You do not have permission to export reports (reports.export).")
        }
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }

        let (startDate, endExclusive) = try parseDateRange(req: req)
        
        // Verify project belongs to org
        let project = try await ProjectModel.query(on: req.db)
            .filter(\.$id == projectId)
            .with(\.$space)
            .first()
        guard let project, project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Project not found.")
        }
        
        // Ensure stats exist for requested export window.
        try await DailyStatsAggregator.ensureAggregated(
            for: projectId,
            from: startDate,
            to: endExclusive,
            recompute: false,
            db: req.db,
            logger: req.logger
        )

        let csv = try await ExportService.generateBurndownCSV(projectId: projectId, startDate: startDate, endExclusive: endExclusive, db: req.db)
        
        let response = Response(status: .ok, body: .init(string: csv))
        response.headers.replaceOrAdd(name: .contentType, value: "text/csv")
        response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"burndown-\(projectId.uuidString).csv\"")
        return response
    }

    // MARK: - GET /api/projects/:projectID/analytics/weekly-throughput

    @Sendable
    func getWeeklyThroughput(req: Request) async throws -> APIResponse<[WeeklyThroughputPointDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.analyticsView)
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }

        let (startDate, endExclusive) = try parseDateRange(req: req)
        _ = try await requireProjectInOrg(req: req, projectId: projectId, orgId: ctx.orgId)

        let listIds = try await listIdsForProject(projectId: projectId, db: req.db)
        guard !listIds.isEmpty else { return .success([]) }

        let tasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= startDate)
            .filter(\.$completedAt < endExclusive)
            .all()

        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        func weekStart(_ d: Date) -> Date {
            iso.dateInterval(of: .weekOfYear, for: d)?.start ?? Self.utcCalendar.startOfDay(for: d)
        }

        var countByWeek: [Date: Int] = [:]
        countByWeek.reserveCapacity(16)
        for t in tasks {
            guard let completedAt = t.completedAt else { continue }
            let wk = weekStart(completedAt)
            countByWeek[wk, default: 0] += 1
        }

        let startWeek = weekStart(startDate)
        let endWeek = weekStart(endExclusive.addingTimeInterval(-1))

        var points: [WeeklyThroughputPointDTO] = []
        var cursor = startWeek
        while cursor <= endWeek {
            points.append(WeeklyThroughputPointDTO(weekStart: cursor, completedTasks: countByWeek[cursor] ?? 0))
            guard let next = iso.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }

        return .success(points)
    }

    // MARK: - GET /api/projects/:projectID/analytics/sprint-velocity

    @Sendable
    func getSprintVelocity(req: Request) async throws -> APIResponse<[SprintVelocityPointDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.analyticsView)
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }

        let (startDate, endExclusive) = try parseDateRange(req: req)
        _ = try await requireProjectInOrg(req: req, projectId: projectId, orgId: ctx.orgId)

        let sprints = try await SprintModel.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .filter(\.$startDate < endExclusive)
            .filter(\.$endDate >= startDate)
            .sort(\.$startDate, .ascending)
            .all()

        guard !sprints.isEmpty else { return .success([]) }

        let listIds = try await listIdsForProject(projectId: projectId, db: req.db)
        guard !listIds.isEmpty else { return .success([]) }

        // Fetch all completed tasks in the overall sprint window, then bucket into sprints.
        let minSprintStart = sprints.map { Self.utcCalendar.startOfDay(for: $0.startDate) }.min() ?? startDate
        let maxSprintEndExclusive: Date = {
            let ends = sprints.compactMap { s in
                Self.utcCalendar.date(byAdding: .day, value: 1, to: Self.utcCalendar.startOfDay(for: s.endDate))
            }
            return ends.max() ?? endExclusive
        }()

        let tasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= minSprintStart)
            .filter(\.$completedAt < maxSprintEndExclusive)
            .all()

        struct Window {
            let sprint: SprintModel
            let start: Date
            let endExclusive: Date
        }
        let windows: [Window] = sprints.map { s in
            let start = Self.utcCalendar.startOfDay(for: s.startDate)
            let endExclusive = Self.utcCalendar.date(byAdding: .day, value: 1, to: Self.utcCalendar.startOfDay(for: s.endDate)) ?? s.endDate
            return Window(sprint: s, start: start, endExclusive: endExclusive)
        }

        var totalsBySprintId: [UUID: (points: Double, tasks: Int)] = [:]
        totalsBySprintId.reserveCapacity(windows.count)

        for t in tasks {
            guard let completedAt = t.completedAt else { continue }

            // Find the sprint window that contains this completion timestamp.
            // Sprints should not overlap; first match wins.
            for w in windows where completedAt >= w.start && completedAt < w.endExclusive {
                let sid = w.sprint.id ?? UUID()
                let sp = Double(t.storyPoints ?? 0)
                let current = totalsBySprintId[sid] ?? (0, 0)
                totalsBySprintId[sid] = (current.points + sp, current.tasks + 1)
                break
            }
        }

        let points: [SprintVelocityPointDTO] = windows.compactMap { w in
            guard let sid = w.sprint.id else { return nil }
            let totals = totalsBySprintId[sid] ?? (0, 0)
            return SprintVelocityPointDTO(
                sprintId: sid,
                name: w.sprint.name,
                startDate: w.sprint.startDate,
                endDate: w.sprint.endDate,
                completedPoints: totals.points,
                completedTasks: totals.tasks
            )
        }

        return .success(points)
    }

    // MARK: - GET /api/projects/:projectID/analytics/report

    @Sendable
    func getReportPayload(req: Request) async throws -> APIResponse<AnalyticsReportPayloadDTO> {
        let ctx = try req.orgContext
        let canExport = ctx.permissions.has(.reportsExport) || ctx.permissions.has(.analyticsExport)
        guard canExport else {
            throw Abort(.forbidden, reason: "You do not have permission to export reports (reports.export).")
        }
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }

        let (startDate, endExclusive) = try parseDateRange(req: req)
        let project = try await requireProjectInOrg(req: req, projectId: projectId, orgId: ctx.orgId)

        // Materialize daily stats.
        let recompute = (try? req.query.get(Bool.self, at: "recompute")) ?? false
        try await DailyStatsAggregator.ensureAggregated(
            for: projectId,
            from: startDate,
            to: endExclusive,
            recompute: recompute,
            db: req.db,
            logger: req.logger
        )

        let listIds = try await listIdsForProject(projectId: projectId, db: req.db)

        // Burndown series
        let stats = try await ProjectDailyStatsModel.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .filter(\.$date >= startDate)
            .filter(\.$date < endExclusive)
            .sort(\.$date, .ascending)
            .all()
            .map { $0.toDTO() }

        // KPI metrics
        let lead = try await computeLeadTime(projectId: projectId, listIds: listIds, startDate: startDate, endExclusive: endExclusive, db: req.db)
        let cycle = try await computeCycleTime(projectId: projectId, listIds: listIds, startDate: startDate, endExclusive: endExclusive, db: req.db)
        let vel = try await computeVelocity(projectId: projectId, listIds: listIds, startDate: startDate, endExclusive: endExclusive, db: req.db)
        let thr = try await computeThroughput(projectId: projectId, listIds: listIds, startDate: startDate, endExclusive: endExclusive, db: req.db)

        // Series
        let weeklyResp = try await getWeeklyThroughput(req: req)
        let sprintResp = try await getSprintVelocity(req: req)
        let weekly = weeklyResp.data ?? []
        let sprint = sprintResp.data ?? []

        let payload = AnalyticsReportPayloadDTO(
            projectId: projectId,
            projectName: project.name,
            from: startDate,
            to: endExclusive,
            generatedAt: Date(),
            leadTime: lead,
            cycleTime: cycle,
            velocity: vel,
            throughput: thr,
            burndown: stats,
            weeklyThroughput: weekly,
            sprintVelocity: sprint
        )
        return .success(payload)
    }

    // MARK: - GET /api/projects/:projectID/analytics/lead-time

    @Sendable
    func getLeadTime(req: Request) async throws -> APIResponse<AnalyticsResponseDTO<Double>> {
        let ctx = try req.orgContext
        try req.requirePermission(.analyticsView)
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        
        let (startDate, endExclusive) = try parseDateRange(req: req)

        // Verify project belongs to org
        let project = try await ProjectModel.query(on: req.db)
            .filter(\.$id == projectId)
            .with(\.$space)
            .first()
        guard let project, project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Project not found.")
        }

        let lists = try await TaskListModel.query(on: req.db).filter(\.$project.$id == projectId).all()
        let listIds = lists.compactMap { $0.id }

        // Fetch completed tasks in the date range
        let tasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= startDate)
            .filter(\.$completedAt < endExclusive)
            .all()

        var leadTimes: [Double] = []
        for task in tasks {
            if let created = task.createdAt, let completed = task.completedAt {
                let diff = completed.timeIntervalSince(created)
                if diff > 0 {
                    leadTimes.append(diff)
                }
            }
        }

        let sampleSize = leadTimes.count
        leadTimes.sort()

        let p50 = calculatePercentile(leadTimes, percentile: 0.50)
        let p90 = calculatePercentile(leadTimes, percentile: 0.90)
        let avg = leadTimes.isEmpty ? 0.0 : (leadTimes.reduce(0, +) / Double(sampleSize))

        let dto = AnalyticsResponseDTO(
            metric: "Lead Time (seconds)",
            value: avg,
            p50: p50,
            p90: p90,
            sampleSize: sampleSize,
            from: startDate,
            to: endExclusive,
            filters: [:]
        )
        return .success(dto)
    }

    // MARK: - GET /api/projects/:projectID/analytics/cycle-time

    @Sendable
    func getCycleTime(req: Request) async throws -> APIResponse<AnalyticsResponseDTO<Double>> {
        let ctx = try req.orgContext
        try req.requirePermission(.analyticsView)
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        
        let (startDate, endExclusive) = try parseDateRange(req: req)

        // Verify project belongs to org
        let project = try await ProjectModel.query(on: req.db)
            .filter(\.$id == projectId)
            .with(\.$space)
            .first()
        guard let project, project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Project not found.")
        }

        let lists = try await TaskListModel.query(on: req.db).filter(\.$project.$id == projectId).all()
        let listIds = lists.compactMap { $0.id }

        // Fetch completed tasks in the date range
        let tasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= startDate)
            .filter(\.$completedAt < endExclusive)
            .all()

        let taskIds = tasks.compactMap { $0.id }
        
        // Fetch statuses for this project to know which are "active"
        let projectStatuses = try await CustomStatusModel.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .all()
        let activeStatusIds = projectStatuses.filter { $0.category == .active }.compactMap { $0.id?.uuidString }
        
        // Fetch activity logs to find when tasks first became "active"
        let activities = try await TaskActivityModel.query(on: req.db)
            .filter(\.$task.$id ~~ taskIds)
            .filter(\.$type == .statusChanged)
            .sort(\.$createdAt, .ascending)
            .all()

        // Group activities by task
        var firstActiveDateByTask: [UUID: Date] = [:]
        for act in activities {
            let tid = act.$task.id
            guard firstActiveDateByTask[tid] == nil else { continue }
            
            // Check if it transitioned TO an active status
            if let toStatusId = act.metadata?["to_status_id"], activeStatusIds.contains(toStatusId) {
                firstActiveDateByTask[tid] = act.createdAt
            } else if let toStatusLegacy = act.metadata?["to"], toStatusLegacy == TaskStatus.inProgress.rawValue || toStatusLegacy == TaskStatus.inReview.rawValue {
                firstActiveDateByTask[tid] = act.createdAt
            }
        }

        var cycleTimes: [Double] = []
        for task in tasks {
            if let completed = task.completedAt, let tid = task.id, let started = firstActiveDateByTask[tid] {
                let diff = completed.timeIntervalSince(started)
                if diff > 0 {
                    cycleTimes.append(diff)
                }
            }
        }

        let sampleSize = cycleTimes.count
        cycleTimes.sort()

        let p50 = calculatePercentile(cycleTimes, percentile: 0.50)
        let p90 = calculatePercentile(cycleTimes, percentile: 0.90)
        let avg = cycleTimes.isEmpty ? 0.0 : (cycleTimes.reduce(0, +) / Double(sampleSize))

        let dto = AnalyticsResponseDTO(
            metric: "Cycle Time (seconds)",
            value: avg,
            p50: p50,
            p90: p90,
            sampleSize: sampleSize,
            from: startDate,
            to: endExclusive,
            filters: [:]
        )
        return .success(dto)
    }

    // MARK: - GET /api/projects/:projectID/analytics/velocity

    @Sendable
    func getVelocity(req: Request) async throws -> APIResponse<AnalyticsResponseDTO<Double>> {
        let ctx = try req.orgContext
        try req.requirePermission(.analyticsView)
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        
        let (startDate, endExclusive) = try parseDateRange(req: req)

        let lists = try await TaskListModel.query(on: req.db).filter(\.$project.$id == projectId).all()
        let listIds = lists.compactMap { $0.id }

        let tasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= startDate)
            .filter(\.$completedAt < endExclusive)
            .all()

        let totalPoints = tasks.reduce(0.0) { $0 + Double($1.storyPoints ?? 0) }

        let dto = AnalyticsResponseDTO(
            metric: "Velocity (Story Points)",
            value: totalPoints,
            sampleSize: tasks.count,
            from: startDate,
            to: endExclusive,
            filters: [:]
        )
        return .success(dto)
    }

    // MARK: - GET /api/projects/:projectID/analytics/throughput

    @Sendable
    func getThroughput(req: Request) async throws -> APIResponse<AnalyticsResponseDTO<Int>> {
        let ctx = try req.orgContext
        try req.requirePermission(.analyticsView)
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        
        let (startDate, endExclusive) = try parseDateRange(req: req)

        let lists = try await TaskListModel.query(on: req.db).filter(\.$project.$id == projectId).all()
        let listIds = lists.compactMap { $0.id }

        let count = try await TaskItemModel.query(on: req.db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= startDate)
            .filter(\.$completedAt < endExclusive)
            .count()

        let dto = AnalyticsResponseDTO(
            metric: "Throughput (Tasks Completed)",
            value: count,
            sampleSize: count,
            from: startDate,
            to: endExclusive,
            filters: [:]
        )
        return .success(dto)
    }

    // MARK: - GET /api/projects/:projectID/analytics/burndown

    @Sendable
    func getBurndown(req: Request) async throws -> APIResponse<[ProjectDailyStatsDTO]> {
        let ctx = try req.orgContext
        try req.requirePermission(.analyticsView)
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        
        let (startDate, endExclusive) = try parseDateRange(req: req)
        let recompute = (try? req.query.get(Bool.self, at: "recompute")) ?? false

        // Verify project belongs to org
        let project = try await ProjectModel.query(on: req.db)
            .filter(\.$id == projectId)
            .with(\.$space)
            .first()
        guard let project, project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Project not found.")
        }

        // Ensure the materialized stats exist for this range (dev-friendly; keeps charts non-empty).
        try await DailyStatsAggregator.ensureAggregated(
            for: projectId,
            from: startDate,
            to: endExclusive,
            recompute: recompute,
            db: req.db,
            logger: req.logger
        )

        let stats = try await ProjectDailyStatsModel.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .filter(\.$date >= startDate)
            .filter(\.$date < endExclusive)
            .sort(\.$date, .ascending)
            .all()

        return .success(stats.map { $0.toDTO() })
    }

    // MARK: - Helpers

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

    private func listIdsForProject(projectId: UUID, db: Database) async throws -> [UUID] {
        let lists = try await TaskListModel.query(on: db)
            .filter(\.$project.$id == projectId)
            .all()
        return lists.compactMap { $0.id }
    }

    private func computeLeadTime(projectId: UUID, listIds: [UUID], startDate: Date, endExclusive: Date, db: Database) async throws -> AnalyticsResponseDTO<Double> {
        let tasks = try await TaskItemModel.query(on: db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= startDate)
            .filter(\.$completedAt < endExclusive)
            .all()

        var leadTimes: [Double] = []
        for task in tasks {
            if let created = task.createdAt, let completed = task.completedAt {
                let diff = completed.timeIntervalSince(created)
                if diff > 0 { leadTimes.append(diff) }
            }
        }

        let sampleSize = leadTimes.count
        leadTimes.sort()
        let p50 = calculatePercentile(leadTimes, percentile: 0.50)
        let p90 = calculatePercentile(leadTimes, percentile: 0.90)
        let avg = leadTimes.isEmpty ? 0.0 : (leadTimes.reduce(0, +) / Double(sampleSize))

        return AnalyticsResponseDTO(
            metric: "Lead Time (seconds)",
            value: avg,
            p50: p50,
            p90: p90,
            sampleSize: sampleSize,
            from: startDate,
            to: endExclusive,
            filters: [:]
        )
    }

    private func computeCycleTime(projectId: UUID, listIds: [UUID], startDate: Date, endExclusive: Date, db: Database) async throws -> AnalyticsResponseDTO<Double> {
        let tasks = try await TaskItemModel.query(on: db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= startDate)
            .filter(\.$completedAt < endExclusive)
            .all()

        let taskIds = tasks.compactMap { $0.id }
        if taskIds.isEmpty {
            return AnalyticsResponseDTO(metric: "Cycle Time (seconds)", value: 0, sampleSize: 0, from: startDate, to: endExclusive, filters: [:])
        }

        let projectStatuses = try await CustomStatusModel.query(on: db)
            .filter(\.$project.$id == projectId)
            .all()
        let activeStatusIds = Set(projectStatuses.filter { $0.category == .active }.compactMap { $0.id?.uuidString })

        let activities = try await TaskActivityModel.query(on: db)
            .filter(\.$task.$id ~~ taskIds)
            .filter(\.$type == .statusChanged)
            .sort(\.$createdAt, .ascending)
            .all()

        var firstActiveDateByTask: [UUID: Date] = [:]
        for act in activities {
            let tid = act.$task.id
            guard firstActiveDateByTask[tid] == nil else { continue }

            if let toStatusId = act.metadata?["to_status_id"], activeStatusIds.contains(toStatusId) {
                if let created = act.createdAt { firstActiveDateByTask[tid] = created }
            } else if let toStatusLegacy = act.metadata?["to"], toStatusLegacy == TaskStatus.inProgress.rawValue || toStatusLegacy == TaskStatus.inReview.rawValue {
                if let created = act.createdAt { firstActiveDateByTask[tid] = created }
            }
        }

        var cycleTimes: [Double] = []
        for task in tasks {
            if let completed = task.completedAt, let tid = task.id, let started = firstActiveDateByTask[tid] {
                let diff = completed.timeIntervalSince(started)
                if diff > 0 { cycleTimes.append(diff) }
            }
        }

        let sampleSize = cycleTimes.count
        cycleTimes.sort()
        let p50 = calculatePercentile(cycleTimes, percentile: 0.50)
        let p90 = calculatePercentile(cycleTimes, percentile: 0.90)
        let avg = cycleTimes.isEmpty ? 0.0 : (cycleTimes.reduce(0, +) / Double(sampleSize))

        return AnalyticsResponseDTO(
            metric: "Cycle Time (seconds)",
            value: avg,
            p50: p50,
            p90: p90,
            sampleSize: sampleSize,
            from: startDate,
            to: endExclusive,
            filters: [:]
        )
    }

    private func computeVelocity(projectId: UUID, listIds: [UUID], startDate: Date, endExclusive: Date, db: Database) async throws -> AnalyticsResponseDTO<Double> {
        let tasks = try await TaskItemModel.query(on: db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= startDate)
            .filter(\.$completedAt < endExclusive)
            .all()

        let totalPoints = tasks.reduce(0.0) { $0 + Double($1.storyPoints ?? 0) }
        return AnalyticsResponseDTO(metric: "Velocity (Story Points)", value: totalPoints, sampleSize: tasks.count, from: startDate, to: endExclusive, filters: [:])
    }

    private func computeThroughput(projectId: UUID, listIds: [UUID], startDate: Date, endExclusive: Date, db: Database) async throws -> AnalyticsResponseDTO<Int> {
        let count = try await TaskItemModel.query(on: db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= startDate)
            .filter(\.$completedAt < endExclusive)
            .count()

        return AnalyticsResponseDTO(metric: "Throughput (Tasks Completed)", value: count, sampleSize: count, from: startDate, to: endExclusive, filters: [:])
    }

    /// Parses `start_date` and `end_date` query params and returns a UTC-normalized range
    /// `[start, endExclusive)` suitable for DB querying.
    private func parseDateRange(req: Request) throws -> (Date, Date) {
        let now = Date()
        let todayStart = Self.utcCalendar.startOfDay(for: now)
        let thirtyDaysAgo = Self.utcCalendar.date(byAdding: .day, value: -30, to: todayStart)!
        
        let startStr = try? req.query.get(String.self, at: "start_date")
        let endStr = try? req.query.get(String.self, at: "end_date")
        
        var startDate = thirtyDaysAgo
        var endDate = todayStart
        
        let formatter = ISO8601DateFormatter()
        
        if let startStr, let parsedStart = formatter.date(from: startStr) {
            startDate = parsedStart
        } else if let startStr, let timestamp = Double(startStr) {
            startDate = Date(timeIntervalSince1970: timestamp)
        }
        
        if let endStr, let parsedEnd = formatter.date(from: endStr) {
            endDate = parsedEnd
        } else if let endStr, let timestamp = Double(endStr) {
            endDate = Date(timeIntervalSince1970: timestamp)
        }

        let startDay = Self.utcCalendar.startOfDay(for: startDate)
        let endDay = Self.utcCalendar.startOfDay(for: endDate)
        let endExclusive = Self.utcCalendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay

        return (startDay, endExclusive)
    }

    private func calculatePercentile(_ sortedData: [Double], percentile: Double) -> Double? {
        guard !sortedData.isEmpty else { return nil }
        if sortedData.count == 1 { return sortedData[0] }
        
        let index = Double(sortedData.count - 1) * percentile
        let lower = Int(floor(index))
        let upper = Int(ceil(index))
        
        if lower == upper {
            return sortedData[lower]
        }
        
        let weight = index - Double(lower)
        return sortedData[lower] * (1.0 - weight) + sortedData[upper] * weight
    }
}
