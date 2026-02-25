import Foundation

// MARK: - Space DTO

/// A Data Transfer Object representing a Space.
public struct SpaceDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let orgId: UUID
    public let name: String
    public let description: String?
    public let position: Double
    public let archivedAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?
    
    public init(id: UUID, orgId: UUID, name: String, description: String? = nil, position: Double = 0.0, archivedAt: Date? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.orgId = orgId
        self.name = name
        self.description = description
        self.position = position
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Project DTO

/// A Data Transfer Object representing a Project.
public struct ProjectDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let spaceId: UUID
    public let name: String
    public let description: String?
    public let position: Double
    public let archivedAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?
    
    public init(id: UUID, spaceId: UUID, name: String, description: String? = nil, position: Double = 0.0, archivedAt: Date? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.spaceId = spaceId
        self.name = name
        self.description = description
        self.position = position
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - TaskList DTO

/// A Data Transfer Object representing a TaskList.
public struct TaskListDTO: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let projectId: UUID
    public let name: String
    public let color: String?
    public let position: Double
    public let archivedAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?
    
    public init(id: UUID, projectId: UUID, name: String, color: String? = nil, position: Double = 0.0, archivedAt: Date? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.color = color
        self.position = position
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Hierarchy Tree DTO

/// Represents the full hierarchy tree fetched for the sidebar navigation.
public struct HierarchyTreeDTO: Codable, Sendable, Equatable {
    public struct ProjectNode: Codable, Sendable, Equatable {
        public let project: ProjectDTO
        public let lists: [TaskListDTO]
        
        public init(project: ProjectDTO, lists: [TaskListDTO] = []) {
            self.project = project
            self.lists = lists
        }
    }
    
    public struct SpaceNode: Codable, Sendable, Equatable {
        public let space: SpaceDTO
        public let projects: [ProjectNode]
        
        public init(space: SpaceDTO, projects: [ProjectNode] = []) {
            self.space = space
            self.projects = projects
        }
    }
    
    public let spaces: [SpaceNode]
    
    public init(spaces: [SpaceNode] = []) {
        self.spaces = spaces
    }
}
