import Foundation
import SharedModels

public protocol AnalyticsRepositoryProtocol: Sendable {
    func getLeadTime(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Double>
    func getCycleTime(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Double>
    func getVelocity(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Double>
    func getThroughput(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Int>
    func getBurndown(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> [ProjectDailyStatsDTO]

    func getWeeklyThroughput(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> [WeeklyThroughputPointDTO]
    func getSprintVelocity(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> [SprintVelocityPointDTO]

    /// Structured JSON payload used for PDF export (client renders PDF).
    func getReportPayload(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsReportPayloadDTO

    /// Raw CSV bytes for sharing/export.
    func exportBurndownCSV(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> Data

    // Sprints (for Sprint Velocity)
    func listSprints(projectId: UUID) async throws -> [SprintDTO]
    func createSprint(projectId: UUID, payload: CreateSprintRequest) async throws -> SprintDTO
}
