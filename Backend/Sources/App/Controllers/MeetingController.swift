import Fluent
import SharedModels
import Vapor

/// Phase 4 (Meetings slice). Schedules and runs meetings, manages participants
/// and the waiting-room flow. The per-meeting chat sidebar is backed by an
/// auto-created `type='meeting'` conversation referenced by
/// `MeetingModel.$meetingChatConversation`.
struct MeetingController: RouteCollection {
    static let onlineHeartbeatWindow: TimeInterval = 90

    func boot(routes: any RoutesBuilder) throws {
        let meetings = routes.grouped("meetings")
        meetings.post(use: create)
        meetings.get(use: list)
        meetings.get(":meetingID", use: show)
        meetings.put(":meetingID", use: update)
        meetings.delete(":meetingID", use: cancel)

        // Lifecycle
        meetings.post(":meetingID", "start", use: start)
        meetings.post(":meetingID", "end", use: end)
        meetings.post(":meetingID", "join", use: join)
        meetings.post(":meetingID", "leave", use: leave)
        meetings.post(":meetingID", "heartbeat", use: heartbeat)

        // Participants
        meetings.post(":meetingID", "participants", use: addParticipants)
        meetings.delete(":meetingID", "participants", ":participantID", use: removeParticipant)
        meetings.put(":meetingID", "participants", ":participantID", "role", use: changeRole)
        meetings.put(":meetingID", "participants", "me", "rsvp", use: rsvp)
        meetings.post(":meetingID", "participants", ":participantID", "admit", use: admit)
        meetings.post(":meetingID", "participants", ":participantID", "deny", use: deny)
    }

    // MARK: - CRUD

    @Sendable
    func create(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(CreateMeetingRequest.self)

        let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 200 else {
            throw Abort(.badRequest, reason: "Title is required and must be 200 characters or fewer.")
        }
        guard payload.scheduledEndAt > payload.scheduledStartAt else {
            throw Abort(.badRequest, reason: "End time must be after start time.")
        }

        // If the meeting is being created from inside an existing channel, validate it.
        if let conversationId = payload.conversationId {
            guard try await ConversationModel.query(on: req.db)
                .filter(\.$id == conversationId)
                .filter(\.$organization.$id == ctx.orgId)
                .count() > 0 else {
                throw Abort(.notFound, reason: "Linked conversation not found.")
            }
        }

        let recurrenceJson = try Self.encodeRecurrence(payload.recurrence)

        // 1. Create per-meeting chat conversation
        let chatConversation = ConversationModel(
            type: "meeting",
            name: title,
            description: payload.description,
            topic: nil,
            isArchived: false,
            isPrivate: true,
            createdBy: ctx.userId,
            ownerId: ctx.userId,
            orgId: ctx.orgId
        )
        try await chatConversation.save(on: req.db)
        let chatConversationID = try chatConversation.requireID()

        // 2. Create the meeting
        let meeting = MeetingModel(
            orgId: ctx.orgId,
            conversationId: payload.conversationId,
            meetingChatConversationId: chatConversationID,
            title: title,
            description: payload.description,
            agenda: payload.agenda,
            scheduledStartAt: payload.scheduledStartAt,
            scheduledEndAt: payload.scheduledEndAt,
            timezone: payload.timezone,
            status: "scheduled",
            hostId: ctx.userId,
            requiresWaitingRoom: payload.requiresWaitingRoom ?? true,
            allowGuests: payload.allowGuests ?? false,
            joinCode: Self.generateJoinCode(),
            accessToken: Self.generateAccessToken(),
            provider: "internal",
            recurrenceRule: recurrenceJson,
            createdBy: ctx.userId
        )
        try await meeting.save(on: req.db)
        let meetingID = try meeting.requireID()

        // 3. Host participant (auto-accepted)
        let hostParticipant = MeetingParticipantModel(
            meetingId: meetingID,
            userId: ctx.userId,
            role: "host",
            inviteStatus: "accepted",
            joinState: "not_joined"
        )
        try await hostParticipant.save(on: req.db)

        // 4. Add host as admin to chat conversation
        try await ConversationMemberModel(
            conversationId: chatConversationID,
            userId: ctx.userId,
            role: "admin"
        ).save(on: req.db)

        // 5. Invitees
        let invitedUserIds = Set(payload.memberIds).filter { $0 != ctx.userId }
        for uid in invitedUserIds {
            // Verify org membership
            let isMember = try await OrganizationMemberModel.query(on: req.db)
                .filter(\.$organization.$id == ctx.orgId)
                .filter(\.$user.$id == uid)
                .count() > 0
            guard isMember else { continue }

            let participant = MeetingParticipantModel(
                meetingId: meetingID,
                userId: uid,
                role: "attendee",
                inviteStatus: "pending",
                joinState: "not_joined"
            )
            try await participant.save(on: req.db)

            try await ConversationMemberModel(
                conversationId: chatConversationID,
                userId: uid,
                role: "member"
            ).save(on: req.db)

            // Notification
            try await Self.emitNotification(
                req: req,
                userId: uid,
                actorId: ctx.userId,
                meetingId: meetingID,
                type: "meeting.invited",
                title: title
            )
        }

        // 6. Guest invitees (no org account)
        if let guestEmails = payload.guestEmails, meeting.allowGuests {
            for email in guestEmails {
                let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !normalized.isEmpty, normalized.contains("@") else { continue }
                let participant = MeetingParticipantModel(
                    meetingId: meetingID,
                    guestEmail: normalized,
                    role: "attendee",
                    inviteStatus: "pending",
                    joinState: "not_joined",
                    inviteToken: Self.generateAccessToken()
                )
                try await participant.save(on: req.db)
            }
        }

        // 7. Audit log
        try? await Self.audit(req: req, action: "meeting.created", meetingId: meetingID, details: title)

        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.created")

        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    @Sendable
    func list(req: Request) async throws -> APIResponse<[MeetingListItemDTO]> {
        let ctx = try req.orgContext

        let scope = (try? req.query.get(String.self, at: "scope")) ?? "upcoming"
        let hostIdFilter: UUID? = try? req.query.get(UUID.self, at: "hostId")
        let conversationIdFilter: UUID? = try? req.query.get(UUID.self, at: "conversationId")
        let statusFilter: String? = try? req.query.get(String.self, at: "status")
        let qFilter: String? = try? req.query.get(String.self, at: "q")
        let fromDate: Date? = try? req.query.get(Date.self, at: "from")
        let toDate: Date? = try? req.query.get(Date.self, at: "to")

        // Only meetings I am a participant of, OR I host.
        let myParticipantRows = try await MeetingParticipantModel.query(on: req.db)
            .filter(\.$user.$id == ctx.userId)
            .all()
        let myMeetingIds = Set(myParticipantRows.map { $0.$meeting.id })
        guard !myMeetingIds.isEmpty else { return .success([]) }

        var query = MeetingModel.query(on: req.db)
            .filter(\.$organization.$id == ctx.orgId)
            .filter(\.$id ~~ Array(myMeetingIds))
            .with(\.$host)

        let now = Date()
        switch scope.lowercased() {
        case "past":
            query = query.filter(\.$scheduledStartAt < now)
                .sort(\.$scheduledStartAt, .descending)
        case "today":
            let cal = Calendar(identifier: .gregorian)
            let start = cal.startOfDay(for: now)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86_400)
            query = query.filter(\.$scheduledStartAt >= start).filter(\.$scheduledStartAt < end)
                .sort(\.$scheduledStartAt, .ascending)
        case "all":
            query = query.sort(\.$scheduledStartAt, .descending)
        default: // "upcoming"
            query = query.filter(\.$scheduledEndAt >= now)
                .sort(\.$scheduledStartAt, .ascending)
        }

        if let hostIdFilter { query = query.filter(\.$host.$id == hostIdFilter) }
        if let conversationIdFilter { query = query.filter(\.$conversation.$id == conversationIdFilter) }
        if let statusFilter { query = query.filter(\.$status == statusFilter) }
        if let fromDate { query = query.filter(\.$scheduledStartAt >= fromDate) }
        if let toDate { query = query.filter(\.$scheduledStartAt <= toDate) }

        let meetings = try await query.limit(200).all()

        let participantsByMeeting = try await Self.participantsByMeeting(
            meetingIds: meetings.compactMap { $0.id },
            on: req.db
        )

        var items: [MeetingListItemDTO] = []
        items.reserveCapacity(meetings.count)
        for meeting in meetings {
            guard let id = meeting.id else { continue }
            let parts = participantsByMeeting[id] ?? []
            let mine = parts.first(where: { $0.$user.id == ctx.userId })
            let waitingCount = parts.filter { $0.joinState == "waiting" }.count

            if let q = qFilter?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
                if !meeting.title.localizedCaseInsensitiveContains(q) { continue }
            }

            items.append(MeetingListItemDTO(
                id: id,
                title: meeting.title,
                scheduledStartAt: meeting.scheduledStartAt,
                scheduledEndAt: meeting.scheduledEndAt,
                timezone: meeting.timezone,
                status: MeetingStatus(rawValue: meeting.status) ?? .scheduled,
                hostId: meeting.$host.id,
                hostDisplayName: meeting.host.displayName,
                participantCount: parts.count,
                myInviteStatus: mine.flatMap { MeetingInviteStatus(rawValue: $0.inviteStatus) },
                myRole: mine.flatMap { MeetingRole(rawValue: $0.role) },
                waitingCount: waitingCount
            ))
        }
        return .success(items)
    }

    @Sendable
    func show(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await Self.requireParticipant(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)
        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    @Sendable
    func update(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let payload = try req.content.decode(UpdateMeetingRequest.self)

        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await Self.requireHostOrCoHost(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        guard meeting.status == "scheduled" else {
            throw Abort(.badRequest, reason: "Only scheduled meetings can be edited.")
        }

        if let title = payload.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            meeting.title = title
        }
        if let description = payload.description { meeting.description = description }
        if let agenda = payload.agenda { meeting.agenda = agenda }
        if let start = payload.scheduledStartAt { meeting.scheduledStartAt = start }
        if let end = payload.scheduledEndAt { meeting.scheduledEndAt = end }
        if let tz = payload.timezone { meeting.timezone = tz }
        if let waiting = payload.requiresWaitingRoom { meeting.requiresWaitingRoom = waiting }
        if let allowGuests = payload.allowGuests { meeting.allowGuests = allowGuests }

        guard meeting.scheduledEndAt > meeting.scheduledStartAt else {
            throw Abort(.badRequest, reason: "End time must be after start time.")
        }

        try await meeting.save(on: req.db)
        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.updated")

        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    @Sendable
    func cancel(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let payload = (try? req.content.decode(CancelMeetingRequest.self)) ?? CancelMeetingRequest()

        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await Self.requireHost(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        guard meeting.status == "scheduled" || meeting.status == "in_progress" else {
            // already ended/cancelled — idempotent no-op
            let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
            return .success(dto)
        }

        meeting.status = "cancelled"
        meeting.cancelledAt = Date()
        meeting.cancelReason = payload.reason
        try await meeting.save(on: req.db)

        // Archive the chat conversation
        if let chatId = meeting.$meetingChatConversation.id,
           let chat = try await ConversationModel.find(chatId, on: req.db) {
            chat.isArchived = true
            try await chat.save(on: req.db)
        }

        // Notify accepted/tentative participants
        let parts = try await MeetingParticipantModel.query(on: req.db)
            .filter(\.$meeting.$id == meetingID)
            .filter(\.$inviteStatus ~~ ["accepted", "tentative"])
            .all()
        for p in parts {
            if let uid = p.$user.id, uid != ctx.userId {
                try? await Self.emitNotification(
                    req: req,
                    userId: uid,
                    actorId: ctx.userId,
                    meetingId: meetingID,
                    type: "meeting.cancelled",
                    title: meeting.title
                )
            }
        }

        try? await Self.audit(req: req, action: "meeting.cancelled", meetingId: meetingID, details: payload.reason)

        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.cancelled")

        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    // MARK: - Lifecycle

    @Sendable
    func start(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)

        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await Self.requireHostOrCoHost(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        guard meeting.status != "cancelled" else {
            throw Abort(.badRequest, reason: "Cancelled meetings cannot be started.")
        }

        if meeting.status == "scheduled" {
            meeting.status = "in_progress"
            meeting.startedAt = Date()
            try await meeting.save(on: req.db)

            try? await Self.audit(req: req, action: "meeting.started", meetingId: meetingID, details: nil)

            broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.started")
        }

        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    @Sendable
    func end(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)

        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await Self.requireHostOrCoHost(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        guard meeting.status == "in_progress" || meeting.status == "scheduled" else {
            // already ended/cancelled — idempotent
            let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
            return .success(dto)
        }

        meeting.status = "ended"
        meeting.endedAt = Date()
        try await meeting.save(on: req.db)

        // Drop any still-in-meeting participants to 'left'.
        let stillInMeeting = try await MeetingParticipantModel.query(on: req.db)
            .filter(\.$meeting.$id == meetingID)
            .filter(\.$joinState == "in_meeting")
            .all()
        for row in stillInMeeting {
            row.joinState = "left"
            row.leftAt = Date()
            row.lastStateChangedAt = Date()
            try await row.save(on: req.db)
        }

        // Emit "missed" notifications to anyone who accepted but never joined.
        let parts = try await MeetingParticipantModel.query(on: req.db)
            .filter(\.$meeting.$id == meetingID)
            .filter(\.$inviteStatus == "accepted")
            .filter(\.$joinState == "not_joined")
            .all()
        for p in parts {
            if let uid = p.$user.id, uid != meeting.$host.id {
                try? await Self.emitNotification(
                    req: req,
                    userId: uid,
                    actorId: meeting.$host.id,
                    meetingId: meetingID,
                    type: "meeting.missed",
                    title: meeting.title
                )
            }
        }

        // Archive the chat conversation
        if let chatId = meeting.$meetingChatConversation.id,
           let chat = try await ConversationModel.find(chatId, on: req.db) {
            chat.isArchived = true
            try await chat.save(on: req.db)
        }

        try? await Self.audit(req: req, action: "meeting.ended", meetingId: meetingID, details: nil)

        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.ended")

        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    @Sendable
    func join(req: Request) async throws -> APIResponse<MeetingJoinTicketDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)

        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        let participant = try await Self.requireParticipantRow(meetingId: meetingID, userId: ctx.userId, on: req.db)

        guard meeting.status != "cancelled" else {
            throw Abort(.badRequest, reason: "Meeting was cancelled.")
        }
        guard meeting.status != "ended" else {
            throw Abort(.badRequest, reason: "Meeting has ended.")
        }

        let isHostRole = participant.role == "host" || participant.role == "co_host"
        let newState: String
        if meeting.requiresWaitingRoom && !isHostRole {
            newState = "waiting"
            participant.waitingSinceAt = Date()
        } else {
            newState = "in_meeting"
            participant.joinedAt = Date()
            // Implicit start: if host/co_host joins a scheduled meeting, flip it to in_progress.
            if isHostRole && meeting.status == "scheduled" {
                meeting.status = "in_progress"
                meeting.startedAt = Date()
                try await meeting.save(on: req.db)
                broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.started")
            }
        }
        participant.joinState = newState
        participant.lastStateChangedAt = Date()
        try await participant.save(on: req.db)

        // Auto-accept RSVP on join.
        if participant.inviteStatus == "pending" {
            participant.inviteStatus = "accepted"
            try await participant.save(on: req.db)
        }

        let eventType = newState == "waiting" ? "meeting.participant_waiting" : "meeting.participant_joined"
        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: eventType,
                              extra: ["participantId": (try? participant.requireID().uuidString) ?? "",
                                      "userId": ctx.userId.uuidString])

        return .success(MeetingJoinTicketDTO(
            meetingId: meetingID,
            joinState: MeetingJoinState(rawValue: newState) ?? .notJoined,
            role: MeetingRole(rawValue: participant.role) ?? .attendee,
            chatConversationId: meeting.$meetingChatConversation.id,
            provider: MeetingProvider(rawValue: meeting.provider) ?? .internal,
            providerToken: nil,
            providerSessionId: meeting.providerSessionId
        ))
    }

    @Sendable
    func leave(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        let participant = try await Self.requireParticipantRow(meetingId: meetingID, userId: ctx.userId, on: req.db)

        participant.joinState = "left"
        participant.leftAt = Date()
        participant.lastStateChangedAt = Date()
        try await participant.save(on: req.db)

        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.participant_left",
                              extra: ["participantId": (try? participant.requireID().uuidString) ?? "",
                                      "userId": ctx.userId.uuidString])
        return .success(EmptyResponse())
    }

    @Sendable
    func heartbeat(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let participant = try await Self.requireParticipantRow(meetingId: meetingID, userId: ctx.userId, on: req.db)
        guard participant.joinState == "in_meeting" || participant.joinState == "waiting" else {
            return .success(EmptyResponse())
        }
        participant.lastStateChangedAt = Date()
        try await participant.save(on: req.db)
        return .success(EmptyResponse())
    }

    // MARK: - Participants

    @Sendable
    func addParticipants(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let payload = try req.content.decode(AddMeetingParticipantsRequest.self)

        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await Self.requireHostOrCoHost(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        for uid in Set(payload.memberIds) where uid != ctx.userId {
            let isOrgMember = try await OrganizationMemberModel.query(on: req.db)
                .filter(\.$organization.$id == ctx.orgId)
                .filter(\.$user.$id == uid)
                .count() > 0
            guard isOrgMember else { continue }

            let exists = try await MeetingParticipantModel.query(on: req.db)
                .filter(\.$meeting.$id == meetingID)
                .filter(\.$user.$id == uid)
                .count() > 0
            guard !exists else { continue }

            let p = MeetingParticipantModel(
                meetingId: meetingID,
                userId: uid,
                role: "attendee",
                inviteStatus: "pending",
                joinState: "not_joined"
            )
            try await p.save(on: req.db)

            if let chatId = meeting.$meetingChatConversation.id {
                let chatMemberExists = try await ConversationMemberModel.query(on: req.db)
                    .filter(\.$conversation.$id == chatId)
                    .filter(\.$user.$id == uid)
                    .count() > 0
                if !chatMemberExists {
                    try await ConversationMemberModel(
                        conversationId: chatId,
                        userId: uid,
                        role: "member"
                    ).save(on: req.db)
                }
            }

            try? await Self.emitNotification(
                req: req,
                userId: uid,
                actorId: ctx.userId,
                meetingId: meetingID,
                type: "meeting.invited",
                title: meeting.title
            )
        }

        if let guests = payload.guestEmails, meeting.allowGuests {
            for email in guests {
                let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !normalized.isEmpty, normalized.contains("@") else { continue }
                let exists = try await MeetingParticipantModel.query(on: req.db)
                    .filter(\.$meeting.$id == meetingID)
                    .filter(\.$guestEmail == normalized)
                    .count() > 0
                guard !exists else { continue }
                try await MeetingParticipantModel(
                    meetingId: meetingID,
                    guestEmail: normalized,
                    role: "attendee",
                    inviteStatus: "pending",
                    joinState: "not_joined",
                    inviteToken: Self.generateAccessToken()
                ).save(on: req.db)
            }
        }

        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.participant_invited")
        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    @Sendable
    func removeParticipant(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let participantID = try req.parameters.require("participantID", as: UUID.self)

        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await Self.requireHostOrCoHost(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        guard let target = try await MeetingParticipantModel.query(on: req.db)
            .filter(\.$id == participantID)
            .filter(\.$meeting.$id == meetingID)
            .first() else {
            throw Abort(.notFound, reason: "Participant not found.")
        }
        guard target.role != "host" else {
            throw Abort(.badRequest, reason: "Cannot remove the host.")
        }

        if target.joinState == "in_meeting" || target.joinState == "waiting" {
            target.joinState = "removed"
            target.leftAt = Date()
            target.lastStateChangedAt = Date()
            try await target.save(on: req.db)
        } else {
            try await target.delete(on: req.db)
        }

        // Remove from chat conversation
        if let chatId = meeting.$meetingChatConversation.id, let uid = target.$user.id {
            try? await ConversationMemberModel.query(on: req.db)
                .filter(\.$conversation.$id == chatId)
                .filter(\.$user.$id == uid)
                .delete()
        }

        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.participant_left",
                              extra: ["participantId": participantID.uuidString])

        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    @Sendable
    func changeRole(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let participantID = try req.parameters.require("participantID", as: UUID.self)
        let payload = try req.content.decode(ChangeMeetingRoleRequest.self)

        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await Self.requireHostOrCoHost(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        guard let target = try await MeetingParticipantModel.query(on: req.db)
            .filter(\.$id == participantID)
            .filter(\.$meeting.$id == meetingID)
            .first() else {
            throw Abort(.notFound, reason: "Participant not found.")
        }

        // Only host can re-assign host. Promotes the target and demotes the previous host to co_host.
        if payload.role == .host {
            try await Self.requireHost(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)
            if let prevHost = try await MeetingParticipantModel.query(on: req.db)
                .filter(\.$meeting.$id == meetingID)
                .filter(\.$role == "host")
                .first() {
                prevHost.role = "co_host"
                try await prevHost.save(on: req.db)
            }
            meeting.$host.id = target.$user.id ?? meeting.$host.id
            try await meeting.save(on: req.db)
        } else if target.role == "host" {
            throw Abort(.badRequest, reason: "Cannot demote the current host directly; promote a new host first.")
        }

        target.role = payload.role.rawValue
        try await target.save(on: req.db)

        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.participant_role_changed",
                              extra: ["participantId": participantID.uuidString, "role": payload.role.rawValue])

        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    @Sendable
    func rsvp(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let payload = try req.content.decode(MeetingRSVPRequest.self)

        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        let participant = try await Self.requireParticipantRow(meetingId: meetingID, userId: ctx.userId, on: req.db)

        participant.inviteStatus = payload.status.rawValue
        try await participant.save(on: req.db)

        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.participant_rsvp",
                              extra: ["userId": ctx.userId.uuidString, "status": payload.status.rawValue])

        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    @Sendable
    func admit(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let participantID = try req.parameters.require("participantID", as: UUID.self)

        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await Self.requireHostOrCoHost(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        guard let target = try await MeetingParticipantModel.query(on: req.db)
            .filter(\.$id == participantID)
            .filter(\.$meeting.$id == meetingID)
            .first() else {
            throw Abort(.notFound, reason: "Participant not found.")
        }
        if target.joinState == "waiting" {
            target.joinState = "in_meeting"
            target.joinedAt = Date()
            target.lastStateChangedAt = Date()
            try await target.save(on: req.db)
        }
        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.participant_admitted",
                              extra: ["participantId": participantID.uuidString,
                                      "userId": target.$user.id?.uuidString ?? ""])

        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    @Sendable
    func deny(req: Request) async throws -> APIResponse<MeetingDTO> {
        let ctx = try req.orgContext
        let meetingID = try req.parameters.require("meetingID", as: UUID.self)
        let participantID = try req.parameters.require("participantID", as: UUID.self)

        let meeting = try await Self.requireMeeting(meetingID: meetingID, orgId: ctx.orgId, on: req.db)
        try await Self.requireHostOrCoHost(meetingId: meetingID, userId: ctx.userId, allowOrgAdmin: ctx.role, on: req.db)

        guard let target = try await MeetingParticipantModel.query(on: req.db)
            .filter(\.$id == participantID)
            .filter(\.$meeting.$id == meetingID)
            .first() else {
            throw Abort(.notFound, reason: "Participant not found.")
        }
        target.joinState = "denied"
        target.lastStateChangedAt = Date()
        try await target.save(on: req.db)

        broadcastMeetingEvent(req: req, orgId: ctx.orgId, meeting: meeting, type: "meeting.participant_denied",
                              extra: ["participantId": participantID.uuidString,
                                      "userId": target.$user.id?.uuidString ?? ""])
        let dto = try await buildMeetingDTO(meeting: meeting, viewerId: ctx.userId, on: req)
        return .success(dto)
    }

    // MARK: - DTO builder

    private func buildMeetingDTO(meeting: MeetingModel, viewerId: UUID, on req: Request) async throws -> MeetingDTO {
        let meetingID = try meeting.requireID()

        let participants = try await MeetingParticipantModel.query(on: req.db)
            .filter(\.$meeting.$id == meetingID)
            .with(\.$user)
            .all()

        let participantDTOs: [MeetingParticipantDTO] = participants.compactMap { Self.participantToDTO($0) }
        let mine = participantDTOs.first(where: { $0.userId == viewerId })
        let waitingCount = participants.filter { $0.joinState == "waiting" }.count

        if meeting.$host.value == nil {
            try? await meeting.$host.load(on: req.db)
        }
        let hostName = meeting.$host.value?.displayName

        let baseURL = Self.publicBaseURL(for: req)
        let share = "\(baseURL)/api/meetings/by-code/\(meeting.joinCode)?token=\(meeting.accessToken)"
        let ics = "\(baseURL)/api/meetings/\(meetingID.uuidString)/ics"

        return MeetingDTO(
            id: meetingID,
            orgId: meeting.$organization.id,
            conversationId: meeting.$conversation.id,
            meetingChatConversationId: meeting.$meetingChatConversation.id,
            title: meeting.title,
            description: meeting.description,
            agenda: meeting.agenda,
            scheduledStartAt: meeting.scheduledStartAt,
            scheduledEndAt: meeting.scheduledEndAt,
            timezone: meeting.timezone,
            status: MeetingStatus(rawValue: meeting.status) ?? .scheduled,
            startedAt: meeting.startedAt,
            endedAt: meeting.endedAt,
            cancelledAt: meeting.cancelledAt,
            cancelReason: meeting.cancelReason,
            hostId: meeting.$host.id,
            hostDisplayName: hostName,
            requiresWaitingRoom: meeting.requiresWaitingRoom,
            allowGuests: meeting.allowGuests,
            joinCode: meeting.joinCode,
            shareUrl: share,
            icsUrl: ics,
            provider: MeetingProvider(rawValue: meeting.provider) ?? .internal,
            recurrence: Self.decodeRecurrence(meeting.recurrenceRule),
            parentMeetingId: meeting.$parentMeeting.id,
            participants: participantDTOs,
            myParticipant: mine,
            waitingCount: waitingCount,
            createdBy: meeting.$createdBy.id,
            createdAt: meeting.createdAt,
            updatedAt: meeting.updatedAt
        )
    }

    static func participantToDTO(_ row: MeetingParticipantModel) -> MeetingParticipantDTO? {
        guard let id = row.id else { return nil }
        let displayName: String
        if let user = row.$user.value, let u = user {
            displayName = u.displayName
        } else if let guestName = row.guestName, !guestName.isEmpty {
            displayName = guestName
        } else if let guestEmail = row.guestEmail {
            displayName = guestEmail
        } else {
            displayName = "Unknown"
        }
        return MeetingParticipantDTO(
            id: id,
            meetingId: row.$meeting.id,
            userId: row.$user.id,
            guestEmail: row.guestEmail,
            guestName: row.guestName,
            displayName: displayName,
            role: MeetingRole(rawValue: row.role) ?? .attendee,
            inviteStatus: MeetingInviteStatus(rawValue: row.inviteStatus) ?? .pending,
            joinState: MeetingJoinState(rawValue: row.joinState) ?? .notJoined,
            waitingSinceAt: row.waitingSinceAt,
            joinedAt: row.joinedAt,
            leftAt: row.leftAt,
            lastStateChangedAt: row.lastStateChangedAt
        )
    }

    // MARK: - Broadcasting

    func broadcastMeetingEvent(
        req: Request,
        orgId: UUID,
        meeting: MeetingModel,
        type: String,
        extra: [String: String] = [:]
    ) {
        guard let meetingId = try? meeting.requireID() else { return }
        var payload: [String: String] = [
            "meetingId": meetingId.uuidString,
            "status": meeting.status,
            "title": meeting.title
        ]
        for (k, v) in extra { payload[k] = v }
        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: orgId,
            channels: ["meeting:\(meetingId.uuidString)"],
            type: type,
            entityId: meetingId,
            payload: payload
        )
    }

    // MARK: - Authz helpers

    static func requireMeeting(meetingID: UUID, orgId: UUID, on db: Database) async throws -> MeetingModel {
        guard let m = try await MeetingModel.query(on: db)
            .filter(\.$id == meetingID)
            .filter(\.$organization.$id == orgId)
            .with(\.$host)
            .first() else {
            throw Abort(.notFound, reason: "Meeting not found.")
        }
        return m
    }

    static func requireParticipant(
        meetingId: UUID, userId: UUID, allowOrgAdmin: UserRole, on db: Database
    ) async throws {
        if allowOrgAdmin == .admin || allowOrgAdmin == .owner { return }
        let exists = try await MeetingParticipantModel.query(on: db)
            .filter(\.$meeting.$id == meetingId)
            .filter(\.$user.$id == userId)
            .count() > 0
        if !exists {
            throw Abort(.forbidden, reason: "Not a participant of this meeting.")
        }
    }

    static func requireParticipantRow(
        meetingId: UUID, userId: UUID, on db: Database
    ) async throws -> MeetingParticipantModel {
        guard let row = try await MeetingParticipantModel.query(on: db)
            .filter(\.$meeting.$id == meetingId)
            .filter(\.$user.$id == userId)
            .first() else {
            throw Abort(.forbidden, reason: "Not a participant of this meeting.")
        }
        return row
    }

    static func requireHost(
        meetingId: UUID, userId: UUID, allowOrgAdmin: UserRole, on db: Database
    ) async throws {
        if allowOrgAdmin == .admin || allowOrgAdmin == .owner { return }
        let row = try await MeetingParticipantModel.query(on: db)
            .filter(\.$meeting.$id == meetingId)
            .filter(\.$user.$id == userId)
            .first()
        guard let row, row.role == "host" else {
            throw Abort(.forbidden, reason: "Host privileges required.")
        }
    }

    static func requireHostOrCoHost(
        meetingId: UUID, userId: UUID, allowOrgAdmin: UserRole, on db: Database
    ) async throws {
        if allowOrgAdmin == .admin || allowOrgAdmin == .owner { return }
        let row = try await MeetingParticipantModel.query(on: db)
            .filter(\.$meeting.$id == meetingId)
            .filter(\.$user.$id == userId)
            .first()
        guard let row, row.role == "host" || row.role == "co_host" else {
            throw Abort(.forbidden, reason: "Host or co-host privileges required.")
        }
    }

    // MARK: - Misc helpers

    static func participantsByMeeting(meetingIds: [UUID], on db: Database) async throws -> [UUID: [MeetingParticipantModel]] {
        guard !meetingIds.isEmpty else { return [:] }
        let rows = try await MeetingParticipantModel.query(on: db)
            .filter(\.$meeting.$id ~~ meetingIds)
            .all()
        return Dictionary(grouping: rows, by: { $0.$meeting.id })
    }

    static func encodeRecurrence(_ rule: MeetingRecurrenceDTO?) throws -> String? {
        guard let rule else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(rule)
        return String(data: data, encoding: .utf8)
    }

    static func decodeRecurrence(_ json: String?) -> MeetingRecurrenceDTO? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MeetingRecurrenceDTO.self, from: data)
    }

    static func generateJoinCode() -> String {
        // 10-char URL-safe code: e.g. "abc-def-gh"
        let alphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")
        var out = ""
        for i in 0..<10 {
            if i == 3 || i == 6 { out.append("-") }
            out.append(alphabet.randomElement() ?? "a")
        }
        return out
    }

    static func generateAccessToken() -> String {
        // 32 base64url-ish chars
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<32).compactMap { _ in alphabet.randomElement() })
    }

    static func simpleMetadata(_ pairs: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: pairs, options: []) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Compute a public base URL for share/.ics links. Honors `PUBLIC_BASE_URL` env var,
    /// falls back to the request's Host header. Used for share & .ics URLs.
    static func publicBaseURL(for req: Request) -> String {
        if let configured = Environment.get("PUBLIC_BASE_URL"), !configured.isEmpty {
            return configured.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        let scheme = req.url.scheme ?? "http"
        let host = req.headers.first(name: .host) ?? "localhost:8080"
        return "\(scheme)://\(host)"
    }

    /// Wraps `AuditLogModel` creation. Looks up the actor's email since `AuditLogModel` requires it.
    static func audit(req: Request, action: String, meetingId: UUID, details: String?) async throws {
        let ctx = try req.orgContext
        let email = (try? await UserModel.find(ctx.userId, on: req.db))?.email ?? ""
        try await AuditLogModel(
            orgId: ctx.orgId,
            userId: ctx.userId,
            userEmail: email,
            action: action,
            resourceType: "meeting",
            resourceId: meetingId,
            details: details
        ).save(on: req.db)
    }

    static func emitNotification(
        req: Request,
        userId: UUID,
        actorId: UUID,
        meetingId: UUID,
        type: String,
        title: String
    ) async throws {
        let ctx = try req.orgContext
        let payload = simpleMetadata(["meetingId": meetingId.uuidString, "title": title])
        try await NotificationModel(
            userId: userId,
            orgId: ctx.orgId,
            actorUserId: actorId,
            entityType: "meeting",
            entityId: meetingId,
            type: type,
            payloadJson: payload
        ).save(on: req.db)
    }
}

