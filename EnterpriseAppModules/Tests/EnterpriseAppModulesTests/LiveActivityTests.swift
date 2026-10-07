import XCTest
@testable import Domain
@testable import AppData

final class LiveActivityTests: XCTestCase {
    @MainActor
    func testLiveActivityManagerMethodsDoNotCrash() {
        let manager = LiveActivityManager.shared

        // Test meeting lifecycle
        manager.startMeetingActivity(
            meetingId: "meeting-123",
            title: "Sprint Planning",
            participantCount: 5,
            isAudioMuted: false,
            isVideoMuted: true,
            isScreenSharing: false
        )
        manager.updateMeetingActivity(
            participantCount: 6,
            isAudioMuted: true,
            isVideoMuted: false,
            isScreenSharing: true,
            status: "In Meeting"
        )
        manager.endMeetingActivity()

        // Test call lifecycle
        manager.startCallActivity(
            callId: "call-456",
            channelOrContactName: "General Chat",
            remoteParticipantCount: 2,
            isAudioMuted: true,
            isVideoMuted: true,
            isScreenSharing: false
        )
        manager.updateCallActivity(
            remoteParticipantCount: 3,
            isAudioMuted: false,
            isVideoMuted: false,
            isScreenSharing: false,
            status: "Connected"
        )
        manager.endCallActivity()

        // Test focus timer lifecycle
        manager.startFocusTimerActivity(
            sessionTitle: "Deep Work Sprint",
            targetMinutes: 25,
            mode: "Focus"
        )
        manager.updateFocusTimerActivity(
            remainingSeconds: 20 * 60,
            totalSeconds: 25 * 60,
            isPaused: true,
            targetDate: Date().addingTimeInterval(1200),
            mode: "Focus"
        )
        manager.endFocusTimerActivity()

        XCTAssertTrue(true, "LiveActivityManager executed all lifecycle methods safely.")
    }

    #if canImport(ActivityKit) && os(iOS)
    func testMeetingActivityAttributesContentState() {
        let now = Date()
        let state = MeetingActivityAttributes.ContentState(
            participantCount: 4,
            isAudioMuted: true,
            isVideoMuted: false,
            isScreenSharing: true,
            status: "In Meeting",
            startDate: now
        )
        let attributes = MeetingActivityAttributes(meetingId: "m-1", meetingTitle: "Demo")

        XCTAssertEqual(attributes.meetingId, "m-1")
        XCTAssertEqual(attributes.meetingTitle, "Demo")
        XCTAssertEqual(state.participantCount, 4)
        XCTAssertTrue(state.isAudioMuted)
        XCTAssertFalse(state.isVideoMuted)
        XCTAssertTrue(state.isScreenSharing)
    }

    func testCallActivityAttributesContentState() {
        let now = Date()
        let state = CallActivityAttributes.ContentState(
            isAudioMuted: false,
            isVideoMuted: true,
            isScreenSharing: false,
            remoteParticipantCount: 3,
            status: "Connected",
            startDate: now
        )
        let attributes = CallActivityAttributes(callId: "c-1", channelOrContactName: "Engineering")

        XCTAssertEqual(attributes.callId, "c-1")
        XCTAssertEqual(attributes.channelOrContactName, "Engineering")
        XCTAssertEqual(state.remoteParticipantCount, 3)
        XCTAssertFalse(state.isAudioMuted)
    }

    func testFocusTimerActivityAttributesContentState() {
        let target = Date().addingTimeInterval(1500)
        let state = FocusTimerActivityAttributes.ContentState(
            remainingSeconds: 1500,
            totalSeconds: 1500,
            isPaused: false,
            targetDate: target,
            mode: "Focus"
        )
        let attributes = FocusTimerActivityAttributes(sessionTitle: "Deep Work", targetMinutes: 25)

        XCTAssertEqual(attributes.sessionTitle, "Deep Work")
        XCTAssertEqual(attributes.targetMinutes, 25)
        XCTAssertEqual(state.remainingSeconds, 1500)
        XCTAssertFalse(state.isPaused)
        XCTAssertEqual(state.mode, "Focus")
    }
    #endif
}
