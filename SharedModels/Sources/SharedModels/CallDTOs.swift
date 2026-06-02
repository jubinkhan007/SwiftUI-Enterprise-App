import Foundation

// MARK: - Enums

public enum CallSessionStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case initiated
    case active
    case ended
    case cancelled
}

public enum CallParticipantRole: String, Codable, Sendable, CaseIterable, Hashable {
    case host
    case presenter
    case participant
}

public enum CallParticipantStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case invited
    case ringing
    case connected
    case declined
    case disconnected
    case ejected
}

public enum CallProvider: String, Codable, Sendable, CaseIterable, Hashable {
    case `internal`
    case livekit
    case agora
}

public enum CallAdminAction: String, Codable, Sendable, CaseIterable, Hashable {
    case muteRemoteAudio = "mute_remote_audio"
    case muteRemoteVideo = "mute_remote_video"
    case stopScreenShare = "stop_screen_share"
    case eject
    case lockRoom = "lock_room"
    case unlockRoom = "unlock_room"
    case promoteToPresenter = "promote_to_presenter"
    case demoteFromPresenter = "demote_from_presenter"
}

// MARK: - Response DTOs

public struct CallParticipantDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let callSessionId: UUID
    public let userId: UUID
    public let displayName: String
    public let role: CallParticipantRole
    public let status: CallParticipantStatus
    public let isAudioMuted: Bool
    public let isVideoMuted: Bool
    public let isScreenSharing: Bool
    public let joinedAt: Date?
    public let leftAt: Date?

    public init(
        id: UUID,
        callSessionId: UUID,
        userId: UUID,
        displayName: String,
        role: CallParticipantRole,
        status: CallParticipantStatus,
        isAudioMuted: Bool = false,
        isVideoMuted: Bool = false,
        isScreenSharing: Bool = false,
        joinedAt: Date? = nil,
        leftAt: Date? = nil
    ) {
        self.id = id
        self.callSessionId = callSessionId
        self.userId = userId
        self.displayName = displayName
        self.role = role
        self.status = status
        self.isAudioMuted = isAudioMuted
        self.isVideoMuted = isVideoMuted
        self.isScreenSharing = isScreenSharing
        self.joinedAt = joinedAt
        self.leftAt = leftAt
    }
}

public struct CallSessionDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let orgId: UUID
    public let conversationId: UUID
    public let meetingId: UUID?
    public let hostId: UUID
    public let status: CallSessionStatus
    public let roomName: String
    public let hasVideo: Bool
    public let isLocked: Bool
    public let provider: CallProvider
    public let startedAt: Date?
    public let endedAt: Date?
    public let participants: [CallParticipantDTO]
    public let myParticipant: CallParticipantDTO?

    public init(
        id: UUID,
        orgId: UUID,
        conversationId: UUID,
        meetingId: UUID? = nil,
        hostId: UUID,
        status: CallSessionStatus,
        roomName: String,
        hasVideo: Bool,
        isLocked: Bool,
        provider: CallProvider,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        participants: [CallParticipantDTO] = [],
        myParticipant: CallParticipantDTO? = nil
    ) {
        self.id = id
        self.orgId = orgId
        self.conversationId = conversationId
        self.meetingId = meetingId
        self.hostId = hostId
        self.status = status
        self.roomName = roomName
        self.hasVideo = hasVideo
        self.isLocked = isLocked
        self.provider = provider
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.participants = participants
        self.myParticipant = myParticipant
    }
}

public struct CallTokenDTO: Codable, Sendable, Hashable {
    public let callSessionId: UUID
    public let roomName: String
    public let identity: String
    public let token: String
    public let provider: CallProvider
    public let url: String?
    public let canPublish: Bool
    public let canSubscribe: Bool
    public let canPublishData: Bool
    public let expiresAt: Date

    public init(
        callSessionId: UUID,
        roomName: String,
        identity: String,
        token: String,
        provider: CallProvider,
        url: String? = nil,
        canPublish: Bool,
        canSubscribe: Bool,
        canPublishData: Bool,
        expiresAt: Date
    ) {
        self.callSessionId = callSessionId
        self.roomName = roomName
        self.identity = identity
        self.token = token
        self.provider = provider
        self.url = url
        self.canPublish = canPublish
        self.canSubscribe = canSubscribe
        self.canPublishData = canPublishData
        self.expiresAt = expiresAt
    }
}

public struct CallJoinTicketDTO: Codable, Sendable, Hashable {
    public let session: CallSessionDTO
    public let token: CallTokenDTO

    public init(session: CallSessionDTO, token: CallTokenDTO) {
        self.session = session
        self.token = token
    }
}

// MARK: - Requests

public struct InitiateCallRequest: Codable, Sendable, Hashable {
    public let conversationId: UUID
    public let meetingId: UUID?
    public let hasVideo: Bool

    public init(conversationId: UUID, meetingId: UUID? = nil, hasVideo: Bool = true) {
        self.conversationId = conversationId
        self.meetingId = meetingId
        self.hasVideo = hasVideo
    }
}

public struct CallAdminEventRequest: Codable, Sendable, Hashable {
    public let action: CallAdminAction
    /// Target participant id (or NULL for room-level actions like lock/unlock).
    public let targetParticipantId: UUID?

    public init(action: CallAdminAction, targetParticipantId: UUID? = nil) {
        self.action = action
        self.targetParticipantId = targetParticipantId
    }
}

public struct UpdateParticipantStateRequest: Codable, Sendable, Hashable {
    public let isAudioMuted: Bool?
    public let isVideoMuted: Bool?
    public let isScreenSharing: Bool?

    public init(isAudioMuted: Bool? = nil, isVideoMuted: Bool? = nil, isScreenSharing: Bool? = nil) {
        self.isAudioMuted = isAudioMuted
        self.isVideoMuted = isVideoMuted
        self.isScreenSharing = isScreenSharing
    }
}

public struct RegisterVoIPTokenRequest: Codable, Sendable, Hashable {
    public let deviceToken: String
    public let bundleId: String
    public let environment: String  // "sandbox" / "production"

    public init(deviceToken: String, bundleId: String, environment: String = "sandbox") {
        self.deviceToken = deviceToken
        self.bundleId = bundleId
        self.environment = environment
    }
}

public struct CreateCallRecordRequest: Codable, Sendable, Hashable {
    public let recordingUrl: String?
    public let summaryUrl: String?
    public let durationSecs: Int?

    public init(recordingUrl: String? = nil, summaryUrl: String? = nil, durationSecs: Int? = nil) {
        self.recordingUrl = recordingUrl
        self.summaryUrl = summaryUrl
        self.durationSecs = durationSecs
    }
}

public struct CallRecordDTO: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let callSessionId: UUID
    public let recordingUrl: String?
    public let summaryUrl: String?
    public let durationSecs: Int?
    public let createdAt: Date?

    public init(
        id: UUID,
        callSessionId: UUID,
        recordingUrl: String? = nil,
        summaryUrl: String? = nil,
        durationSecs: Int? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.callSessionId = callSessionId
        self.recordingUrl = recordingUrl
        self.summaryUrl = summaryUrl
        self.durationSecs = durationSecs
        self.createdAt = createdAt
    }
}
