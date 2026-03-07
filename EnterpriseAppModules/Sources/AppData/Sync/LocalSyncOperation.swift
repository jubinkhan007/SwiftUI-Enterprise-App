import Foundation
import SwiftData

public enum SyncEntityType: String, Codable, Sendable {
    case task
    case list
}

public enum SyncOperationMethod: String, Codable, Sendable {
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

@Model
public final class LocalSyncOperation: @unchecked Sendable {
    @Attribute(.unique) public var id: UUID
    public var entityTypeRawValue: String
    public var entityId: UUID
    public var orgId: UUID
    public var idempotencyKey: UUID
    public var operationRawValue: String
    public var payloadJSON: String?
    public var baseSnapshotJSON: String?
    public var remoteSnapshotJSON: String?
    public var timestamp: Date
    public var retryCount: Int
    public var lastError: String?
    public var nextAttemptAt: Date?
    public var needsAttention: Bool
    public var dirtyFields: [String]

    public init(
        id: UUID = UUID(),
        entityType: SyncEntityType,
        entityId: UUID,
        orgId: UUID,
        idempotencyKey: UUID = UUID(),
        operation: SyncOperationMethod,
        payloadJSON: String? = nil,
        baseSnapshotJSON: String? = nil,
        remoteSnapshotJSON: String? = nil,
        timestamp: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil,
        nextAttemptAt: Date? = nil,
        needsAttention: Bool = false,
        dirtyFields: [String] = []
    ) {
        self.id = id
        self.entityTypeRawValue = entityType.rawValue
        self.entityId = entityId
        self.orgId = orgId
        self.idempotencyKey = idempotencyKey
        self.operationRawValue = operation.rawValue
        self.payloadJSON = payloadJSON
        self.baseSnapshotJSON = baseSnapshotJSON
        self.remoteSnapshotJSON = remoteSnapshotJSON
        self.timestamp = timestamp
        self.retryCount = retryCount
        self.lastError = lastError
        self.nextAttemptAt = nextAttemptAt
        self.needsAttention = needsAttention
        self.dirtyFields = dirtyFields
    }

    public var entityType: SyncEntityType {
        get { SyncEntityType(rawValue: entityTypeRawValue) ?? .task }
        set { entityTypeRawValue = newValue.rawValue }
    }

    public var operation: SyncOperationMethod {
        get { SyncOperationMethod(rawValue: operationRawValue) ?? .put }
        set { operationRawValue = newValue.rawValue }
    }
}

