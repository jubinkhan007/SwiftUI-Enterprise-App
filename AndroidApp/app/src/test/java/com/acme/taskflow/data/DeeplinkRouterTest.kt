package com.acme.taskflow.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class DeeplinkRouterTest {

    @Test
    fun testTaskDeeplinkParsing() {
        val taskId = UUID.randomUUID().toString()
        val target = DeeplinkParser.parse("taskflow://tasks/$taskId")
        assertNotNull(target)
        assertTrue(target is DeeplinkTarget.Task)
        assertEquals(taskId, (target as DeeplinkTarget.Task).id)
    }

    @Test
    fun testChannelDeeplinkParsing() {
        val channelId = UUID.randomUUID().toString()
        val target = DeeplinkParser.parse("taskflow://channels/$channelId")
        assertNotNull(target)
        assertTrue(target is DeeplinkTarget.Channel)
        assertEquals(channelId, (target as DeeplinkTarget.Channel).id)
    }

    @Test
    fun testMeetingDeeplinkParsing() {
        val meetingId = UUID.randomUUID().toString()
        val target = DeeplinkParser.parse("taskflow://meetings/$meetingId")
        assertNotNull(target)
        assertTrue(target is DeeplinkTarget.Meeting)
        assertEquals(meetingId, (target as DeeplinkTarget.Meeting).id)
    }

    @Test
    fun testCallDeeplinkParsing() {
        val callId = UUID.randomUUID().toString()
        val target = DeeplinkParser.parse("taskflow://calls/$callId")
        assertNotNull(target)
        assertTrue(target is DeeplinkTarget.Call)
        assertEquals(callId, (target as DeeplinkTarget.Call).id)
    }

    @Test
    fun testBillingDeeplinkParsing() {
        val target = DeeplinkParser.parse("taskflow://billing")
        assertNotNull(target)
        assertTrue(target is DeeplinkTarget.Billing)
    }

    @Test
    fun testInboxDeeplinkParsing() {
        val target = DeeplinkParser.parse("taskflow://inbox")
        assertNotNull(target)
        assertTrue(target is DeeplinkTarget.Inbox)
    }

    @Test
    fun testProductivityDeeplinkParsing() {
        val target = DeeplinkParser.parse("taskflow://productivity")
        assertNotNull(target)
        assertTrue(target is DeeplinkTarget.Productivity)
    }

    @Test
    fun testBuildUrlParity() {
        val taskId = "task-12345"
        val url = DeeplinkParser.buildUrl(DeeplinkTarget.Task(taskId))
        assertEquals("taskflow://tasks/task-12345", url)

        val billingUrl = DeeplinkParser.buildUrl(DeeplinkTarget.Billing)
        assertEquals("taskflow://billing", billingUrl)
    }
}
