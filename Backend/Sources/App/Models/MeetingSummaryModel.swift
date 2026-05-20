import Fluent
import Vapor

/// Post-meeting summary. `actionItemsJson` / `highlightsJson` hold JSON-encoded arrays.
/// `source`: "template" (deterministic stub now), "ai" (Phase 4 follow-up), or "manual".
final class MeetingSummaryModel: Model, Content, @unchecked Sendable {
    static let schema = "meeting_summaries"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "meeting_id")
    var meeting: MeetingModel

    @Field(key: "summary_text")
    var summaryText: String

    @OptionalField(key: "action_items_json")
    var actionItemsJson: String?

    @OptionalField(key: "highlights_json")
    var highlightsJson: String?

    @OptionalParent(key: "generated_by")
    var generatedBy: UserModel?

    @Field(key: "source")
    var source: String

    @Timestamp(key: "generated_at", on: .create)
    var generatedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        meetingId: UUID,
        summaryText: String,
        actionItemsJson: String? = nil,
        highlightsJson: String? = nil,
        generatedBy: UUID? = nil,
        source: String = "template"
    ) {
        self.id = id
        self.$meeting.id = meetingId
        self.summaryText = summaryText
        self.actionItemsJson = actionItemsJson
        self.highlightsJson = highlightsJson
        if let generatedBy { self.$generatedBy.id = generatedBy }
        self.source = source
    }
}
