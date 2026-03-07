import Foundation
import SwiftData
import SharedModels

public protocol HierarchyLocalStoreProtocol: Sendable {
    func getHierarchy(orgId: UUID) async throws -> HierarchyTreeDTO
    func replaceAll(orgId: UUID, tree: HierarchyTreeDTO) async throws
    func applyDelta(orgId: UUID, tree: HierarchyTreeDTO) async throws
    func getCursor(orgId: UUID) async throws -> String?
    func setCursor(orgId: UUID, cursor: String) async throws
}

@MainActor
public final class HierarchyLocalStore: HierarchyLocalStoreProtocol, @unchecked Sendable {
    private let modelContainer: ModelContainer

    public init(container: ModelContainer) {
        self.modelContainer = container
    }

    public func getHierarchy(orgId: UUID) async throws -> HierarchyTreeDTO {
        let context = modelContainer.mainContext

        let spaces = try context.fetch(
            FetchDescriptor<LocalSpace>(
                predicate: #Predicate { $0.orgId == orgId && $0.isTombstone == false && $0.archivedAt == nil },
                sortBy: [SortDescriptor(\.position, order: .forward)]
            )
        )

        let projects = try context.fetch(
            FetchDescriptor<LocalProject>(
                predicate: #Predicate { $0.orgId == orgId && $0.isTombstone == false && $0.archivedAt == nil },
                sortBy: [SortDescriptor(\.position, order: .forward)]
            )
        )

        let lists = try context.fetch(
            FetchDescriptor<LocalTaskList>(
                predicate: #Predicate { $0.orgId == orgId && $0.isTombstone == false && $0.archivedAt == nil },
                sortBy: [SortDescriptor(\.position, order: .forward)]
            )
        )

        let listsByProject = Dictionary(grouping: lists, by: \.projectId)
        let projectsBySpace = Dictionary(grouping: projects, by: \.spaceId)

        let spaceNodes: [HierarchyTreeDTO.SpaceNode] = spaces.map { space in
            let spaceDTO = SpaceDTO(
                id: space.id,
                orgId: space.orgId,
                name: space.name,
                description: space.spaceDescription,
                position: space.position,
                archivedAt: space.archivedAt,
                createdAt: space.createdAt,
                updatedAt: space.updatedAt
            )

            let projectNodes: [HierarchyTreeDTO.ProjectNode] = (projectsBySpace[space.id] ?? []).map { project in
                let projectDTO = ProjectDTO(
                    id: project.id,
                    spaceId: project.spaceId,
                    name: project.name,
                    description: project.projectDescription,
                    position: project.position,
                    archivedAt: project.archivedAt,
                    createdAt: project.createdAt,
                    updatedAt: project.updatedAt
                )
                let listDTOs: [TaskListDTO] = (listsByProject[project.id] ?? []).map { list in
                    TaskListDTO(
                        id: list.id,
                        projectId: list.projectId,
                        name: list.name,
                        color: list.color,
                        position: list.position,
                        archivedAt: list.archivedAt,
                        createdAt: list.createdAt,
                        updatedAt: list.updatedAt
                    )
                }
                return HierarchyTreeDTO.ProjectNode(project: projectDTO, lists: listDTOs)
            }

            return HierarchyTreeDTO.SpaceNode(space: spaceDTO, projects: projectNodes)
        }

        return HierarchyTreeDTO(spaces: spaceNodes)
    }

    public func replaceAll(orgId: UUID, tree: HierarchyTreeDTO) async throws {
        let context = modelContainer.mainContext

        let spaces = try context.fetch(FetchDescriptor<LocalSpace>(predicate: #Predicate { $0.orgId == orgId }))
        for s in spaces { context.delete(s) }
        let projects = try context.fetch(FetchDescriptor<LocalProject>(predicate: #Predicate { $0.orgId == orgId }))
        for p in projects { context.delete(p) }
        let lists = try context.fetch(FetchDescriptor<LocalTaskList>(predicate: #Predicate { $0.orgId == orgId }))
        for l in lists { context.delete(l) }

        for spaceNode in tree.spaces {
            let spaceDTO = spaceNode.space
            context.insert(LocalSpace(
                id: spaceDTO.id,
                orgId: spaceDTO.orgId,
                name: spaceDTO.name,
                description: spaceDTO.description,
                position: spaceDTO.position,
                archivedAt: spaceDTO.archivedAt,
                createdAt: spaceDTO.createdAt,
                updatedAt: spaceDTO.updatedAt,
                serverUpdatedAt: spaceDTO.updatedAt
            ))

            for projectNode in spaceNode.projects {
                let projectDTO = projectNode.project
                context.insert(LocalProject(
                    id: projectDTO.id,
                    orgId: orgId,
                    spaceId: projectDTO.spaceId,
                    name: projectDTO.name,
                    description: projectDTO.description,
                    position: projectDTO.position,
                    archivedAt: projectDTO.archivedAt,
                    createdAt: projectDTO.createdAt,
                    updatedAt: projectDTO.updatedAt,
                    serverUpdatedAt: projectDTO.updatedAt
                ))

                for listDTO in projectNode.lists {
                    context.insert(LocalTaskList(
                        id: listDTO.id,
                        orgId: orgId,
                        projectId: listDTO.projectId,
                        name: listDTO.name,
                        color: listDTO.color,
                        position: listDTO.position,
                        archivedAt: listDTO.archivedAt,
                        createdAt: listDTO.createdAt,
                        updatedAt: listDTO.updatedAt,
                        serverUpdatedAt: listDTO.updatedAt
                    ))
                }
            }
        }

        try context.save()
    }

    public func applyDelta(orgId: UUID, tree: HierarchyTreeDTO) async throws {
        let context = modelContainer.mainContext

        for spaceNode in tree.spaces {
            try upsert(space: spaceNode.space, context: context)
            for projectNode in spaceNode.projects {
                try upsert(project: projectNode.project, orgId: orgId, context: context)
                for listDTO in projectNode.lists {
                    try upsert(list: listDTO, orgId: orgId, context: context)
                }
            }
        }

        try context.save()
    }

    public func getCursor(orgId: UUID) async throws -> String? {
        let context = modelContainer.mainContext
        var descriptor = FetchDescriptor<HierarchySyncCursor>(predicate: #Predicate { $0.orgId == orgId })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.cursor
    }

    public func setCursor(orgId: UUID, cursor: String) async throws {
        let context = modelContainer.mainContext
        var descriptor = FetchDescriptor<HierarchySyncCursor>(predicate: #Predicate { $0.orgId == orgId })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.cursor = cursor
            existing.updatedAt = Date()
        } else {
            context.insert(HierarchySyncCursor(orgId: orgId, cursor: cursor))
        }
        try context.save()
    }

    // MARK: - Upserts

    private func upsert(space: SpaceDTO, context: ModelContext) throws {
        var descriptor = FetchDescriptor<LocalSpace>(predicate: #Predicate { $0.id == space.id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.orgId = space.orgId
            existing.name = space.name
            existing.spaceDescription = space.description
            existing.position = space.position
            existing.archivedAt = space.archivedAt
            existing.createdAt = space.createdAt
            existing.updatedAt = space.updatedAt
            existing.serverUpdatedAt = space.updatedAt
            existing.isTombstone = space.archivedAt != nil
        } else {
            context.insert(LocalSpace(
                id: space.id,
                orgId: space.orgId,
                name: space.name,
                description: space.description,
                position: space.position,
                archivedAt: space.archivedAt,
                createdAt: space.createdAt,
                updatedAt: space.updatedAt,
                serverUpdatedAt: space.updatedAt,
                isTombstone: space.archivedAt != nil
            ))
        }
    }

    private func upsert(project: ProjectDTO, orgId: UUID, context: ModelContext) throws {
        var descriptor = FetchDescriptor<LocalProject>(predicate: #Predicate { $0.id == project.id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.orgId = orgId
            existing.spaceId = project.spaceId
            existing.name = project.name
            existing.projectDescription = project.description
            existing.position = project.position
            existing.archivedAt = project.archivedAt
            existing.createdAt = project.createdAt
            existing.updatedAt = project.updatedAt
            existing.serverUpdatedAt = project.updatedAt
            existing.isTombstone = project.archivedAt != nil
        } else {
            context.insert(LocalProject(
                id: project.id,
                orgId: orgId,
                spaceId: project.spaceId,
                name: project.name,
                description: project.description,
                position: project.position,
                archivedAt: project.archivedAt,
                createdAt: project.createdAt,
                updatedAt: project.updatedAt,
                serverUpdatedAt: project.updatedAt,
                isTombstone: project.archivedAt != nil
            ))
        }
    }

    private func upsert(list: TaskListDTO, orgId: UUID, context: ModelContext) throws {
        var descriptor = FetchDescriptor<LocalTaskList>(predicate: #Predicate { $0.id == list.id })
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.orgId = orgId
            existing.projectId = list.projectId
            existing.name = list.name
            existing.color = list.color
            existing.position = list.position
            existing.archivedAt = list.archivedAt
            existing.createdAt = list.createdAt
            existing.updatedAt = list.updatedAt
            existing.serverUpdatedAt = list.updatedAt
            existing.isTombstone = list.archivedAt != nil
        } else {
            context.insert(LocalTaskList(
                id: list.id,
                orgId: orgId,
                projectId: list.projectId,
                name: list.name,
                color: list.color,
                position: list.position,
                archivedAt: list.archivedAt,
                createdAt: list.createdAt,
                updatedAt: list.updatedAt,
                serverUpdatedAt: list.updatedAt,
                isTombstone: list.archivedAt != nil
            ))
        }
    }
}
