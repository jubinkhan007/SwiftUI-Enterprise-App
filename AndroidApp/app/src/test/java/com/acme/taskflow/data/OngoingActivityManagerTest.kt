package com.acme.taskflow.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class OngoingActivityManagerTest {

    @Test
    fun testChannelAndNotificationConstants() {
        assertEquals("channel_calls_ongoing", OngoingActivityManager.CHANNEL_CALLS_ONGOING)
        assertEquals("channel_focus_ongoing", OngoingActivityManager.CHANNEL_FOCUS_ONGOING)

        assertEquals(9001, OngoingActivityManager.NOTIFICATION_ID_CALL)
        assertEquals(9002, OngoingActivityManager.NOTIFICATION_ID_MEETING)
        assertEquals(9003, OngoingActivityManager.NOTIFICATION_ID_FOCUS)
    }

    @Test
    fun testIntentActionConstants() {
        assertEquals("com.acme.taskflow.ACTION_HANG_UP_CALL", OngoingActivityManager.ACTION_HANG_UP_CALL)
        assertEquals("com.acme.taskflow.ACTION_LEAVE_MEETING", OngoingActivityManager.ACTION_LEAVE_MEETING)
        assertEquals("com.acme.taskflow.ACTION_TOGGLE_FOCUS", OngoingActivityManager.ACTION_TOGGLE_FOCUS)
        assertEquals("com.acme.taskflow.ACTION_STOP_FOCUS", OngoingActivityManager.ACTION_STOP_FOCUS)
    }

    @Test
    fun testOngoingDeeplinkCompatibilityWithRouter() {
        val callLink = "taskflow://calls/call-123"
        val callTarget = DeeplinkParser.parse(callLink)
        assertNotNull(callTarget)
        assertEquals(DeeplinkTarget.Call("call-123"), callTarget)

        val meetingLink = "taskflow://meetings/meet-456"
        val meetingTarget = DeeplinkParser.parse(meetingLink)
        assertNotNull(meetingTarget)
        assertEquals(DeeplinkTarget.Meeting("meet-456"), meetingTarget)

        val focusLink = "taskflow://productivity"
        val focusTarget = DeeplinkParser.parse(focusLink)
        assertNotNull(focusTarget)
        assertEquals(DeeplinkTarget.Productivity, focusTarget)
    }
}
