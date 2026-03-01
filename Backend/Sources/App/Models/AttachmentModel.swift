import Fluent
import Vapor

/// Tracks a binary attachment stored privately on the server.
final class AttachmentModel: Model, Content, @unchecked Sendable {
    static let schema = "attachments"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "task_id")
    var task: TaskItemModel

    @Parent(key: "org_id")
    var organization: OrganizationModel

    @Field(key: "filename")
    var filename: String

    @Field(key: "file_type")
    var fileType: String

    @Field(key: "mime_type")
    var mimeType: String

    @Field(key: "size")
    var size: Int64

    @Field(key: "storage_key")
    var storageKey: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        taskId: UUID,
        orgId: UUID,
        filename: String,
        fileType: String,
        mimeType: String,
        size: Int64,
        storageKey: String
    ) {
        self.id = id
        self.$task.id = taskId
        self.$organization.id = orgId
        self.filename = filename
        self.fileType = fileType
        self.mimeType = mimeType
        self.size = size
        self.storageKey = storageKey
    }
}

