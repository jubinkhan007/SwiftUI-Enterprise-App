import Fluent
import SharedModels
import Vapor

/// Phase 4-B (Calls). Manages ad-hoc and meeting-attached SFU sessions:
/// initiate / accept / decline / end + admin actions (mute-remote, lock,
/// eject) + LiveKit-compatible token issuance per join.
struct CallController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let calls = routes.grouped("calls")
        calls.post("initiate", use: initiate)
        calls.get(":callID", use: show)
        calls.post(":callID", "accept", use: accept)
        calls.post(":callID", "decline", use: decline)
        calls.post(":callID", "end", use: end)
        calls.post(":callID", "leave", use: leave)
        calls.put(":callID", "state", use: updateMyState)
        calls.post(":callID", "admin", use: adminAction)
        calls.get(":callID", "token", use: refreshToken)
        calls.post(":callID", "records", use: createRecord)

        // VoIP push tokens
        let me = routes.grouped("me")
        me.post("voip-tokens", use: registerVoIPToken)
        me.delete("voip-tokens", ":token", use: deleteVoIPToken)
    }

    // MARK: - Initiate

    @Sendable
    func initiate(req: Request) async throws -> APIResponse<CallJoinTicketDTO> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(InitiateCallRequest.self)

        let isMember = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$conversation.$id == payload.conversationId)
            .filter(\.$user.$id == ctx.userId)
            .count() > 0
        guard isMember else {
            throw Abort(.forbidden, reason: "Not a member of this conversation.")
        }

        if let meetingId = payload.meetingId {
            let belongs = try await MeetingModel.query(on: req.db)
                .filter(\.$id == meetingId)
                .filter(\.$organization.$id == ctx.orgId)
                .count() > 0
            guard belongs else { throw Abort(.notFound, reason: "Meeting not found.") }
        }

        // If an active call already exists for this conversation, return it
        // instead of creating a parallel session.
        if let existing = try await CallSessionModel.query(on: req.db)
            .filter(\.$conversation.$id == payload.conversationId)
            .filter(\.$status ~~ ["initiated", "active"])
            .first() {
            let ticket = try await join(callSession: existing, userId: ctx.userId, ctx: ctx, on: req)
            return .success(ticket)
        }

        let room = Self.generateRoomName(orgId: ctx.orgId)
        let session = CallSessionModel(
            conversationId: payload.conversationId,
            meetingId: payload.meetingId,
            hostId: ctx.userId,
            orgId: ctx.orgId,
            roomName: room,
            hasVideo: payload.hasVideo,
            provider: "livekit",
            status: "initiated"
        )
        try await session.save(on: req.db)
        let sessionID = try session.requireID()

        // Host participant (host role)
        let hostParticipant = CallParticipantModel(
            callSessionId: sessionID,
            userId: ctx.userId,
            role: "host",
            status: "connected"
        )
        hostParticipant.joinedAt = Date()
        try await hostParticipant.save(on: req.db)

        // Ring everyone else in the conversation
        let others = try await ConversationMemberModel.query(on: req.db)
            .filter(\.$conversation.$id == payload.conversationId)
            .filter(\.$user.$id != ctx.userId)
            .all()
        for member in others {
            let p = CallParticipantModel(
                callSessionId: sessionID,
                userId: member.$user.id,
                role: "participant",
                status: "ringing"
            )
            try await p.save(on: req.db)
            try? await emitCallNotification(req: req, userId: member.$user.id, actorId: ctx.userId, callSessionId: sessionID, type: "call.incoming")
        }

        broadcast(req: req, orgId: ctx.orgId, session: session, type: "call.initiated", channels: ["conversation:\(payload.conversationId.uuidString)"])

        let ticket = try await join(callSession: session, userId: ctx.userId, ctx: ctx, on: req)
        return .success(ticket)
    }

    // MARK: - Show / Token

    @Sendable
    func show(req: Request) async throws -> APIResponse<CallSessionDTO> {
        let ctx = try req.orgContext
        let callID = try req.parameters.require("callID", as: UUID.self)
        let session = try await requireSession(callID: callID, orgId: ctx.orgId, on: req.db)
        try await requireParticipant(callId: callID, userId: ctx.userId, on: req.db)
        let dto = try await buildSessionDTO(session: session, viewerId: ctx.userId, on: req.db)
        return .success(dto)
    }

    @Sendable
    func refreshToken(req: Request) async throws -> APIResponse<CallTokenDTO> {
        let ctx = try req.orgContext
        let callID = try req.parameters.require("callID", as: UUID.self)
        let session = try await requireSession(callID: callID, orgId: ctx.orgId, on: req.db)
        let participant = try await requireParticipantRow(callId: callID, userId: ctx.userId, on: req.db)
        let token = try await issueToken(session: session, participant: participant, on: req.db)
        return .success(token)
    }

    // MARK: - Accept / Decline / Leave / End

    @Sendable
    func accept(req: Request) async throws -> APIResponse<CallJoinTicketDTO> {
        let ctx = try req.orgContext
        let callID = try req.parameters.require("callID", as: UUID.self)
        let session = try await requireSession(callID: callID, orgId: ctx.orgId, on: req.db)
        guard session.status != "ended", session.status != "cancelled" else {
            throw Abort(.badRequest, reason: "Call is no longer active.")
        }
        if session.isLocked {
            throw Abort(.forbidden, reason: "Room is locked.")
        }
        // Flip session to active on first accept.
        if session.status == "initiated" {
            session.status = "active"
            try await session.save(on: req.db)
            broadcast(req: req, orgId: ctx.orgId, session: session, type: "call.active",
                      channels: ["conversation:\(session.$conversation.id.uuidString)", "call:\(callID.uuidString)"])
        }
        let ticket = try await join(callSession: session, userId: ctx.userId, ctx: ctx, on: req)
        return .success(ticket)
    }

    @Sendable
    func decline(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let callID = try req.parameters.require("callID", as: UUID.self)
        let participant = try await requireParticipantRow(callId: callID, userId: ctx.userId, on: req.db)
        participant.status = "declined"
        try await participant.save(on: req.db)

        if let session = try await CallSessionModel.find(callID, on: req.db) {
            broadcast(req: req, orgId: ctx.orgId, session: session, type: "call.participant_declined",
                      channels: ["call:\(callID.uuidString)", "conversation:\(session.$conversation.id.uuidString)"],
                      extra: ["userId": ctx.userId.uuidString])
        }
        return .success(EmptyResponse())
    }

    @Sendable
    func leave(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let callID = try req.parameters.require("callID", as: UUID.self)
        let participant = try await requireParticipantRow(callId: callID, userId: ctx.userId, on: req.db)
        participant.status = "disconnected"
        participant.leftAt = Date()
        try await participant.save(on: req.db)

        if let session = try await CallSessionModel.find(callID, on: req.db) {
            broadcast(req: req, orgId: ctx.orgId, session: session, type: "call.participant_left",
                      channels: ["call:\(callID.uuidString)"],
                      extra: ["userId": ctx.userId.uuidString])

            // If everyone has left, end the call.
            let activeCount = try await CallParticipantModel.query(on: req.db)
                .filter(\.$callSession.$id == callID)
                .filter(\.$status == "connected")
                .count()
            if activeCount == 0 {
                session.status = "ended"
                session.endedAt = Date()
                try await session.save(on: req.db)
                broadcast(req: req, orgId: ctx.orgId, session: session, type: "call.ended",
                          channels: ["call:\(callID.uuidString)", "conversation:\(session.$conversation.id.uuidString)"])
            }
        }
        return .success(EmptyResponse())
    }

    @Sendable
    func end(req: Request) async throws -> APIResponse<CallSessionDTO> {
        let ctx = try req.orgContext
        let callID = try req.parameters.require("callID", as: UUID.self)
        let session = try await requireSession(callID: callID, orgId: ctx.orgId, on: req.db)
        try requireHost(session: session, userId: ctx.userId)

        if session.status != "ended" {
            session.status = "ended"
            session.endedAt = Date()
            try await session.save(on: req.db)

            // Disconnect every connected participant.
            let connected = try await CallParticipantModel.query(on: req.db)
                .filter(\.$callSession.$id == callID)
                .filter(\.$status == "connected")
                .all()
            for p in connected {
                p.status = "disconnected"
                p.leftAt = Date()
                try await p.save(on: req.db)
            }

            broadcast(req: req, orgId: ctx.orgId, session: session, type: "call.ended",
                      channels: ["call:\(callID.uuidString)", "conversation:\(session.$conversation.id.uuidString)"])
        }
        let dto = try await buildSessionDTO(session: session, viewerId: ctx.userId, on: req.db)
        return .success(dto)
    }

    // MARK: - Participant state

    @Sendable
    func updateMyState(req: Request) async throws -> APIResponse<CallParticipantDTO> {
        let ctx = try req.orgContext
        let callID = try req.parameters.require("callID", as: UUID.self)
        let payload = try req.content.decode(UpdateParticipantStateRequest.self)
        let participant = try await requireParticipantRow(callId: callID, userId: ctx.userId, on: req.db)

        if let am = payload.isAudioMuted { participant.isAudioMuted = am }
        if let vm = payload.isVideoMuted { participant.isVideoMuted = vm }
        if let ss = payload.isScreenSharing { participant.isScreenSharing = ss }
        try await participant.save(on: req.db)

        try await participant.$user.load(on: req.db)
        let dto = Self.participantToDTO(participant)

        if let session = try await CallSessionModel.find(callID, on: req.db) {
            broadcast(req: req, orgId: ctx.orgId, session: session, type: "call.participant_state",
                      channels: ["call:\(callID.uuidString)"],
                      extra: [
                        "userId": ctx.userId.uuidString,
                        "isAudioMuted": String(participant.isAudioMuted),
                        "isVideoMuted": String(participant.isVideoMuted),
                        "isScreenSharing": String(participant.isScreenSharing)
                      ])
        }
        return .success(dto!)
    }

    @Sendable
    func adminAction(req: Request) async throws -> APIResponse<CallSessionDTO> {
        let ctx = try req.orgContext
        let callID = try req.parameters.require("callID", as: UUID.self)
        let payload = try req.content.decode(CallAdminEventRequest.self)
        let session = try await requireSession(callID: callID, orgId: ctx.orgId, on: req.db)
        try requireHost(session: session, userId: ctx.userId)

        var extra: [String: String] = ["action": payload.action.rawValue]
        if let target = payload.targetParticipantId {
            extra["participantId"] = target.uuidString
        }

        switch payload.action {
        case .lockRoom:
            session.isLocked = true
            try await session.save(on: req.db)
        case .unlockRoom:
            session.isLocked = false
            try await session.save(on: req.db)
        case .eject:
            guard let pid = payload.targetParticipantId,
                  let target = try await CallParticipantModel.find(pid, on: req.db) else {
                throw Abort(.badRequest, reason: "Missing target participant.")
            }
            target.status = "ejected"
            target.leftAt = Date()
            try await target.save(on: req.db)
        case .muteRemoteAudio:
            if let pid = payload.targetParticipantId, let target = try await CallParticipantModel.find(pid, on: req.db) {
                target.isAudioMuted = true
                try await target.save(on: req.db)
            }
        case .muteRemoteVideo:
            if let pid = payload.targetParticipantId, let target = try await CallParticipantModel.find(pid, on: req.db) {
                target.isVideoMuted = true
                try await target.save(on: req.db)
            }
        case .stopScreenShare:
            if let pid = payload.targetParticipantId, let target = try await CallParticipantModel.find(pid, on: req.db) {
                target.isScreenSharing = false
                try await target.save(on: req.db)
            }
        case .promoteToPresenter:
            if let pid = payload.targetParticipantId, let target = try await CallParticipantModel.find(pid, on: req.db) {
                target.role = "presenter"
                try await target.save(on: req.db)
            }
        case .demoteFromPresenter:
            if let pid = payload.targetParticipantId, let target = try await CallParticipantModel.find(pid, on: req.db) {
                target.role = "participant"
                try await target.save(on: req.db)
            }
        }

        broadcast(req: req, orgId: ctx.orgId, session: session, type: "call.admin",
                  channels: ["call:\(callID.uuidString)"], extra: extra)

        let dto = try await buildSessionDTO(session: session, viewerId: ctx.userId, on: req.db)
        return .success(dto)
    }

    // MARK: - Records

    @Sendable
    func createRecord(req: Request) async throws -> APIResponse<CallRecordDTO> {
        let ctx = try req.orgContext
        let callID = try req.parameters.require("callID", as: UUID.self)
        let payload = try req.content.decode(CreateCallRecordRequest.self)
        let session = try await requireSession(callID: callID, orgId: ctx.orgId, on: req.db)
        try requireHost(session: session, userId: ctx.userId)

        let row = CallRecordModel(
            callSessionId: callID,
            recordingUrl: payload.recordingUrl,
            summaryUrl: payload.summaryUrl,
            durationSecs: payload.durationSecs
        )
        try await row.save(on: req.db)

        return .success(CallRecordDTO(
            id: try row.requireID(),
            callSessionId: callID,
            recordingUrl: row.recordingUrl,
            summaryUrl: row.summaryUrl,
            durationSecs: row.durationSecs,
            createdAt: row.createdAt
        ))
    }

    // MARK: - VoIP tokens

    @Sendable
    func registerVoIPToken(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let payload = try req.content.decode(RegisterVoIPTokenRequest.self)
        let token = payload.deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw Abort(.badRequest, reason: "Empty device token.") }

        if let existing = try await VoIPDeviceTokenModel.query(on: req.db)
            .filter(\.$deviceToken == token)
            .first() {
            existing.$user.id = ctx.userId
            existing.bundleId = payload.bundleId
            existing.environment = payload.environment
            try await existing.save(on: req.db)
        } else {
            try await VoIPDeviceTokenModel(
                userId: ctx.userId,
                deviceToken: token,
                bundleId: payload.bundleId,
                environment: payload.environment
            ).save(on: req.db)
        }
        return .success(EmptyResponse())
    }

    @Sendable
    func deleteVoIPToken(req: Request) async throws -> APIResponse<EmptyResponse> {
        let ctx = try req.orgContext
        let token = try req.parameters.require("token", as: String.self)
        try await VoIPDeviceTokenModel.query(on: req.db)
            .filter(\.$deviceToken == token)
            .filter(\.$user.$id == ctx.userId)
            .delete()
        return .success(EmptyResponse())
    }

    // MARK: - Helpers

    private func join(callSession: CallSessionModel, userId: UUID, ctx: OrgContext, on req: Request) async throws -> CallJoinTicketDTO {
        let participant: CallParticipantModel
        if let existing = try await CallParticipantModel.query(on: req.db)
            .filter(\.$callSession.$id == callSession.requireID())
            .filter(\.$user.$id == userId)
            .first() {
            existing.status = "connected"
            existing.joinedAt = existing.joinedAt ?? Date()
            try await existing.save(on: req.db)
            participant = existing
        } else {
            // Late join — only allowed if room not locked.
            if callSession.isLocked {
                throw Abort(.forbidden, reason: "Room is locked.")
            }
            let fresh = CallParticipantModel(
                callSessionId: try callSession.requireID(),
                userId: userId,
                role: "participant",
                status: "connected"
            )
            fresh.joinedAt = Date()
            try await fresh.save(on: req.db)
            participant = fresh
        }

        try await participant.$user.load(on: req.db)
        let token = try await issueToken(session: callSession, participant: participant, on: req.db)
        let session = try await buildSessionDTO(session: callSession, viewerId: userId, on: req.db)

        let callID = try callSession.requireID()
        broadcast(req: req, orgId: ctx.orgId, session: callSession, type: "call.participant_joined",
                  channels: ["call:\(callID.uuidString)"],
                  extra: ["userId": userId.uuidString])

        return CallJoinTicketDTO(session: session, token: token)
    }

    private func issueToken(session: CallSessionModel, participant: CallParticipantModel, on db: Database) async throws -> CallTokenDTO {
        if participant.$user.value == nil {
            try await participant.$user.load(on: db)
        }
        let user = participant.$user.value
        let identity = participant.$user.id.uuidString
        let displayName = user?.displayName ?? identity

        let canPublish = participant.role != "participant" || true  // viewers can be promoted; default all-publish
        let isPresenter = participant.role == "host" || participant.role == "presenter"
        let grants = LiveKitTokenSigner.Grants(
            canPublish: canPublish,
            canSubscribe: true,
            canPublishData: true,
            canPublishSources: isPresenter ? ["camera", "microphone", "screen_share", "screen_share_audio"] : ["camera", "microphone"],
            roomAdmin: participant.role == "host",
            roomCreate: false
        )

        let signed = LiveKitTokenSigner.sign(
            roomName: session.roomName,
            identity: identity,
            displayName: displayName,
            grants: grants
        )

        return CallTokenDTO(
            callSessionId: try session.requireID(),
            roomName: session.roomName,
            identity: identity,
            token: signed.token,
            provider: CallProvider(rawValue: session.provider) ?? .livekit,
            url: signed.serverUrl,
            canPublish: grants.canPublish,
            canSubscribe: grants.canSubscribe,
            canPublishData: grants.canPublishData,
            expiresAt: signed.expiresAt
        )
    }

    private func buildSessionDTO(session: CallSessionModel, viewerId: UUID, on db: Database) async throws -> CallSessionDTO {
        let id = try session.requireID()
        let rows = try await CallParticipantModel.query(on: db)
            .filter(\.$callSession.$id == id)
            .with(\.$user)
            .all()
        let participants = rows.compactMap { Self.participantToDTO($0) }
        let mine = participants.first { $0.userId == viewerId }
        return CallSessionDTO(
            id: id,
            orgId: session.$organization.id,
            conversationId: session.$conversation.id,
            meetingId: session.$meeting.id,
            hostId: session.$host.id,
            status: CallSessionStatus(rawValue: session.status) ?? .initiated,
            roomName: session.roomName,
            hasVideo: session.hasVideo,
            isLocked: session.isLocked,
            provider: CallProvider(rawValue: session.provider) ?? .livekit,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            participants: participants,
            myParticipant: mine
        )
    }

    static func participantToDTO(_ row: CallParticipantModel) -> CallParticipantDTO? {
        guard let id = row.id else { return nil }
        let displayName = row.$user.value?.displayName ?? "Unknown"
        return CallParticipantDTO(
            id: id,
            callSessionId: row.$callSession.id,
            userId: row.$user.id,
            displayName: displayName,
            role: CallParticipantRole(rawValue: row.role) ?? .participant,
            status: CallParticipantStatus(rawValue: row.status) ?? .invited,
            isAudioMuted: row.isAudioMuted,
            isVideoMuted: row.isVideoMuted,
            isScreenSharing: row.isScreenSharing,
            joinedAt: row.joinedAt,
            leftAt: row.leftAt
        )
    }

    private func requireSession(callID: UUID, orgId: UUID, on db: Database) async throws -> CallSessionModel {
        guard let session = try await CallSessionModel.query(on: db)
            .filter(\.$id == callID)
            .filter(\.$organization.$id == orgId)
            .first() else {
            throw Abort(.notFound, reason: "Call not found.")
        }
        return session
    }

    private func requireParticipant(callId: UUID, userId: UUID, on db: Database) async throws {
        let exists = try await CallParticipantModel.query(on: db)
            .filter(\.$callSession.$id == callId)
            .filter(\.$user.$id == userId)
            .count() > 0
        if !exists {
            throw Abort(.forbidden, reason: "Not a participant of this call.")
        }
    }

    private func requireParticipantRow(callId: UUID, userId: UUID, on db: Database) async throws -> CallParticipantModel {
        guard let row = try await CallParticipantModel.query(on: db)
            .filter(\.$callSession.$id == callId)
            .filter(\.$user.$id == userId)
            .first() else {
            throw Abort(.forbidden, reason: "Not a participant of this call.")
        }
        return row
    }

    private func requireHost(session: CallSessionModel, userId: UUID) throws {
        guard session.$host.id == userId else {
            throw Abort(.forbidden, reason: "Host privileges required.")
        }
    }

    private func emitCallNotification(req: Request, userId: UUID, actorId: UUID, callSessionId: UUID, type: String) async throws {
        let ctx = try req.orgContext
        let payload: [String: String] = [
            "callSessionId": callSessionId.uuidString,
            "actorId": actorId.uuidString
        ]
        let payloadJson = try? String(
            data: JSONSerialization.data(withJSONObject: payload, options: []),
            encoding: .utf8
        )
        try? await NotificationModel(
            userId: userId,
            orgId: ctx.orgId,
            actorUserId: actorId,
            entityType: "call",
            entityId: callSessionId,
            type: type,
            payloadJson: payloadJson
        ).save(on: req.db)
    }

    private func broadcast(
        req: Request,
        orgId: UUID,
        session: CallSessionModel,
        type: String,
        channels: [String],
        extra: [String: String] = [:]
    ) {
        guard let id = try? session.requireID() else { return }
        var payload: [String: String] = [
            "callSessionId": id.uuidString,
            "conversationId": session.$conversation.id.uuidString,
            "status": session.status
        ]
        for (k, v) in extra { payload[k] = v }
        RealtimeBroadcaster.broadcast(
            app: req.application,
            orgId: orgId,
            channels: channels,
            type: type,
            entityId: id,
            payload: payload
        )
    }

    static func generateRoomName(orgId: UUID) -> String {
        "org-\(orgId.uuidString.prefix(8).lowercased())-\(UUID().uuidString.prefix(12).lowercased())"
    }
}
