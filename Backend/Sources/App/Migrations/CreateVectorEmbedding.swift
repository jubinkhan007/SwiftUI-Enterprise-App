import Fluent

struct CreateVectorEmbedding: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("vector_embeddings")
            .id()
            .field("organization_id", .uuid, .required, .references("organizations", "id", onDelete: .cascade))
            .field("entity_type", .string, .required)
            .field("entity_id", .uuid, .required)
            .field("text_hash", .string, .required)
            .field("embedding_json", .string, .required)
            .field("content_preview", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("vector_embeddings").delete()
    }
}
