import Foundation
import SharedModels
import AppNetwork
import Domain

/// Concrete implementation of HierarchyRepositoryProtocol using APIClient.
public final class HierarchyRepository: HierarchyRepositoryProtocol {
    private let apiClient: APIClient
    private let localStore: HierarchyLocalStoreProtocol
    private let apiConfiguration: APIConfiguration
    
    public init(
        apiClient: APIClient,
        localStore: HierarchyLocalStoreProtocol,
        configuration: APIConfiguration = .current
    ) {
        self.apiClient = apiClient
        self.localStore = localStore
        self.apiConfiguration = configuration
    }
    
    public func getHierarchy() async throws -> HierarchyTreeDTO {
        guard let orgId = OrganizationContext.shared.orgId else {
            throw NetworkError.underlying("Missing organization context")
        }

        let cached = (try? await localStore.getHierarchy(orgId: orgId)) ?? HierarchyTreeDTO(spaces: [])

        do {
            let cursor = try await localStore.getCursor(orgId: orgId)
            let endpoint = HierarchyEndpoint.getHierarchy(since: cursor, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<HierarchyTreeDTO>.self)

            if let tree = response.data {
                if cursor == nil {
                    try await localStore.replaceAll(orgId: orgId, tree: tree)
                } else {
                    try await localStore.applyDelta(orgId: orgId, tree: tree)
                }
            }
            if let newCursor = response.cursor {
                try await localStore.setCursor(orgId: orgId, cursor: newCursor)
            }

            return try await localStore.getHierarchy(orgId: orgId)
        } catch let error as NetworkError {
            if error == .offline {
                return cached
            }
            throw error
        }
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
