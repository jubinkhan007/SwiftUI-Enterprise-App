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
}
