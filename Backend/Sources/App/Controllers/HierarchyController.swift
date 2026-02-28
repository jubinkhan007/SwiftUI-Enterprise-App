import Fluent
import Vapor
import SharedModels

/// Handles CRUD operations for the task hierarchy (Spaces -> Projects -> TaskLists).
/// All routes are protected by Auth & OrgTenantMiddleware.
struct HierarchyController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        // Routes are already scoped to /api by routes.swift
        
        // POST /api/spaces
        routes.post("spaces", use: createSpace)
        
        // POST /api/spaces/:space_id/projects
        routes.post("spaces", ":space_id", "projects", use: createProject)
        
        // POST /api/projects/:project_id/lists
        routes.post("projects", ":project_id", "lists", use: createList)
        
        // GET /api/hierarchy
        routes.get("hierarchy", use: getHierarchy)
    }

    // MARK: - Spaces

    struct CreateSpacePayload: Content {
        let name: String
        let description: String?
    }

    @Sendable
    func createSpace(req: Request) async throws -> APIResponse<SpaceDTO> {
        let payload = try req.content.decode(CreateSpacePayload.self)
        let orgId = try req.orgContext.orgId
        
        // Permission Check: Requires org-level permission (managed by middleware/RBAC in the future)
        // For now, any member can create a space.

        let space = SpaceModel(orgId: orgId, name: payload.name, description: payload.description)
        try await space.save(on: req.db)

        let dto = SpaceDTO(
            id: space.id!,
            orgId: space.$organization.id,
            name: space.name,
            description: space.description,
            position: space.position,
            archivedAt: space.archivedAt,
            createdAt: space.createdAt,
            updatedAt: space.updatedAt
        )
        return .success(dto)
    }

    // MARK: - Projects

    struct CreateProjectPayload: Content {
        let name: String
        let description: String?
    }

    @Sendable
    func createProject(req: Request) async throws -> APIResponse<ProjectDTO> {
        let payload = try req.content.decode(CreateProjectPayload.self)
        let orgId = try req.orgContext.orgId
        
        guard let spaceIdString = req.parameters.get("space_id"),
              let spaceId = UUID(uuidString: spaceIdString) else {
            throw Abort(.badRequest, reason: "Invalid space ID.")
        }

        // Validate Space belongs to the current Org
        guard let space = try await SpaceModel.query(on: req.db)
            .filter(\.$id == spaceId)
            .filter(\.$organization.$id == orgId)
            .first() else {
            throw Abort(.notFound, reason: "Space not found in this organization.")
        }

        let project = ProjectModel(spaceId: spaceId, name: payload.name, description: payload.description)
        try await req.db.transaction { db in
            try await project.save(on: db)

            // Phase 10: initialize standard workflow statuses for new projects.
            let projectId = try project.requireID()
            let existing = (try? await CustomStatusModel.query(on: db)
                .filter(\.$project.$id == projectId)
                .count()) ?? 0
            if existing == 0 {
                let standard: [(TaskStatus, String, Double, WorkflowStatusCategory, Bool, Bool)] = [
                    (.todo, "#94A3B8", 0, .backlog, true, false),
                    (.inProgress, "#3B82F6", 1000, .active, false, false),
                    (.inReview, "#F59E0B", 2000, .active, false, false),
                    (.done, "#22C55E", 3000, .completed, false, true),
                    (.cancelled, "#64748B", 4000, .cancelled, false, true)
                ]
                for (legacy, color, pos, category, isDefault, isFinal) in standard {
                    let s = CustomStatusModel(
                        projectId: projectId,
                        name: legacy.displayName,
                        color: color,
                        position: pos,
                        category: category,
                        isDefault: isDefault,
                        isFinal: isFinal,
                        isLocked: true,
                        legacyStatus: legacy.rawValue
                    )
                    try? await s.save(on: db)
                }
            }
        }

        let dto = ProjectDTO(
            id: project.id!,
            spaceId: project.$space.id,
            name: project.name,
            description: project.description,
            position: project.position,
            archivedAt: project.archivedAt,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt
        )
        return .success(dto)
    }

    // MARK: - TaskLists

    struct CreateListPayload: Content {
        let name: String
        let color: String?
    }

    @Sendable
    func createList(req: Request) async throws -> APIResponse<TaskListDTO> {
        let payload = try req.content.decode(CreateListPayload.self)
        let orgId = try req.orgContext.orgId
        
        guard let projectIdString = req.parameters.get("project_id"),
              let projectId = UUID(uuidString: projectIdString) else {
            throw Abort(.badRequest, reason: "Invalid project ID.")
        }

        // Validate Project belongs to a Space in the current Org (Data Isolation)
        guard let project = try await ProjectModel.query(on: req.db)
            .with(\.$space)
            .filter(\.$id == projectId)
            .first(),
              project.space.$organization.id == orgId else {
            throw Abort(.notFound, reason: "Project not found in this organization.")
        }

        let list = TaskListModel(projectId: projectId, name: payload.name, color: payload.color)
        try await list.save(on: req.db)

        let dto = TaskListDTO(
            id: list.id!,
            projectId: list.$project.id,
            name: list.name,
            color: list.color,
            position: list.position,
            archivedAt: list.archivedAt,
            createdAt: list.createdAt,
            updatedAt: list.updatedAt
        )
        return .success(dto)
    }

    // MARK: - Hierarchy (Sidebar Fetch)

    @Sendable
    func getHierarchy(req: Request) async throws -> APIResponse<HierarchyTreeDTO> {
        let orgId = try req.orgContext.orgId
        
        // Fetch all spaces for org (filtering out soft deleted)
        let spaces = try await SpaceModel.query(on: req.db)
            .filter(\.$organization.$id == orgId)
            .filter(\.$archivedAt == nil) // Exclude archived
            .with(\.$projects) { project in
                project.with(\.$taskLists)
            }
            .all()
        
        // Build the nested DTO tree
        let spaceNodes = spaces.map { space -> HierarchyTreeDTO.SpaceNode in
            let spaceDTO = SpaceDTO(
                id: space.id!, orgId: space.$organization.id, name: space.name,
                description: space.description, position: space.position,
                archivedAt: space.archivedAt, createdAt: space.createdAt, updatedAt: space.updatedAt
            )
            
            // Filter unarchived projects
            let activeProjects = space.projects.filter { $0.archivedAt == nil }
            let projectNodes = activeProjects.map { project -> HierarchyTreeDTO.ProjectNode in
                let projectDTO = ProjectDTO(
                    id: project.id!, spaceId: project.$space.id, name: project.name,
                    description: project.description, position: project.position,
                    archivedAt: project.archivedAt, createdAt: project.createdAt, updatedAt: project.updatedAt
                )
                
                // Filter unarchived lists
                let activeLists = project.taskLists.filter { $0.archivedAt == nil }
                let listDTOs = activeLists.map { list -> TaskListDTO in
                    TaskListDTO(
                        id: list.id!, projectId: list.$project.id, name: list.name,
                        color: list.color, position: list.position, archivedAt: list.archivedAt,
                        createdAt: list.createdAt, updatedAt: list.updatedAt
                    )
                }
                
                return HierarchyTreeDTO.ProjectNode(project: projectDTO, lists: listDTOs)
            }
            
            return HierarchyTreeDTO.SpaceNode(space: spaceDTO, projects: projectNodes)
        }
        
        return .success(HierarchyTreeDTO(spaces: spaceNodes))
    }
}
