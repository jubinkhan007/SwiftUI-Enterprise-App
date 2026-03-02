import Foundation
import SwiftUI
import Domain
import SharedModels

@MainActor
public final class AnalyticsDashboardViewModel: ObservableObject {
    @Published public private(set) var isLoading: Bool = false
    @Published public var error: Error?
    
    @Published public var leadTime: AnalyticsResponseDTO<Double>?
    @Published public var cycleTime: AnalyticsResponseDTO<Double>?
    @Published public var velocity: AnalyticsResponseDTO<Double>?
    @Published public var throughput: AnalyticsResponseDTO<Int>?
    @Published public var burndownStats: [ProjectDailyStatsDTO] = []
    
    @Published public var startDate: Date
    @Published public var endDate: Date
    
    private let repository: AnalyticsRepositoryProtocol
    private let projectId: UUID
    
    public init(projectId: UUID, repository: AnalyticsRepositoryProtocol) {
        self.projectId = projectId
        self.repository = repository
        
        let now = Date()
        self.endDate = now
        self.startDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
    }
    
    public func fetchAllAnalytics() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            async let fetchLead = repository.getLeadTime(projectId: projectId, startDate: startDate, endDate: endDate)
            async let fetchCycle = repository.getCycleTime(projectId: projectId, startDate: startDate, endDate: endDate)
            async let fetchVelocity = repository.getVelocity(projectId: projectId, startDate: startDate, endDate: endDate)
            async let fetchThroughput = repository.getThroughput(projectId: projectId, startDate: startDate, endDate: endDate)
            async let fetchBurndown = repository.getBurndown(projectId: projectId, startDate: startDate, endDate: endDate)
            
            let (lead, cycle, vel, thr, burn) = try await (fetchLead, fetchCycle, fetchVelocity, fetchThroughput, fetchBurndown)
            
            self.leadTime = lead
            self.cycleTime = cycle
            self.velocity = vel
            self.throughput = thr
            self.burndownStats = burn
        } catch {
            self.error = error
        }
    }
}
