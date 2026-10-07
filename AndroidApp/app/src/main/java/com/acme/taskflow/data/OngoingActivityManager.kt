package com.acme.taskflow.data

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.acme.taskflow.MainActivity
import com.acme.taskflow.R

/**
 * Manages sticky ongoing rich system notifications for active Calls,
 * in-progress Meetings, and Focus/Pomodoro timers with live chronometers.
 */
object OngoingActivityManager {
    const val CHANNEL_CALLS_ONGOING = "channel_calls_ongoing"
    const val CHANNEL_FOCUS_ONGOING = "channel_focus_ongoing"

    const val NOTIFICATION_ID_CALL = 9001
    const val NOTIFICATION_ID_MEETING = 9002
    const val NOTIFICATION_ID_FOCUS = 9003

    const val ACTION_HANG_UP_CALL = "com.acme.taskflow.ACTION_HANG_UP_CALL"
    const val ACTION_LEAVE_MEETING = "com.acme.taskflow.ACTION_LEAVE_MEETING"
    const val ACTION_TOGGLE_FOCUS = "com.acme.taskflow.ACTION_TOGGLE_FOCUS"
    const val ACTION_STOP_FOCUS = "com.acme.taskflow.ACTION_STOP_FOCUS"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return

        if (manager.getNotificationChannel(CHANNEL_CALLS_ONGOING) == null) {
            val callChannel = NotificationChannel(
                CHANNEL_CALLS_ONGOING,
                "Active Calls & Meetings",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live ongoing call and meeting duration and quick actions."
                setShowBadge(false)
            }
            manager.createNotificationChannel(callChannel)
        }

        if (manager.getNotificationChannel(CHANNEL_FOCUS_ONGOING) == null) {
            val focusChannel = NotificationChannel(
                CHANNEL_FOCUS_ONGOING,
                "Focus & Deep Work",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows active countdown timers for focus sessions."
                setShowBadge(false)
            }
            manager.createNotificationChannel(focusChannel)
        }
    }

    // MARK: - Active Call Ongoing Notification

    fun showCallOngoingNotification(
        context: Context,
        callId: String,
        title: String,
        remoteCount: Int = 1,
        isMuted: Boolean = false,
        startTimeMillis: Long = System.currentTimeMillis()
    ) {
        ensureChannels(context)
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) return

        val deepLink = "taskflow://calls/$callId"
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            data = android.net.Uri.parse(deepLink)
            putExtra("deep_link", deepLink)
            putExtra("EXTRA_DEEPLINK", deepLink)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID_CALL,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val hangUpIntent = Intent(ACTION_HANG_UP_CALL).apply {
            putExtra("callId", callId)
        }
        val hangUpPendingIntent = PendingIntent.getBroadcast(
            context,
            NOTIFICATION_ID_CALL + 10,
            hangUpIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val subText = if (isMuted) "Mic Muted • ${remoteCount + 1} on call" else "Mic Live • ${remoteCount + 1} on call"

        val notification = NotificationCompat.Builder(context, CHANNEL_CALLS_ONGOING)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title.ifBlank { "Active Call" })
            .setContentText(subText)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setUsesChronometer(true)
            .setWhen(startTimeMillis)
            .setContentIntent(openPendingIntent)
            .addAction(0, "Return to Call", openPendingIntent)
            .addAction(0, "Hang Up", hangUpPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID_CALL, notification)
    }

    fun hideCallNotification(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID_CALL)
    }

    // MARK: - Active Meeting Ongoing Notification

    fun showMeetingOngoingNotification(
        context: Context,
        meetingId: String,
        title: String,
        participantCount: Int = 1,
        isMuted: Boolean = false,
        startTimeMillis: Long = System.currentTimeMillis()
    ) {
        ensureChannels(context)
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) return

        val deepLink = "taskflow://meetings/$meetingId"
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            data = android.net.Uri.parse(deepLink)
            putExtra("deep_link", deepLink)
            putExtra("EXTRA_DEEPLINK", deepLink)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID_MEETING,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val leaveIntent = Intent(ACTION_LEAVE_MEETING).apply {
            putExtra("meetingId", meetingId)
        }
        val leavePendingIntent = PendingIntent.getBroadcast(
            context,
            NOTIFICATION_ID_MEETING + 10,
            leaveIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val subText = if (isMuted) "Mic Muted • $participantCount participants" else "Mic Live • $participantCount participants"

        val notification = NotificationCompat.Builder(context, CHANNEL_CALLS_ONGOING)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title.ifBlank { "In Meeting Room" })
            .setContentText(subText)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setUsesChronometer(true)
            .setWhen(startTimeMillis)
            .setContentIntent(openPendingIntent)
            .addAction(0, "Open Meeting", openPendingIntent)
            .addAction(0, "Leave", leavePendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID_MEETING, notification)
    }

    fun hideMeetingNotification(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID_MEETING)
    }

    // MARK: - Focus Timer Ongoing Notification

    fun showFocusOngoingNotification(
        context: Context,
        sessionTitle: String,
        remainingMillis: Long,
        totalMinutes: Int,
        isPaused: Boolean = false
    ) {
        ensureChannels(context)
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) return

        val deepLink = "taskflow://productivity"
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            data = android.net.Uri.parse(deepLink)
            putExtra("deep_link", deepLink)
            putExtra("EXTRA_DEEPLINK", deepLink)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID_FOCUS,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val toggleIntent = Intent(ACTION_TOGGLE_FOCUS)
        val togglePendingIntent = PendingIntent.getBroadcast(
            context,
            NOTIFICATION_ID_FOCUS + 10,
            toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(ACTION_STOP_FOCUS)
        val stopPendingIntent = PendingIntent.getBroadcast(
            context,
            NOTIFICATION_ID_FOCUS + 20,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val minsLeft = remainingMillis / 60000
        val subText = if (isPaused) "Paused • ${minsLeft}m remaining" else "Deep Work Focus • ${minsLeft}m left (${totalMinutes}m goal)"

        val builder = NotificationCompat.Builder(context, CHANNEL_FOCUS_ONGOING)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(sessionTitle.ifBlank { "Focus Session" })
            .setContentText(subText)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setContentIntent(openPendingIntent)
            .addAction(0, if (isPaused) "Resume" else "Pause", togglePendingIntent)
            .addAction(0, "Stop", stopPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        if (!isPaused) {
            builder.setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                builder.setChronometerCountDown(true)
            }
            builder.setWhen(System.currentTimeMillis() + remainingMillis)
        }

        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID_FOCUS, builder.build())
    }

    fun hideFocusNotification(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID_FOCUS)
    }
}
