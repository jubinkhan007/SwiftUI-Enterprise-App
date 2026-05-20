import Fluent
import Vapor

/// One collaborative notes blob per meeting. Versioned for optimistic-concurrency edits.
final class MeetingNotesModel: Model, Content, @unchecked Sendable {
    static let schema = "meeting_notes"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "meeting_id")
    var meeting: MeetingModel

    @Field(key: "body")
    var body: String

    @Field(key: "version")
    var version: Int

    @OptionalParent(key: "updated_by")
    var updatedBy: UserModel?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, meetingId: UUID, body: String = "", version: Int = 1, updatedBy: UUID? = nil) {
        self.id = id
        self.$meeting.id = meetingId
        self.body = body
        self.version = version
        if let updatedBy { self.$updatedBy.id = updatedBy }
    }
}
