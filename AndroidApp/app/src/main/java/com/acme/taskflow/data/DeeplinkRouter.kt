package com.acme.taskflow.data

import android.net.Uri

sealed class DeeplinkTarget {
    data class Task(val id: String) : DeeplinkTarget()
    data class Channel(val id: String) : DeeplinkTarget()
    data class Meeting(val id: String) : DeeplinkTarget()
    data class Call(val id: String) : DeeplinkTarget()
    object Billing : DeeplinkTarget()
    object Inbox : DeeplinkTarget()
    object Productivity : DeeplinkTarget()
}

object DeeplinkParser {
    fun parse(urlStr: String?): DeeplinkTarget? {
        if (urlStr.isNullOrBlank()) return null
        val str = urlStr.trim()
        if (!str.contains("://")) return null
        val scheme = str.substringBefore("://").lowercase()
        if (scheme != "taskflow" && scheme != "https" && scheme != "http") return null

        val remainder = str.substringAfter("://").substringBefore("?").substringBefore("#")
        val segments = remainder.split("/").map { it.trim() }.filter { it.isNotEmpty() }
        val first = segments.firstOrNull()?.lowercase() ?: return null

        return when (first) {
            "tasks", "task" -> segments.getOrNull(1)?.let { DeeplinkTarget.Task(it) }
            "channels", "channel", "messages", "message" -> segments.getOrNull(1)?.let { DeeplinkTarget.Channel(it) }
            "meetings", "meeting" -> segments.getOrNull(1)?.let { DeeplinkTarget.Meeting(it) }
            "calls", "call" -> segments.getOrNull(1)?.let { DeeplinkTarget.Call(it) }
            "billing", "subscriptions", "subscription" -> DeeplinkTarget.Billing
            "inbox", "notifications", "notification" -> DeeplinkTarget.Inbox
            "productivity", "reminders", "reminder" -> DeeplinkTarget.Productivity
            else -> null
        }
    }

    fun parse(uri: Uri?): DeeplinkTarget? {
        if (uri == null) return null
        return parse(uri.toString())
    }

    fun buildUrl(target: DeeplinkTarget): String = when (target) {
        is DeeplinkTarget.Task -> "taskflow://tasks/${target.id}"
        is DeeplinkTarget.Channel -> "taskflow://channels/${target.id}"
        is DeeplinkTarget.Meeting -> "taskflow://meetings/${target.id}"
        is DeeplinkTarget.Call -> "taskflow://calls/${target.id}"
        is DeeplinkTarget.Billing -> "taskflow://billing"
        is DeeplinkTarget.Inbox -> "taskflow://inbox"
        is DeeplinkTarget.Productivity -> "taskflow://productivity"
    }
}
