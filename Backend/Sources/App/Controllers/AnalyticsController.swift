import Fluent
import SharedModels
import Vapor

/// Handles KPI and Analytics calculations for a project, establishing Enterprise Trust.
struct AnalyticsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let projects = routes.grouped("projects").grouped(OrgTenantMiddleware())
        let analytics = projects.grouped(":projectID", "analytics")

        analytics.get("lead-time", use: getLeadTime)
        analytics.get("cycle-time", use: getCycleTime)
        analytics.get("velocity", use: getVelocity)
        analytics.get("throughput", use: getThroughput)
        analytics.get("burndown", use: getBurndown)
        analytics.get("export", "burndown", use: exportBurndownCSV)
    }

    // MARK: - GET /api/projects/:projectID/analytics/export/burndown

    @Sendable
    func exportBurndownCSV(req: Request) async throws -> Response {
        let ctx = try req.orgContext
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        
        // Verify project belongs to org
        let project = try await ProjectModel.query(on: req.db)
            .filter(\.$id == projectId)
            .with(\.$space)
            .first()
        guard let project, project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Project not found.")
        }
        
        let csv = try await ExportService.generateBurndownCSV(projectId: projectId, db: req.db)
        
        let response = Response(status: .ok, body: .init(string: csv))
        response.headers.replaceOrAdd(name: .contentType, value: "text/csv")
        response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"burndown-\(projectId.uuidString).csv\"")
        return response
    }

    // MARK: - GET /api/projects/:projectID/analytics/lead-time

    @Sendable
    func getLeadTime(req: Request) async throws -> APIResponse<AnalyticsResponseDTO<Double>> {
        let ctx = try req.orgContext
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        
        let (startDate, endDate) = try parseDateRange(req: req)

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
            .filter(\.$completedAt <= endDate)
            .filter(\.$status != .cancelled) // typically exclude cancelled
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
            to: endDate,
            filters: [:]
        )
        return .success(dto)
    }

    // MARK: - GET /api/projects/:projectID/analytics/cycle-time

    @Sendable
    func getCycleTime(req: Request) async throws -> APIResponse<AnalyticsResponseDTO<Double>> {
        let ctx = try req.orgContext
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        
        let (startDate, endDate) = try parseDateRange(req: req)

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
            .filter(\.$completedAt <= endDate)
            .filter(\.$status != .cancelled)
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
            to: endDate,
            filters: [:]
        )
        return .success(dto)
    }

    // MARK: - GET /api/projects/:projectID/analytics/velocity

    @Sendable
    func getVelocity(req: Request) async throws -> APIResponse<AnalyticsResponseDTO<Double>> {
        let ctx = try req.orgContext
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        
        let (startDate, endDate) = try parseDateRange(req: req)

        let lists = try await TaskListModel.query(on: req.db).filter(\.$project.$id == projectId).all()
        let listIds = lists.compactMap { $0.id }

        let tasks = try await TaskItemModel.query(on: req.db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= startDate)
            .filter(\.$completedAt <= endDate)
            .filter(\.$status != .cancelled)
            .all()

        let totalPoints = tasks.reduce(0.0) { $0 + Double($1.storyPoints ?? 0) }

        let dto = AnalyticsResponseDTO(
            metric: "Velocity (Story Points)",
            value: totalPoints,
            sampleSize: tasks.count,
            from: startDate,
            to: endDate,
            filters: [:]
        )
        return .success(dto)
    }

    // MARK: - GET /api/projects/:projectID/analytics/throughput

    @Sendable
    func getThroughput(req: Request) async throws -> APIResponse<AnalyticsResponseDTO<Int>> {
        let ctx = try req.orgContext
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        
        let (startDate, endDate) = try parseDateRange(req: req)

        let lists = try await TaskListModel.query(on: req.db).filter(\.$project.$id == projectId).all()
        let listIds = lists.compactMap { $0.id }

        let count = try await TaskItemModel.query(on: req.db)
            .filter(\.$list.$id ~~ listIds)
            .filter(\.$completedAt != nil)
            .filter(\.$completedAt >= startDate)
            .filter(\.$completedAt <= endDate)
            .filter(\.$status != .cancelled)
            .count()

        let dto = AnalyticsResponseDTO(
            metric: "Throughput (Tasks Completed)",
            value: count,
            sampleSize: count,
            from: startDate,
            to: endDate,
            filters: [:]
        )
        return .success(dto)
    }

    // MARK: - GET /api/projects/:projectID/analytics/burndown

    @Sendable
    func getBurndown(req: Request) async throws -> APIResponse<[ProjectDailyStatsDTO]> {
        let ctx = try req.orgContext
        guard let projectId = req.parameters.get("projectID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Project ID.")
        }
        
        let (startDate, endDate) = try parseDateRange(req: req)

        // Verify project belongs to org
        let project = try await ProjectModel.query(on: req.db)
            .filter(\.$id == projectId)
            .with(\.$space)
            .first()
        guard let project, project.space.$organization.id == ctx.orgId else {
            throw Abort(.notFound, reason: "Project not found.")
        }

        let stats = try await ProjectDailyStatsModel.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .filter(\.$date >= startDate)
            .filter(\.$date <= endDate)
            .sort(\.$date, .ascending)
            .all()

        return .success(stats.map { $0.toDTO() })
    }

    // MARK: - Helpers

    private func parseDateRange(req: Request) throws -> (Date, Date) {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        
        let startStr = try? req.query.get(String.self, at: "start_date")
        let endStr = try? req.query.get(String.self, at: "end_date")
        
        var startDate = thirtyDaysAgo
        var endDate = now
        
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
        
        return (startDate, endDate)
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
