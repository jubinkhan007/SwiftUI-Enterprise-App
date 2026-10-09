import Fluent
import Foundation
import Vapor

/// Database model for storing pre-computed semantic vector embeddings.
final class VectorEmbeddingModel: Model, @unchecked Sendable {
    static let schema = "vector_embeddings"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "organization_id")
    var organization: OrganizationModel

    @Field(key: "entity_type")
    var entityType: String

    @Field(key: "entity_id")
    var entityId: UUID

    @Field(key: "text_hash")
    var textHash: String

    @Field(key: "embedding_json")
    var embeddingJson: String

    @Field(key: "content_preview")
    var contentPreview: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        organizationId: UUID,
        entityType: String,
        entityId: UUID,
        textHash: String,
        embeddingJson: String,
        contentPreview: String
    ) {
        self.id = id
        self.$organization.id = organizationId
        self.entityType = entityType
        self.entityId = entityId
        self.textHash = textHash
        self.embeddingJson = embeddingJson
        self.contentPreview = contentPreview
    }
}
