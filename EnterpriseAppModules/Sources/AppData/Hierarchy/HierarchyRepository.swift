import Foundation
import SharedModels
import AppNetwork
import Domain

/// Concrete implementation of HierarchyRepositoryProtocol using APIClient.
public final class HierarchyRepository: HierarchyRepositoryProtocol {
    private let apiClient: APIClient
    private let apiConfiguration: APIConfiguration
    
    public init(apiClient: APIClient, configuration: APIConfiguration = .localVapor) {
        self.apiClient = apiClient
        self.apiConfiguration = configuration
    }
    
    public func getHierarchy() async throws -> HierarchyTreeDTO {
        let endpoint = HierarchyEndpoint.getHierarchy(configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<HierarchyTreeDTO>.self)
        
        guard let data = response.data else {
            throw NetworkError.underlying("No hierarchy data returned from server")
        }
        return data
    }
    
    public func createSpace(name: String, description: String?) async throws -> SpaceDTO {
        let endpoint = HierarchyEndpoint.createSpace(name: name, description: description, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<SpaceDTO>.self)
        
        guard let data = response.data else {
            throw NetworkError.underlying("Failed to create space")
        }
        return data
    }
    
    public func createProject(spaceId: UUID, name: String, description: String?) async throws -> ProjectDTO {
        let endpoint = HierarchyEndpoint.createProject(spaceId: spaceId, name: name, description: description, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<ProjectDTO>.self)
        
        guard let data = response.data else {
            throw NetworkError.underlying("Failed to create project")
        }
        return data
    }
    
    public func createList(projectId: UUID, name: String, color: String?) async throws -> TaskListDTO {
        let endpoint = HierarchyEndpoint.createList(projectId: projectId, name: name, color: color, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<TaskListDTO>.self)
        
        guard let data = response.data else {
            throw NetworkError.underlying("Failed to create list")
        }
        return data
    }
}
