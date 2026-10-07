import Foundation
import Domain
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

/// Singleton coordinator managing iOS Live Activities and Dynamic Island states
/// for active Meetings, Calls, and Focus Timers.
@MainActor
public final class LiveActivityManager {
    public static let shared = LiveActivityManager()

    #if canImport(ActivityKit) && os(iOS)
    private var meetingActivity: Activity<MeetingActivityAttributes>?
    private var callActivity: Activity<CallActivityAttributes>?
    private var focusTimerActivity: Activity<FocusTimerActivityAttributes>?
    #endif

    public var areActivitiesSupported: Bool {
        #if canImport(ActivityKit) && os(iOS)
        return ActivityAuthorizationInfo().areActivitiesEnabled
        #else
        return false
        #endif
    }

    private init() {}

    // MARK: - Meeting Live Activity

    public func startMeetingActivity(
        meetingId: String,
        title: String,
        participantCount: Int = 1,
        isAudioMuted: Bool = false,
        isVideoMuted: Bool = true,
        isScreenSharing: Bool = false
    ) {
        #if canImport(ActivityKit) && os(iOS)
        guard areActivitiesSupported else { return }

        // End any existing meeting activity first
        endMeetingActivity()

        let attributes = MeetingActivityAttributes(meetingId: meetingId, meetingTitle: title)
        let initialContentState = MeetingActivityAttributes.ContentState(
            participantCount: participantCount,
            isAudioMuted: isAudioMuted,
            isVideoMuted: isVideoMuted,
            isScreenSharing: isScreenSharing,
            status: "In Meeting",
            startDate: Date()
        )

        do {
            let activity = try Activity<MeetingActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialContentState, staleDate: nil),
                pushType: nil
            )
            self.meetingActivity = activity
        } catch {
            print("[LiveActivityManager] Failed to start Meeting Activity: \(error)")
        }
        #endif
    }

    public func updateMeetingActivity(
        participantCount: Int? = nil,
        isAudioMuted: Bool? = nil,
        isVideoMuted: Bool? = nil,
        isScreenSharing: Bool? = nil,
        status: String? = nil
    ) {
        #if canImport(ActivityKit) && os(iOS)
        guard let activity = meetingActivity else { return }

        var state = activity.content.state
        if let participantCount { state.participantCount = participantCount }
        if let isAudioMuted { state.isAudioMuted = isAudioMuted }
        if let isVideoMuted { state.isVideoMuted = isVideoMuted }
        if let isScreenSharing { state.isScreenSharing = isScreenSharing }
        if let status { state.status = status }

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
        #endif
    }

    public func endMeetingActivity() {
        #if canImport(ActivityKit) && os(iOS)
        guard let activity = meetingActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.meetingActivity = nil
        #endif
    }

    // MARK: - Call Live Activity

    public func startCallActivity(
        callId: String,
        channelOrContactName: String,
        remoteParticipantCount: Int = 1,
        isAudioMuted: Bool = false,
        isVideoMuted: Bool = true,
        isScreenSharing: Bool = false
    ) {
        #if canImport(ActivityKit) && os(iOS)
        guard areActivitiesSupported else { return }

        endCallActivity()

        let attributes = CallActivityAttributes(
            callId: callId,
            channelOrContactName: channelOrContactName
        )
        let initialContentState = CallActivityAttributes.ContentState(
            isAudioMuted: isAudioMuted,
            isVideoMuted: isVideoMuted,
            isScreenSharing: isScreenSharing,
            remoteParticipantCount: remoteParticipantCount,
            status: "Connected",
            startDate: Date()
        )

        do {
            let activity = try Activity<CallActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialContentState, staleDate: nil),
                pushType: nil
            )
            self.callActivity = activity
        } catch {
            print("[LiveActivityManager] Failed to start Call Activity: \(error)")
        }
        #endif
    }

    public func updateCallActivity(
        remoteParticipantCount: Int? = nil,
        isAudioMuted: Bool? = nil,
        isVideoMuted: Bool? = nil,
        isScreenSharing: Bool? = nil,
        status: String? = nil
    ) {
        #if canImport(ActivityKit) && os(iOS)
        guard let activity = callActivity else { return }

        var state = activity.content.state
        if let remoteParticipantCount { state.remoteParticipantCount = remoteParticipantCount }
        if let isAudioMuted { state.isAudioMuted = isAudioMuted }
        if let isVideoMuted { state.isVideoMuted = isVideoMuted }
        if let isScreenSharing { state.isScreenSharing = isScreenSharing }
        if let status { state.status = status }

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
        #endif
    }

    public func endCallActivity() {
        #if canImport(ActivityKit) && os(iOS)
        guard let activity = callActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.callActivity = nil
        #endif
    }

    // MARK: - Focus Timer Live Activity

    public func startFocusTimerActivity(
        sessionTitle: String,
        targetMinutes: Int,
        mode: String = "Focus"
    ) {
        #if canImport(ActivityKit) && os(iOS)
        guard areActivitiesSupported else { return }

        endFocusTimerActivity()

        let attributes = FocusTimerActivityAttributes(
            sessionTitle: sessionTitle,
            targetMinutes: targetMinutes
        )
        let totalSecs = targetMinutes * 60
        let target = Date().addingTimeInterval(TimeInterval(totalSecs))
        let initialContentState = FocusTimerActivityAttributes.ContentState(
            remainingSeconds: totalSecs,
            totalSeconds: totalSecs,
            isPaused: false,
            targetDate: target,
            mode: mode
        )

        do {
            let activity = try Activity<FocusTimerActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialContentState, staleDate: nil),
                pushType: nil
            )
            self.focusTimerActivity = activity
        } catch {
            print("[LiveActivityManager] Failed to start Focus Timer Activity: \(error)")
        }
        #endif
    }

    public func updateFocusTimerActivity(
        remainingSeconds: Int? = nil,
        totalSeconds: Int? = nil,
        isPaused: Bool? = nil,
        targetDate: Date? = nil,
        mode: String? = nil
    ) {
        #if canImport(ActivityKit) && os(iOS)
        guard let activity = focusTimerActivity else { return }

        var state = activity.content.state
        if let remainingSeconds { state.remainingSeconds = remainingSeconds }
        if let totalSeconds { state.totalSeconds = totalSeconds }
        if let isPaused { state.isPaused = isPaused }
        if let targetDate { state.targetDate = targetDate }
        if let mode { state.mode = mode }

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
        #endif
    }

    public func endFocusTimerActivity() {
        #if canImport(ActivityKit) && os(iOS)
        guard let activity = focusTimerActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.focusTimerActivity = nil
        #endif
    }
}
