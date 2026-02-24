import Fluent
import Vapor
import SharedModels

/// Fluent database model for an Audit Log entry.
/// Records all significant actions within an organization for compliance and debugging.
final class AuditLogModel: Model, Content, @unchecked Sendable {
    static let schema = "audit_logs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Field(key: "user_id")
    var userId: UUID

    @Field(key: "user_email")
    var userEmail: String

    /// The action performed, e.g., "member.invited", "member.role_changed", "task.deleted"
    @Field(key: "action")
    var action: String

    /// The type of resource acted upon, e.g., "member", "invite", "task", "org"
    @Field(key: "resource_type")
    var resourceType: String

    @OptionalField(key: "resource_id")
    var resourceId: UUID?

    @OptionalField(key: "details")
    var details: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        orgId: UUID,
        userId: UUID,
        userEmail: String,
        action: String,
        resourceType: String,
        resourceId: UUID? = nil,
        details: String? = nil
    ) {
        self.id = id
        self.$organization.id = orgId
        self.userId = userId
        self.userEmail = userEmail
        self.action = action
        self.resourceType = resourceType
        self.resourceId = resourceId
        self.details = details
    }

    func toDTO() -> AuditLogDTO {
        AuditLogDTO(
            id: id ?? UUID(),
            orgId: $organization.id,
            userId: userId,
            userEmail: userEmail,
            action: action,
            resourceType: resourceType,
            resourceId: resourceId,
            details: details,
            createdAt: createdAt
        )
    }
}

// MARK: - Convenience Logger

extension AuditLogModel {
    /// Create and save an audit log entry in a single call.
    static func log(
        on db: Database,
        orgId: UUID,
        userId: UUID,
        userEmail: String,
        action: String,
        resourceType: String,
        resourceId: UUID? = nil,
        details: String? = nil
    ) async throws {
        let entry = AuditLogModel(
            orgId: orgId,
            userId: userId,
            userEmail: userEmail,
            action: action,
            resourceType: resourceType,
            resourceId: resourceId,
            details: details
        )
        try await entry.save(on: db)
    }
}
