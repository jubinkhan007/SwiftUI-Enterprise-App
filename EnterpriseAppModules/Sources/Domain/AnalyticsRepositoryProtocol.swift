import Foundation
import SharedModels

public protocol AnalyticsRepositoryProtocol: Sendable {
    func getLeadTime(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Double>
    func getCycleTime(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Double>
    func getVelocity(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Double>
    func getThroughput(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Int>
    func getBurndown(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> [ProjectDailyStatsDTO]
}
