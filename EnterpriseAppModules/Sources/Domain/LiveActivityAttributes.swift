import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

// MARK: - Meeting Live Activity Attributes

#if canImport(ActivityKit) && os(iOS)
public struct MeetingActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var participantCount: Int
        public var isAudioMuted: Bool
        public var isVideoMuted: Bool
        public var isScreenSharing: Bool
        public var status: String
        public var startDate: Date

        public init(
            participantCount: Int = 1,
            isAudioMuted: Bool = false,
            isVideoMuted: Bool = true,
            isScreenSharing: Bool = false,
            status: String = "In Meeting",
            startDate: Date = Date()
        ) {
            self.participantCount = participantCount
            self.isAudioMuted = isAudioMuted
            self.isVideoMuted = isVideoMuted
            self.isScreenSharing = isScreenSharing
            self.status = status
            self.startDate = startDate
        }
    }

    public var meetingId: String
    public var meetingTitle: String

    public init(meetingId: String, meetingTitle: String) {
        self.meetingId = meetingId
        self.meetingTitle = meetingTitle
    }
}

// MARK: - Call Live Activity Attributes

public struct CallActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var isAudioMuted: Bool
        public var isVideoMuted: Bool
        public var isScreenSharing: Bool
        public var remoteParticipantCount: Int
        public var status: String
        public var startDate: Date

        public init(
            isAudioMuted: Bool = false,
            isVideoMuted: Bool = true,
            isScreenSharing: Bool = false,
            remoteParticipantCount: Int = 1,
            status: String = "Connected",
            startDate: Date = Date()
        ) {
            self.isAudioMuted = isAudioMuted
            self.isVideoMuted = isVideoMuted
            self.isScreenSharing = isScreenSharing
            self.remoteParticipantCount = remoteParticipantCount
            self.status = status
            self.startDate = startDate
        }
    }

    public var callId: String
    public var channelOrContactName: String

    public init(callId: String, channelOrContactName: String) {
        self.callId = callId
        self.channelOrContactName = channelOrContactName
    }
}

// MARK: - Focus Timer Live Activity Attributes

public struct FocusTimerActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var remainingSeconds: Int
        public var totalSeconds: Int
        public var isPaused: Bool
        public var targetDate: Date
        public var mode: String

        public init(
            remainingSeconds: Int,
            totalSeconds: Int,
            isPaused: Bool = false,
            targetDate: Date,
            mode: String = "Focus"
        ) {
            self.remainingSeconds = remainingSeconds
            self.totalSeconds = totalSeconds
            self.isPaused = isPaused
            self.targetDate = targetDate
            self.mode = mode
        }
    }

    public var sessionTitle: String
    public var targetMinutes: Int

    public init(sessionTitle: String, targetMinutes: Int) {
        self.sessionTitle = sessionTitle
        self.targetMinutes = targetMinutes
    }
}
#endif
