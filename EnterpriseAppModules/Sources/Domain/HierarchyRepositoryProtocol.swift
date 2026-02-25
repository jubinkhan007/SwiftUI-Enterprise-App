import Foundation
import SharedModels

public protocol HierarchyRepositoryProtocol: Sendable {
    /// Fetches the full hierarchy tree (Spaces -> Projects -> TaskLists) for the current organization.
    func getHierarchy() async throws -> HierarchyTreeDTO
    
    /// Creates a new space within the current organization.
    func createSpace(name: String, description: String?) async throws -> SpaceDTO
    
    /// Creates a new project within a specific space.
    func createProject(spaceId: UUID, name: String, description: String?) async throws -> ProjectDTO
    
    /// Creates a new task list within a specific project.
    func createList(projectId: UUID, name: String, color: String?) async throws -> TaskListDTO
}
