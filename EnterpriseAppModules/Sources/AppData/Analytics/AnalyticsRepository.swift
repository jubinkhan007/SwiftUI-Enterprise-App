import Foundation
import SharedModels
import Domain
import AppNetwork

public final class AnalyticsRepository: AnalyticsRepositoryProtocol {
    private let apiClient: APIClient
    private let configuration: APIConfiguration
    
    public init(apiClient: APIClient, configuration: APIConfiguration = .localVapor) {
        self.apiClient = apiClient
        self.configuration = configuration
    }
    
    public func getLeadTime(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Double> {
        let endpoint = AnalyticsEndpoint.getLeadTime(projectId: projectId, startDate: startDate, endDate: endDate, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<AnalyticsResponseDTO<Double>>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func getCycleTime(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Double> {
        let endpoint = AnalyticsEndpoint.getCycleTime(projectId: projectId, startDate: startDate, endDate: endDate, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<AnalyticsResponseDTO<Double>>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func getVelocity(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Double> {
        let endpoint = AnalyticsEndpoint.getVelocity(projectId: projectId, startDate: startDate, endDate: endDate, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<AnalyticsResponseDTO<Double>>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func getThroughput(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsResponseDTO<Int> {
        let endpoint = AnalyticsEndpoint.getThroughput(projectId: projectId, startDate: startDate, endDate: endDate, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<AnalyticsResponseDTO<Int>>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
    
    public func getBurndown(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> [ProjectDailyStatsDTO] {
        let endpoint = AnalyticsEndpoint.getBurndown(projectId: projectId, startDate: startDate, endDate: endDate, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[ProjectDailyStatsDTO]>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }

    public func getWeeklyThroughput(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> [WeeklyThroughputPointDTO] {
        let endpoint = AnalyticsEndpoint.getWeeklyThroughput(projectId: projectId, startDate: startDate, endDate: endDate, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[WeeklyThroughputPointDTO]>.self)
        return response.data ?? []
    }

    public func getSprintVelocity(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> [SprintVelocityPointDTO] {
        let endpoint = AnalyticsEndpoint.getSprintVelocity(projectId: projectId, startDate: startDate, endDate: endDate, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[SprintVelocityPointDTO]>.self)
        return response.data ?? []
    }

    public func getReportPayload(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> AnalyticsReportPayloadDTO {
        let endpoint = AnalyticsEndpoint.getReportPayload(projectId: projectId, startDate: startDate, endDate: endDate, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<AnalyticsReportPayloadDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }

    public func exportBurndownCSV(projectId: UUID, startDate: Date?, endDate: Date?) async throws -> Data {
        let endpoint = AnalyticsEndpoint.exportBurndownCSV(projectId: projectId, startDate: startDate, endDate: endDate, configuration: configuration)
        return try await apiClient.requestData(endpoint)
    }

    public func listSprints(projectId: UUID) async throws -> [SprintDTO] {
        let endpoint = SprintEndpoint.list(projectId: projectId, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[SprintDTO]>.self)
        return response.data ?? []
    }

    public func createSprint(projectId: UUID, payload: CreateSprintRequest) async throws -> SprintDTO {
        let endpoint = SprintEndpoint.create(projectId: projectId, payload: payload, configuration: configuration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<SprintDTO>.self)
        guard let data = response.data else { throw NetworkError.underlying("No data") }
        return data
    }
}
