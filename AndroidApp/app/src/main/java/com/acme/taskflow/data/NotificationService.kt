package com.acme.taskflow.data

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.acme.taskflow.MainActivity
import com.acme.taskflow.R
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.collect

/** Keeps user-visible message and incoming-call alerts alive when the UI is backgrounded. */
class NotificationService : Service() {
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var socketJob: Job? = null
    private var pollJob: Job? = null
    private var api: ApiClient? = null
    private var userId = ""
    private var nextNotificationId = 1000
    private val seenNotificationIds = LinkedHashSet<String>()

    override fun onCreate() {
        super.onCreate()
        createChannels()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                SERVICE_NOTIFICATION_ID,
                serviceNotification(),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(SERVICE_NOTIFICATION_ID, serviceNotification())
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val storedSession = SessionStore(this).read()
        val preferences = getSharedPreferences(SERVICE_PREFS, MODE_PRIVATE)
        val server = intent?.getStringExtra(EXTRA_SERVER).orEmpty().ifBlank { storedSession?.text("server").orEmpty() }
        val token = intent?.getStringExtra(EXTRA_TOKEN).orEmpty().ifBlank { storedSession?.text("token").orEmpty() }
        val orgId = intent?.getStringExtra(EXTRA_ORG_ID).orEmpty().ifBlank { preferences.getString(EXTRA_ORG_ID, "").orEmpty() }
        if (server.isNotBlank() && token.isNotBlank() && orgId.isNotBlank()) {
            preferences.edit().putString(EXTRA_ORG_ID, orgId).apply()
            userId = storedSession?.child("user")?.id.orEmpty()
            api = ApiClient(server, token, orgId)
            socketJob?.cancel()
            pollJob?.cancel()
            socketJob = serviceScope.launch { collectEvents(api!!) }
            pollJob = serviceScope.launch { pollNotifications(api!!) }
        }
        return START_STICKY
    }

    private suspend fun collectEvents(client: ApiClient) {
        while (serviceScope.isActive) {
            try {
                client.events().collect { event ->
                    when (event.text("type")) {
                        "message.new" -> {
                            if (event.child("payload").text("senderId") != userId) {
                                showMessageNotification("New message", "You have a new message")
                            }
                        }
                    }
                }
            } catch (_: CancellationException) {
                throw CancellationException()
            } catch (_: Exception) {
                delay(3000)
            }
        }
    }

    private suspend fun pollNotifications(client: ApiClient) {
        var initialized = false
        while (serviceScope.isActive) {
            try {
                val rows = client.request(
                    "/api/notifications",
                    query = mapOf("unread" to "true", "per_page" to "50")
                ).data.rows()
                val incoming = rows.filter { it.id.isNotBlank() && it.id !in seenNotificationIds }
                if (initialized) incoming.forEach { notification ->
                    val type = notification.text("type")
                    val payload = runCatching { com.google.gson.JsonParser.parseString(notification.text("payload_json")).obj() }.getOrDefault(com.google.gson.JsonObject())
                    when {
                        type == "call.incoming" -> {
                            val caller = payload.text("actorName")
                            showCallNotification(
                                "Incoming call",
                                notification.text("body").ifBlank {
                                    if (caller.isBlank()) "Someone is calling you" else "$caller is calling you"
                                }
                            )
                        }
                        type.startsWith("message") -> showMessageNotification(
                            notification.text("title", "New message"),
                            notification.text("body").ifBlank { payload.text("message", "You have a new message") }
                        )
                    }
                }
                rows.map { it.id }.filter { it.isNotBlank() }.forEach { seenNotificationIds.add(it) }
                while (seenNotificationIds.size > 200) seenNotificationIds.remove(seenNotificationIds.first())
                initialized = true
            } catch (_: CancellationException) {
                throw CancellationException()
            } catch (_: Exception) {
                // Reconnect/poll on the next interval; the UI remains independent.
            }
            delay(5000)
        }
    }

    private fun showMessageNotification(title: String, body: String) = showNotification(
        channel = CHANNEL_MESSAGES,
        title = title,
        body = body,
        priority = NotificationCompat.PRIORITY_DEFAULT
    )

    private fun showCallNotification(title: String, body: String) = showNotification(
        channel = CHANNEL_CALLS,
        title = title,
        body = body,
        priority = NotificationCompat.PRIORITY_HIGH
    )

    private fun showNotification(channel: String, title: String, body: String, priority: Int) {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) return
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            nextNotificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, channel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(priority)
            .build()
        NotificationManagerCompat.from(this).notify(nextNotificationId++, notification)
    }

    private fun serviceNotification(): Notification = NotificationCompat.Builder(this, CHANNEL_SERVICE)
        .setSmallIcon(R.mipmap.ic_launcher)
        .setContentTitle(getString(R.string.app_name))
        .setContentText("Notifications are active")
        .setOngoing(true)
        .setPriority(NotificationCompat.PRIORITY_MIN)
        .build()

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(CHANNEL_SERVICE, "Connection", NotificationManager.IMPORTANCE_MIN))
        manager.createNotificationChannel(NotificationChannel(CHANNEL_MESSAGES, "Messages", NotificationManager.IMPORTANCE_DEFAULT))
        manager.createNotificationChannel(NotificationChannel(CHANNEL_CALLS, "Calls", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Incoming voice and video calls"
        })
    }

    override fun onDestroy() {
        socketJob?.cancel()
        pollJob?.cancel()
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val SERVICE_NOTIFICATION_ID = 9
        private const val CHANNEL_SERVICE = "taskflow_connection"
        private const val CHANNEL_MESSAGES = "taskflow_messages"
        private const val CHANNEL_CALLS = "taskflow_calls"
        private const val EXTRA_SERVER = "server"
        private const val EXTRA_TOKEN = "token"
        private const val EXTRA_ORG_ID = "org_id"
        private const val SERVICE_PREFS = "notification_service"

        fun start(context: Context, server: String, token: String, orgId: String) {
            val intent = Intent(context, NotificationService::class.java).apply {
                putExtra(EXTRA_SERVER, server)
                putExtra(EXTRA_TOKEN, token)
                putExtra(EXTRA_ORG_ID, orgId)
            }
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, NotificationService::class.java))
        }
    }
}
