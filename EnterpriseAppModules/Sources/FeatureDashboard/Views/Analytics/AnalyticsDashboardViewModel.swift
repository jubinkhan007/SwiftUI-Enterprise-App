import Foundation
import SwiftUI
import Domain
import SharedModels

@MainActor
public final class AnalyticsDashboardViewModel: ObservableObject {
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isExporting: Bool = false
    @Published public private(set) var isCreatingSprint: Bool = false
    @Published public var error: Error?
    
    @Published public var leadTime: AnalyticsResponseDTO<Double>?
    @Published public var cycleTime: AnalyticsResponseDTO<Double>?
    @Published public var velocity: AnalyticsResponseDTO<Double>?
    @Published public var throughput: AnalyticsResponseDTO<Int>?
    @Published public var burndownStats: [ProjectDailyStatsDTO] = []
    @Published public var weeklyThroughput: [WeeklyThroughputPointDTO] = []
    @Published public var sprintVelocity: [SprintVelocityPointDTO] = []
    @Published public private(set) var lastUpdated: Date?
    
    @Published public var startDate: Date
    @Published public var endDate: Date
    
    private let repository: AnalyticsRepositoryProtocol
    private let projectId: UUID
    private var lastCacheKey: String?
    
    public init(projectId: UUID, repository: AnalyticsRepositoryProtocol) {
        self.projectId = projectId
        self.repository = repository
        
        let now = Date()
        self.endDate = now
        self.startDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now

        // Best-effort: show cached data immediately if available.
        loadCachedSnapshotIfAvailable()
    }
    
    public func fetchAllAnalytics(forceRefresh: Bool = false) async {
        if !forceRefresh {
            loadCachedSnapshotIfAvailable()
        }

        isLoading = (leadTime == nil && burndownStats.isEmpty)
        error = nil
        defer { isLoading = false }
        
        do {
            async let fetchLead = repository.getLeadTime(projectId: projectId, startDate: startDate, endDate: endDate)
            async let fetchCycle = repository.getCycleTime(projectId: projectId, startDate: startDate, endDate: endDate)
            async let fetchVelocity = repository.getVelocity(projectId: projectId, startDate: startDate, endDate: endDate)
            async let fetchThroughput = repository.getThroughput(projectId: projectId, startDate: startDate, endDate: endDate)
            async let fetchBurndown = repository.getBurndown(projectId: projectId, startDate: startDate, endDate: endDate)
            async let fetchWeekly = repository.getWeeklyThroughput(projectId: projectId, startDate: startDate, endDate: endDate)
            async let fetchSprint = repository.getSprintVelocity(projectId: projectId, startDate: startDate, endDate: endDate)
            
            let (lead, cycle, vel, thr, burn, weekly, sprint) = try await (fetchLead, fetchCycle, fetchVelocity, fetchThroughput, fetchBurndown, fetchWeekly, fetchSprint)
            
            self.leadTime = lead
            self.cycleTime = cycle
            self.velocity = vel
            self.throughput = thr
            self.burndownStats = burn
            self.weeklyThroughput = weekly
            self.sprintVelocity = sprint
            self.lastUpdated = Date()

            saveCachedSnapshot()
        } catch {
            self.error = error
        }
    }

    public func exportBurndownCSV() async throws -> URL {
        isExporting = true
        defer { isExporting = false }

        let data = try await repository.exportBurndownCSV(projectId: projectId, startDate: startDate, endDate: endDate)
        return try writeTempFile(data: data, filename: "burndown-\(projectId.uuidString).csv")
    }

    public func exportPDFReport() async throws -> URL {
        isExporting = true
        defer { isExporting = false }

        let payload = try await repository.getReportPayload(projectId: projectId, startDate: startDate, endDate: endDate)
        let pdf = AnalyticsPDFRenderer.render(report: payload)
        return try writeTempFile(data: pdf, filename: "report-\(projectId.uuidString).pdf")
    }

    public func createSprint(name: String, startDate: Date, endDate: Date, status: SprintStatus) async {
        isCreatingSprint = true
        defer { isCreatingSprint = false }

        do {
            _ = try await repository.createSprint(
                projectId: projectId,
                payload: CreateSprintRequest(name: name, startDate: startDate, endDate: endDate, status: status)
            )
            await fetchAllAnalytics(forceRefresh: true)
        } catch {
            self.error = error
        }
    }
}

// MARK: - Caching

private struct AnalyticsDashboardSnapshot: Codable {
    let projectId: UUID
    let startDate: Date
    let endDate: Date
    let lastUpdated: Date
    let leadTime: AnalyticsResponseDTO<Double>?
    let cycleTime: AnalyticsResponseDTO<Double>?
    let velocity: AnalyticsResponseDTO<Double>?
    let throughput: AnalyticsResponseDTO<Int>?
    let burndownStats: [ProjectDailyStatsDTO]
    let weeklyThroughput: [WeeklyThroughputPointDTO]
    let sprintVelocity: [SprintVelocityPointDTO]
}

private extension AnalyticsDashboardViewModel {
    func cacheKey(projectId: UUID, startDate: Date, endDate: Date) -> String {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]
        return "\(projectId.uuidString)_\(df.string(from: startDate))_\(df.string(from: endDate))"
    }

    func cacheURL(for key: String) throws -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let base else { throw NSError(domain: "AnalyticsCache", code: 1) }
        return base.appendingPathComponent("analytics_dashboard_\(key).json")
    }

    func loadCachedSnapshotIfAvailable() {
        let key = cacheKey(projectId: projectId, startDate: startDate, endDate: endDate)
        guard key != lastCacheKey else { return }
        lastCacheKey = key

        guard let url = try? cacheURL(for: key),
              let data = try? Data(contentsOf: url)
        else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snap = try? decoder.decode(AnalyticsDashboardSnapshot.self, from: data) else { return }

        self.leadTime = snap.leadTime
        self.cycleTime = snap.cycleTime
        self.velocity = snap.velocity
        self.throughput = snap.throughput
        self.burndownStats = snap.burndownStats
        self.weeklyThroughput = snap.weeklyThroughput
        self.sprintVelocity = snap.sprintVelocity
        self.lastUpdated = snap.lastUpdated
    }

    func saveCachedSnapshot() {
        guard let lastUpdated else { return }
        let key = cacheKey(projectId: projectId, startDate: startDate, endDate: endDate)
        lastCacheKey = key

        let snap = AnalyticsDashboardSnapshot(
            projectId: projectId,
            startDate: startDate,
            endDate: endDate,
            lastUpdated: lastUpdated,
            leadTime: leadTime,
            cycleTime: cycleTime,
            velocity: velocity,
            throughput: throughput,
            burndownStats: burndownStats,
            weeklyThroughput: weeklyThroughput,
            sprintVelocity: sprintVelocity
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snap),
              let url = try? cacheURL(for: key)
        else { return }
        try? data.write(to: url, options: [.atomic])
    }

    func writeTempFile(data: Data, filename: String) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: tmp, options: [.atomic])
        return tmp
    }
}
