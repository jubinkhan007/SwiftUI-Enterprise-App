import Foundation
import SwiftData

@Model
public final class LocalOrganization: @unchecked Sendable {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var slug: String
    public var orgDescription: String?
    public var ownerId: UUID

    public var serverUpdatedAt: Date?
    public var locallyModifiedAt: Date?
    public var dirtyFields: [String]
    public var isTombstone: Bool

    public init(
        id: UUID,
        name: String,
        slug: String,
        description: String? = nil,
        ownerId: UUID,
        serverUpdatedAt: Date? = nil,
        locallyModifiedAt: Date? = nil,
        dirtyFields: [String] = [],
        isTombstone: Bool = false
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.orgDescription = description
        self.ownerId = ownerId
        self.serverUpdatedAt = serverUpdatedAt
        self.locallyModifiedAt = locallyModifiedAt
        self.dirtyFields = dirtyFields
        self.isTombstone = isTombstone
    }
}

@Model
public final class LocalSpace: @unchecked Sendable {
    @Attribute(.unique) public var id: UUID
    public var orgId: UUID
    public var name: String
    public var spaceDescription: String?
    public var position: Double
    public var archivedAt: Date?
    public var createdAt: Date?
    public var updatedAt: Date?

    public var serverUpdatedAt: Date?
    public var locallyModifiedAt: Date?
    public var dirtyFields: [String]
    public var isTombstone: Bool

    public init(
        id: UUID,
        orgId: UUID,
        name: String,
        description: String? = nil,
        position: Double = 0,
        archivedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        serverUpdatedAt: Date? = nil,
        locallyModifiedAt: Date? = nil,
        dirtyFields: [String] = [],
        isTombstone: Bool = false
    ) {
        self.id = id
        self.orgId = orgId
        self.name = name
        self.spaceDescription = description
        self.position = position
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverUpdatedAt = serverUpdatedAt
        self.locallyModifiedAt = locallyModifiedAt
        self.dirtyFields = dirtyFields
        self.isTombstone = isTombstone
    }
}

@Model
public final class LocalProject: @unchecked Sendable {
    @Attribute(.unique) public var id: UUID
    public var orgId: UUID
    public var spaceId: UUID
    public var name: String
    public var projectDescription: String?
    public var position: Double
    public var archivedAt: Date?
    public var createdAt: Date?
    public var updatedAt: Date?

    public var serverUpdatedAt: Date?
    public var locallyModifiedAt: Date?
    public var dirtyFields: [String]
    public var isTombstone: Bool

    public init(
        id: UUID,
        orgId: UUID,
        spaceId: UUID,
        name: String,
        description: String? = nil,
        position: Double = 0,
        archivedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        serverUpdatedAt: Date? = nil,
        locallyModifiedAt: Date? = nil,
        dirtyFields: [String] = [],
        isTombstone: Bool = false
    ) {
        self.id = id
        self.orgId = orgId
        self.spaceId = spaceId
        self.name = name
        self.projectDescription = description
        self.position = position
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverUpdatedAt = serverUpdatedAt
        self.locallyModifiedAt = locallyModifiedAt
        self.dirtyFields = dirtyFields
        self.isTombstone = isTombstone
    }
}

@Model
public final class LocalTaskList: @unchecked Sendable {
    @Attribute(.unique) public var id: UUID
    public var orgId: UUID
    public var projectId: UUID
    public var name: String
    public var color: String?
    public var position: Double
    public var archivedAt: Date?
    public var createdAt: Date?
    public var updatedAt: Date?

    public var serverUpdatedAt: Date?
    public var locallyModifiedAt: Date?
    public var dirtyFields: [String]
    public var isTombstone: Bool

    public init(
        id: UUID,
        orgId: UUID,
        projectId: UUID,
        name: String,
        color: String? = nil,
        position: Double = 0,
        archivedAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        serverUpdatedAt: Date? = nil,
        locallyModifiedAt: Date? = nil,
        dirtyFields: [String] = [],
        isTombstone: Bool = false
    ) {
        self.id = id
        self.orgId = orgId
        self.projectId = projectId
        self.name = name
        self.color = color
        self.position = position
        self.archivedAt = archivedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverUpdatedAt = serverUpdatedAt
        self.locallyModifiedAt = locallyModifiedAt
        self.dirtyFields = dirtyFields
        self.isTombstone = isTombstone
    }
}

@Model
public final class HierarchySyncCursor: @unchecked Sendable {
    @Attribute(.unique) public var orgId: UUID
    public var cursor: String
    public var updatedAt: Date

    public init(orgId: UUID, cursor: String, updatedAt: Date = Date()) {
        self.orgId = orgId
        self.cursor = cursor
        self.updatedAt = updatedAt
    }
}

