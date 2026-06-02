import Fluent
import Vapor

/// Optional post-call artifact: recording URL, AI-summary URL, duration.
/// Populated by the SFU's recording webhook (sub-phase 4-C) or manually
/// uploaded; the schema is in place now to avoid future churn.
final class CallRecordModel: Model, Content, @unchecked Sendable {
    static let schema = "call_records"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "call_session_id")
    var callSession: CallSessionModel

    @OptionalField(key: "recording_url")
    var recordingUrl: String?

    @OptionalField(key: "summary_url")
    var summaryUrl: String?

    @OptionalField(key: "duration_secs")
    var durationSecs: Int?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        callSessionId: UUID,
        recordingUrl: String? = nil,
        summaryUrl: String? = nil,
        durationSecs: Int? = nil
    ) {
        self.id = id
        self.$callSession.id = callSessionId
        self.recordingUrl = recordingUrl
        self.summaryUrl = summaryUrl
        self.durationSecs = durationSecs
    }
}
