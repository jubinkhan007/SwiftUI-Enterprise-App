import Fluent
import SharedModels
import Vapor

/// Phase 4: collaborative notes, post-meeting summary, action items,
/// `.ics` calendar export, and guest share-link landing for meetings.
struct MeetingNotesController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let meetings = routes.grouped("meetings")

        // Notes
        meetings.get(":meetingID", "notes", use: getNotes)
        meetings.put(":meetingID", "notes", use: updateNotes)

        // Summary + action items
        meetings.get(":meetingID", "summary", use: getSummary)
        meetings.post(":meetingID", "summary", use: generateSummary)
        meetings.post(":meetingID", "summary", "action-items", use: addActionItem)

        // ICS export
        meetings.get(":meetingID", "ics", use: ics)

        // Guest share-link landing (still org-scoped — guest auth lands in 4-B)
        meetings.get("by-code", ":joinCode", use: byJoinCode)
    }

    // MARK: - Notes

    @Sendable
    func getNotes(req: Request) async throws -> APIResponse<MeetingNotesDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        _ = try await MeetingController.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await MeetingController.requireParticipant(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        let row = try await Self.fetchOrCreateNotes(meetingId: meetingID, on: req.db)
        return .success(MeetingNotesDTO(
            meetingId: meetingID,
            body: row.body,
            version: row.version,
            updatedBy: row.$updatedBy.id,
            updatedAt: row.updatedAt
        ))
    }

    @Sendable
    func updateNotes(req: Request) async throws -> APIResponse<MeetingNotesDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let payload = try req.content.decode(UpdateMeetingNotesRequest.self)

        _ = try await MeetingController.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await MeetingController.requireParticipant(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        let row = try await Self.fetchOrCreateNotes(meetingId: meetingID, on: req.db)
        guard row.version == payload.expectedVersion else {
            throw Abort(.conflict, reason: "Notes have been updated by someone else. Refresh and try again.")
        }

        row.body = payload.body
        row.version += 1
        row.$updatedBy.id = ctx.userId
        try await row.save(on: req.db)

        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: ctx.orgId,
            channels: ["meeting:\(meetingID.uuidString)"],
            type: "meeting.notes_updated",
            entityId: meetingID,
            payload: [
                "meetingId": meetingID.uuidString,
                "version": "\(row.version)",
                "updatedBy": ctx.userId.uuidString
            ]
        )

        return .success(MeetingNotesDTO(
            meetingId: meetingID,
            body: row.body,
            version: row.version,
            updatedBy: row.$updatedBy.id,
            updatedAt: row.updatedAt
        ))
    }

    // MARK: - Summary

    @Sendable
    func getSummary(req: Request) async throws -> APIResponse<MeetingSummaryDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        _ = try await MeetingController.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await MeetingController.requireParticipant(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        guard let row = try await Self.latestSummary(meetingId: meetingID, on: req.db) else {
            throw Abort(.notFound, reason: "Summary has not been generated yet.")
        }
        return .success(Self.summaryDTO(row, on: req.db))
    }

    @Sendable
    func generateSummary(req: Request) async throws -> APIResponse<MeetingSummaryDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let payload = (try? req.content.decode(GenerateMeetingSummaryRequest.self)) ?? GenerateMeetingSummaryRequest()

        let meeting = try await MeetingController.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await MeetingController.requireHostOrCoHost(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        let participants = try await MeetingParticipantModel.query(on: req.db)
            .filter(\.$meeting.$id == meetingID)
            .with(\.$user)
            .all()
        let joined = participants.filter { $0.joinedAt != nil }

        let duration: TimeInterval = {
            if let started = meeting.startedAt, let ended = meeting.endedAt { return ended.timeIntervalSince(started) }
            return meeting.scheduledEndAt.timeIntervalSince(meeting.scheduledStartAt)
        }()
        let mins = Int(duration / 60.0)

        let attendees = joined
            .compactMap { $0.$user.value??.displayName }
            .sorted()
            .joined(separator: ", ")

        let summaryText = """
        \(meeting.title)
        Host: \(meeting.host.displayName)
        Duration: \(mins) min
        Attendees who joined: \(attendees.isEmpty ? "(none)" : attendees)
        """

        let existing = try await Self.latestSummary(meetingId: meetingID, on: req.db)
        let row: MeetingSummaryModel
        if let existing, !(payload.regenerate ?? false) {
            row = existing
            row.summaryText = summaryText
        } else {
            row = MeetingSummaryModel(
                meetingId: meetingID,
                summaryText: summaryText,
                actionItemsJson: existing?.actionItemsJson,
                highlightsJson: nil,
                generatedBy: ctx.userId,
                source: "template"
            )
        }
        try await row.save(on: req.db)

        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: ctx.orgId,
            channels: ["meeting:\(meetingID.uuidString)"],
            type: "meeting.summary_ready",
            entityId: meetingID,
            payload: ["meetingId": meetingID.uuidString]
        )

        return .success(Self.summaryDTO(row, on: req.db))
    }

    // MARK: - Action items

    @Sendable
    func addActionItem(req: Request) async throws -> APIResponse<MeetingSummaryDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let payload = try req.content.decode(CreateMeetingActionItemRequest.self)

        let trimmed = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw Abort(.badRequest, reason: "Action item text is required.")
        }

        _ = try await MeetingController.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await MeetingController.requireParticipant(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        // Optionally create a linked task
        var linkedTaskId: UUID? = nil
        if let listId = payload.createTaskInListId {
            let listQuery = TaskListModel.query(on: req.db)
                .filter(\.$id == listId)
                .with(\.$project) { project in project.with(\.$space) }
            guard let list = try await listQuery.first(),
                  list.project.space.$organization.id == ctx.orgId else {
                throw Abort(.notFound, reason: "Target list not found.")
            }
            let task = TaskItemModel(
                orgId: ctx.orgId,
                listId: listId,
                projectId: list.$project.id,
                title: String(trimmed.prefix(140)),
                description: trimmed,
                assigneeId: payload.assigneeUserId
            )
            task.dueDate = payload.dueAt
            try await req.db.transaction { db in
                task.issueKey = try await IssueKeyService.nextIssueKey(project: list.project, db: db)
                try await task.save(on: db)
            }
            linkedTaskId = task.id
        }

        let item = MeetingActionItemDTO(
            id: UUID(),
            text: trimmed,
            assigneeUserId: payload.assigneeUserId,
            assigneeDisplayName: nil,
            dueAt: payload.dueAt,
            linkedTaskId: linkedTaskId
        )

        // Ensure a summary row exists, then append the action item to its JSON.
        let row: MeetingSummaryModel
        if let existing = try await Self.latestSummary(meetingId: meetingID, on: req.db) {
            row = existing
        } else {
            row = MeetingSummaryModel(
                meetingId: meetingID,
                summaryText: "",
                actionItemsJson: nil,
                highlightsJson: nil,
                generatedBy: ctx.userId,
                source: "manual"
            )
        }

        var items = Self.decodeActionItems(row.actionItemsJson) ?? []
        items.append(item)
        row.actionItemsJson = Self.encodeActionItems(items)
        try await row.save(on: req.db)

        return .success(Self.summaryDTO(row, on: req.db))
    }

    // MARK: - ICS export

    @Sendable
    func ics(req: Request) async throws -> Response {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let meeting = try await MeetingController.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await MeetingController.requireParticipant(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        let baseURL = MeetingController.publicBaseURL(for: req)
        let body = Self.buildICS(meeting: meeting, baseURL: baseURL)

        let response = Response(status: .ok)
        response.headers.replaceOrAdd(name: .contentType, value: "text/calendar; charset=utf-8")
        response.headers.replaceOrAdd(name: .contentDisposition, value: "attachment; filename=\"meeting-\(meetingID.uuidString).ics\"")
        response.body = .init(string: body)
        return response
    }

    // MARK: - Share link landing

    @Sendable
    func byJoinCode(req: Request) async throws -> APIResponse<MeetingShareLinkDTO> {
        _ = try req.orgContext
        let joinCode = try req.parameters.require("joinCode", as: String.self)
        guard let token = try? req.query.get(String.self, at: "token") else {
            throw Abort(.unauthorized, reason: "Missing token.")
        }
        guard let meeting = try await MeetingModel.query(on: req.db)
            .filter(\.$joinCode == joinCode)
            .first(),
              meeting.accessToken == token else {
            throw Abort(.notFound, reason: "Share link is invalid or expired.")
        }
        let meetingID = try meeting.requireID()
        let baseURL = MeetingController.publicBaseURL(for: req)
        return .success(MeetingShareLinkDTO(
            meetingId: meetingID,
            joinCode: joinCode,
            shareUrl: "\(baseURL)/api/meetings/by-code/\(joinCode)?token=\(meeting.accessToken)",
            icsUrl: "\(baseURL)/api/meetings/\(meetingID.uuidString)/ics"
        ))
    }

    // MARK: - Helpers

    private static func fetchOrCreateNotes(meetingId: UUID, on db: Database) async throws -> MeetingNotesModel {
        if let existing = try await MeetingNotesModel.query(on: db)
            .filter(\.$meeting.$id == meetingId)
            .first() {
            return existing
        }
        let row = MeetingNotesModel(meetingId: meetingId, body: "", version: 1)
        try await row.save(on: db)
        return row
    }

    private static func latestSummary(meetingId: UUID, on db: Database) async throws -> MeetingSummaryModel? {
        try await MeetingSummaryModel.query(on: db)
            .filter(\.$meeting.$id == meetingId)
            .sort(\.$generatedAt, .descending)
            .first()
    }

    private static func decodeActionItems(_ json: String?) -> [MeetingActionItemDTO]? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([MeetingActionItemDTO].self, from: data)
    }

    private static func encodeActionItems(_ items: [MeetingActionItemDTO]) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func summaryDTO(_ row: MeetingSummaryModel, on db: Database) -> MeetingSummaryDTO {
        MeetingSummaryDTO(
            meetingId: row.$meeting.id,
            summaryText: row.summaryText,
            actionItems: decodeActionItems(row.actionItemsJson) ?? [],
            highlights: [],
            generatedBy: row.$generatedBy.id,
            source: row.source,
            generatedAt: row.generatedAt
        )
    }

    private static func buildICS(meeting: MeetingModel, baseURL: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]

        func ics(_ d: Date) -> String {
            // YYYYMMDDTHHMMSSZ (UTC)
            let s = fmt.string(from: d)
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ":", with: "")
            return s
        }
        let uid = (try? meeting.requireID().uuidString) ?? UUID().uuidString
        let now = Date()
        let title = meeting.title.replacingOccurrences(of: "\n", with: " ")
        let descPlain = (meeting.description ?? "").replacingOccurrences(of: "\n", with: "\\n")
        let url = "\(baseURL)/api/meetings/by-code/\(meeting.joinCode)?token=\(meeting.accessToken)"
        let lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//EnterpriseApp//Meetings//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "BEGIN:VEVENT",
            "UID:\(uid)@enterprise-app",
            "DTSTAMP:\(ics(now))",
            "DTSTART:\(ics(meeting.scheduledStartAt))",
            "DTEND:\(ics(meeting.scheduledEndAt))",
            "SUMMARY:\(title)",
            "DESCRIPTION:\(descPlain)",
            "URL:\(url)",
            "STATUS:\(meeting.status == "cancelled" ? "CANCELLED" : "CONFIRMED")",
            "END:VEVENT",
            "END:VCALENDAR"
        ]
        return lines.joined(separator: "\r\n") + "\r\n"
    }
}
