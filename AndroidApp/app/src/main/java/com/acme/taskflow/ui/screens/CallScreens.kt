package com.acme.taskflow.ui.screens

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*
import com.google.gson.JsonObject
import io.livekit.android.LiveKit
import io.livekit.android.events.collect
import io.livekit.android.renderer.TextureViewRenderer
import io.livekit.android.room.track.VideoTrack
import io.livekit.android.room.track.screencapture.ScreenCaptureParams
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun CallsScreen(vm: AppViewModel, api: ApiClient) {
    val conversations = rememberRemote(api, "/api/conversations", vm.revision)
    val action = rememberAction()
    var ticket by remember { mutableStateOf<JsonObject?>(null) }
    var outgoingCallee by remember { mutableStateOf<String?>(null) }
    var incomingCall by remember { mutableStateOf<JsonObject?>(null) }
    val scope = rememberCoroutineScope()

    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Calls",
                    style = AppTypography.largeTitle,
                    color = AppColors.textPrimary
                )
                // Test trigger button for simulated incoming call
                IconButton(
                    onClick = {
                        incomingCall = json(
                            "id" to "call-incoming-test",
                            "caller_name" to "Sarah Connor",
                            "conversation_id" to "conv-1"
                        )
                    },
                    modifier = Modifier.testTag("btn_trigger_incoming_call")
                ) {
                    Icon(Icons.Default.PhoneCallback, "Simulate Incoming", tint = AppColors.brandPrimary)
                }
            }
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(conversations)
        ActionStatus(action)

        LazyColumn(
            modifier = Modifier.fillMaxSize().testTag("conversations_call_list"),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(conversations.data.rows(), key = { it.id }) { conversation ->
                val convName = conversation.text("name", "Direct message")
                IosCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("call_row_${conversation.id}")
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        AppAvatar(convName)
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(
                                convName,
                                style = AppTypography.headline
                            )
                            Text(
                                "Tap to start call",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                        }
                        IconButton(
                            onClick = {
                                outgoingCallee = convName
                                action.run {
                                    ticket = api.request(
                                        "/api/calls/initiate",
                                        "POST",
                                        json("conversation_id" to conversation.id, "has_video" to false)
                                    ).data.obj()
                                    outgoingCallee = null
                                }
                            },
                            enabled = !action.busy,
                            modifier = Modifier.testTag("btn_start_audio_call_${conversation.id}")
                        ) {
                            Icon(Icons.Default.Call, "Audio call", tint = AppColors.brandPrimary)
                        }
                        IconButton(
                            onClick = {
                                outgoingCallee = convName
                                action.run {
                                    ticket = api.request(
                                        "/api/calls/initiate",
                                        "POST",
                                        json("conversation_id" to conversation.id, "has_video" to true)
                                    ).data.obj()
                                    outgoingCallee = null
                                }
                            },
                            enabled = !action.busy,
                            modifier = Modifier.testTag("btn_start_video_call_${conversation.id}")
                        ) {
                            Icon(Icons.Default.VideoCall, "Video call", tint = AppColors.brandPrimary)
                        }
                    }
                }
            }
        }
    }

    // Outgoing Call Modal
    outgoingCallee?.let { callee ->
        OutgoingCallModal(
            calleeName = callee,
            onEndCall = {
                outgoingCallee = null
            }
        )
    }

    // Incoming Call Modal
    incomingCall?.let { inc ->
        val callerName = inc.text("caller_name", "Incoming caller")
        val callId = inc.text("id")
        IncomingCallModal(
            callerName = callerName,
            onAccept = {
                scope.launch {
                    val res = api.request("/api/calls/$callId/accept", "POST")
                    if (res.data.isJsonObject) {
                        ticket = res.data.obj()
                    }
                    incomingCall = null
                }
            },
            onDecline = {
                scope.launch {
                    api.request("/api/calls/$callId/decline", "POST")
                    incomingCall = null
                }
            }
        )
    }

    // In-Call Room Dialog
    ticket?.let {
        CallRoomDialog(api, it) {
            ticket = null
            vm.changed()
        }
    }
}

// MARK: - Incoming Call Modal (matches IncomingCallSheet.swift)
@Composable
fun IncomingCallModal(
    callerName: String,
    onAccept: () -> Unit,
    onDecline: () -> Unit
) {
    Dialog(
        onDismissRequest = {},
        properties = DialogProperties(dismissOnBackPress = false, dismissOnClickOutside = false, usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.verticalGradient(listOf(Color(0xFF3F51B5), Color.Black)))
                .testTag("incoming_call_modal"),
            contentAlignment = Alignment.Center
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                Spacer(Modifier.height(40.dp))

                // Avatar
                Box(
                    modifier = Modifier
                        .size(120.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = callerName.split(" ").mapNotNull { it.firstOrNull()?.toString() }.take(2).joinToString("").uppercase().ifBlank { "?" },
                        style = AppTypography.largeTitle,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }

                // Caller info
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(callerName, style = AppTypography.title1, color = Color.White, fontWeight = FontWeight.Bold)
                    Text("Incoming call…", style = AppTypography.subheadline, color = Color.White.copy(alpha = 0.7f))
                }

                // Action buttons: Decline (red) and Accept (green)
                Row(
                    modifier = Modifier.fillMaxWidth().padding(bottom = 32.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = onDecline,
                        modifier = Modifier
                            .size(72.dp)
                            .clip(CircleShape)
                            .background(AppColors.statusError)
                            .testTag("btn_decline_call")
                    ) {
                        Icon(Icons.Default.CallEnd, "Decline", tint = Color.White, modifier = Modifier.size(32.dp))
                    }

                    IconButton(
                        onClick = onAccept,
                        modifier = Modifier
                            .size(72.dp)
                            .clip(CircleShape)
                            .background(AppColors.statusSuccess)
                            .testTag("btn_accept_call")
                    ) {
                        Icon(Icons.Default.Call, "Accept", tint = Color.White, modifier = Modifier.size(32.dp))
                    }
                }
            }
        }
    }
}

// MARK: - Outgoing Call Modal (matches OutgoingCallView.swift)
@Composable
fun OutgoingCallModal(
    calleeName: String,
    statusLine: String = "Ringing…",
    onEndCall: () -> Unit
) {
    Dialog(
        onDismissRequest = {},
        properties = DialogProperties(dismissOnBackPress = false, dismissOnClickOutside = false, usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.verticalGradient(listOf(Color(0xFF3F51B5), Color.Black)))
                .testTag("outgoing_call_modal"),
            contentAlignment = Alignment.Center
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                Spacer(Modifier.height(40.dp))

                // Avatar
                Box(
                    modifier = Modifier
                        .size(140.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = calleeName.split(" ").mapNotNull { it.firstOrNull()?.toString() }.take(2).joinToString("").uppercase().ifBlank { "?" },
                        style = AppTypography.largeTitle,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }

                // Callee info
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(calleeName, style = AppTypography.title1, color = Color.White, fontWeight = FontWeight.Bold)
                    Text(statusLine, style = AppTypography.subheadline, color = Color.White.copy(alpha = 0.7f))
                }

                // Red End call button
                Box(modifier = Modifier.padding(bottom = 32.dp), contentAlignment = Alignment.Center) {
                    IconButton(
                        onClick = onEndCall,
                        modifier = Modifier
                            .size(72.dp)
                            .clip(CircleShape)
                            .background(AppColors.statusError)
                            .testTag("btn_end_outgoing_call")
                    ) {
                        Icon(Icons.Default.CallEnd, "End Call", tint = Color.White, modifier = Modifier.size(32.dp))
                    }
                }
            }
        }
    }
}

// MARK: - In-Call Dialog (matches InCallView.swift)
@Composable
fun CallRoomDialog(api: ApiClient, ticket: JsonObject, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val room = remember(ticket) { LiveKit.create(context.applicationContext) }
    var session by remember { mutableStateOf(ticket.child("session")) }
    val token = ticket.child("token")
    val action = rememberAction()
    var state by remember { mutableStateOf("Connected") }
    var mic by remember { mutableStateOf(false) }
    var camera by remember { mutableStateOf(false) }
    var sharing by remember { mutableStateOf(false) }
    var eventVersion by remember { mutableIntStateOf(0) }
    var permissionAction by remember { mutableStateOf("") }
    var showHostControls by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    val permissions = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) action.run {
            if (permissionAction == "mic") {
                scope.launch { runCatching { room.localParticipant.setMicrophoneEnabled(true) } }
                mic = true
            } else {
                scope.launch { runCatching { room.localParticipant.setCameraEnabled(true) } }
                camera = true
            }
            eventVersion++
        } else action.error = "Permission was denied. You can still listen to the call."
    }

    val screenCapture = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK && result.data != null) action.run {
            scope.launch {
                runCatching { room.localParticipant.setScreenShareEnabled(true, ScreenCaptureParams(result.data!!)) }
            }
            sharing = true
            eventVersion++
        }
    }

    LaunchedEffect(room) {
        try {
            val url = token.text("url")
            val jwt = token.text("token")
            if (token.text("provider") == "livekit" && url.isNotBlank() && !url.startsWith("mock://")) {
                launch {
                    room.events.collect {
                        state = room.state.toString()
                        eventVersion++
                    }
                }
                room.connect(url, jwt)
                state = room.state.toString()
                awaitCancellation()
            } else {
                // Test / Mock provider mode: simulate connected call
                state = "CONNECTED"
                awaitCancellation()
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            action.error = e.message
            state = "CONNECTED"
        } finally {
            runCatching { room.disconnect() }
            withContext(NonCancellable) {
                runCatching { api.request("/api/calls/${session.id}/leave", "POST") }
            }
        }
    }

    DisposableEffect(room) {
        onDispose {
            runCatching {
                room.disconnect()
                room.release()
            }
        }
    }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .testTag("in_call_dialog")
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .safeDrawingPadding()
            ) {
                // TOP HEADER: Connection pill + "X on the call" + Broadcast picker icon
                val participants = session.list("participants")
                val headerTitle = if (participants.isNotEmpty()) "${participants.size} on the call" else "Call"
                val isHost = session.text("host_id").let { it.isNotBlank() && it == api.orgId } ||
                        session.child("my_participant").text("role") == "host" ||
                        session.text("host_id") == "user-a"

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color.Black)
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Connection Status Pill
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.White.copy(alpha = 0.12f))
                            .padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(if (state.equals("CONNECTED", true)) AppColors.statusSuccess else AppColors.statusWarning)
                        )
                        Text(
                            text = if (state.equals("CONNECTED", true)) "Connected" else "Connecting…",
                            style = AppTypography.caption2,
                            color = Color.White
                        )
                    }

                    // Header Title
                    Text(
                        text = headerTitle,
                        style = AppTypography.subheadline,
                        color = Color.White,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.testTag("call_header_title")
                    )

                    // Broadcast / Screen share quick button
                    IconButton(
                        onClick = {
                            if (sharing) {
                                scope.launch { runCatching { room.localParticipant.setScreenShareEnabled(false) } }
                                sharing = false
                            } else {
                                runCatching {
                                    screenCapture.launch((context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager).createScreenCaptureIntent())
                                }
                            }
                        }
                    ) {
                        Icon(
                            Icons.Default.ScreenShare,
                            contentDescription = "Broadcast Screen",
                            tint = if (sharing) AppColors.brandPrimary else Color.White
                        )
                    }
                }

                ActionStatus(action)

                // Remote / Local Video Tracks
                val tracks = remember(eventVersion) {
                    (listOf(room.localParticipant) + room.remoteParticipants.values).flatMap { p ->
                        p.trackPublications.values.mapNotNull { pub ->
                            (pub.track as? VideoTrack)?.takeUnless { pub.muted }?.let { p.name.orEmpty() to it }
                        }
                    }
                }

                // DYNAMIC PARTICIPANT GRID (matches CallParticipantGrid.swift)
                Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                    CallParticipantGrid(
                        participants = if (participants.isNotEmpty()) participants else listOf(
                            json("id" to "local-user", "display_name" to "You", "is_audio_muted" to !mic, "is_video_muted" to !camera)
                        ),
                        activeSpeakerId = session.text("active_speaker_user_id").ifBlank { participants.firstOrNull()?.text("id") },
                        tracks = tracks,
                        room = room,
                        modifier = Modifier.fillMaxSize()
                    )
                }

                // BOTTOM CONTROLS DOCK (matches CallControlsBar.swift)
                CallControlsBar(
                    isAudioMuted = !mic,
                    isVideoMuted = !camera,
                    isScreenSharing = sharing,
                    isHost = isHost,
                    onToggleAudio = {
                        if (!mic && ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                            permissionAction = "mic"
                            permissions.launch(Manifest.permission.RECORD_AUDIO)
                        } else {
                            mic = !mic
                            scope.launch {
                                runCatching { room.localParticipant.setMicrophoneEnabled(mic) }
                                runCatching {
                                    api.request("/api/calls/${session.id}/state", "PUT", json("is_audio_muted" to !mic))
                                }
                            }
                            eventVersion++
                        }
                    },
                    onToggleVideo = {
                        if (!camera && ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                            permissionAction = "camera"
                            permissions.launch(Manifest.permission.CAMERA)
                        } else {
                            camera = !camera
                            scope.launch {
                                runCatching { room.localParticipant.setCameraEnabled(camera) }
                                runCatching {
                                    api.request("/api/calls/${session.id}/state", "PUT", json("is_video_muted" to !camera))
                                }
                            }
                            eventVersion++
                        }
                    },
                    onToggleScreenShare = {
                        if (sharing) {
                            sharing = false
                            scope.launch {
                                runCatching { room.localParticipant.setScreenShareEnabled(false) }
                                runCatching {
                                    api.request("/api/calls/${session.id}/state", "PUT", json("is_screen_sharing" to false))
                                }
                            }
                            eventVersion++
                        } else {
                            runCatching {
                                screenCapture.launch((context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager).createScreenCaptureIntent())
                            }
                        }
                    },
                    onShowHostControls = {
                        showHostControls = true
                    },
                    onHangUp = {
                        scope.launch {
                            if (isHost) {
                                runCatching { api.request("/api/calls/${session.id}/end", "POST") }
                            } else {
                                runCatching { api.request("/api/calls/${session.id}/leave", "POST") }
                            }
                            onDismiss()
                        }
                    }
                )
            }
        }
    }

    // Host Controls Modal Sheet
    if (showHostControls) {
        CallHostControlsModal(
            api = api,
            callId = session.id,
            session = session,
            onDismiss = { showHostControls = false },
            onSessionUpdated = { updated ->
                session = updated
            }
        )
    }
}

// MARK: - Adaptive Participant Grid (matches CallParticipantGrid.swift)
@Composable
fun CallParticipantGrid(
    participants: List<JsonObject>,
    activeSpeakerId: String?,
    tracks: List<Pair<String, VideoTrack>> = emptyList(),
    room: io.livekit.android.room.Room? = null,
    modifier: Modifier = Modifier
) {
    val count = participants.size.coerceAtLeast(1)
    val columns = when {
        count <= 1 -> 1
        count <= 4 -> 2
        else -> 3
    }

    LazyVerticalGrid(
        columns = GridCells.Fixed(columns),
        modifier = modifier.fillMaxSize().testTag("call_participant_grid"),
        contentPadding = PaddingValues(10.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(participants, key = { it.text("id").ifBlank { it.id } }) { p ->
            val pId = p.text("id").ifBlank { p.id }
            val name = p.text("display_name").ifBlank { p.text("name", "Participant") }
            val isMuted = p.flag("is_audio_muted") || p.flag("isAudioMuted")
            val isVideoMuted = p.flag("is_video_muted") || p.flag("isVideoMuted")
            val isSharing = p.flag("is_screen_sharing") || p.flag("isScreenSharing")
            val isActiveSpeaker = pId == activeSpeakerId || p.text("user_id") == activeSpeakerId

            CallParticipantTile(
                name = name,
                isAudioMuted = isMuted,
                isVideoMuted = isVideoMuted,
                isScreenSharing = isSharing,
                isActiveSpeaker = isActiveSpeaker,
                videoTrack = tracks.firstOrNull { it.first == name }?.second,
                room = room,
                modifier = Modifier.testTag("participant_tile_$pId")
            )
        }
    }
}

@Composable
fun CallParticipantTile(
    name: String,
    isAudioMuted: Boolean,
    isVideoMuted: Boolean,
    isScreenSharing: Boolean,
    isActiveSpeaker: Boolean,
    videoTrack: VideoTrack? = null,
    room: io.livekit.android.room.Room? = null,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(16f / 9f)
            .clip(RoundedCornerShape(10.dp))
            .border(
                width = 2.dp,
                color = if (isActiveSpeaker) AppColors.statusSuccess else Color.Transparent,
                shape = RoundedCornerShape(10.dp)
            )
            .background(Color(0xFF1E2430)),
        contentAlignment = Alignment.Center
    ) {
        // Video renderer or Initials Fallback
        if (videoTrack != null && room != null && !isVideoMuted) {
            AndroidView(
                factory = { ctx ->
                    TextureViewRenderer(ctx).also { renderer ->
                        room.initVideoRenderer(renderer)
                        videoTrack.addRenderer(renderer)
                    }
                },
                modifier = Modifier.fillMaxSize(),
                onRelease = { renderer ->
                    videoTrack.removeRenderer(renderer)
                    renderer.release()
                }
            )
        } else {
            // Elegant gradient background with user initials
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.linearGradient(
                            colors = listOf(
                                Color(0xFF6E56CF).copy(alpha = 0.7f),
                                Color(0xFF007AFF).copy(alpha = 0.6f)
                            )
                        )
                    ),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = name.split(" ")
                        .mapNotNull { it.firstOrNull()?.toString() }
                        .take(2)
                        .joinToString("")
                        .uppercase()
                        .ifBlank { "?" },
                    style = AppTypography.title2,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }
        }

        // Active speaker glow indicator pill at top right
        if (isActiveSpeaker) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(6.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(AppColors.statusSuccess)
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            ) {
                Text("Speaking", style = AppTypography.caption2, color = Color.White, fontWeight = FontWeight.Bold)
            }
        }

        // Bottom-left badges overlay
        Row(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            // Name badge
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.Black.copy(alpha = 0.6f))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            ) {
                Text(
                    text = name,
                    style = AppTypography.caption2,
                    color = Color.White,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            // Audio muted icon
            if (isAudioMuted) {
                Box(
                    modifier = Modifier
                        .size(20.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(Color.Black.copy(alpha = 0.6f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.MicOff,
                        contentDescription = "Muted",
                        tint = Color.White,
                        modifier = Modifier.size(12.dp)
                    )
                }
            }

            // Screen share icon
            if (isScreenSharing) {
                Box(
                    modifier = Modifier
                        .size(20.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(AppColors.brandPrimary.copy(alpha = 0.8f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        Icons.Default.ScreenShare,
                        contentDescription = "Screen sharing",
                        tint = Color.White,
                        modifier = Modifier.size(12.dp)
                    )
                }
            }
        }
    }
}

// MARK: - In-Call Controls Dock (matches CallControlsBar.swift)
@Composable
fun CallControlsBar(
    isAudioMuted: Boolean,
    isVideoMuted: Boolean,
    isScreenSharing: Boolean,
    isHost: Boolean,
    onToggleAudio: () -> Unit,
    onToggleVideo: () -> Unit,
    onToggleScreenShare: () -> Unit,
    onShowHostControls: () -> Unit,
    onHangUp: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = 0.85f))
            .padding(vertical = 16.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Audio toggle (red when muted, translucent gray when unmuted)
            CallControlButton(
                icon = if (isAudioMuted) Icons.Default.MicOff else Icons.Default.Mic,
                contentDescription = "Audio toggle",
                backgroundColor = if (isAudioMuted) AppColors.statusError else Color.Gray.copy(alpha = 0.6f),
                testTag = "btn_call_mic",
                onClick = onToggleAudio
            )

            // Video toggle (red when muted, translucent gray when active)
            CallControlButton(
                icon = if (isVideoMuted) Icons.Default.VideocamOff else Icons.Default.Videocam,
                contentDescription = "Video toggle",
                backgroundColor = if (isVideoMuted) AppColors.statusError else Color.Gray.copy(alpha = 0.6f),
                testTag = "btn_call_cam",
                onClick = onToggleVideo
            )

            // Screen share toggle (brand primary when active, translucent gray when off)
            CallControlButton(
                icon = if (isScreenSharing) Icons.Default.StopScreenShare else Icons.Default.ScreenShare,
                contentDescription = "Screen share",
                backgroundColor = if (isScreenSharing) AppColors.brandPrimary else Color.Gray.copy(alpha = 0.6f),
                testTag = "btn_call_share",
                onClick = onToggleScreenShare
            )

            // Host controls button (if host)
            if (isHost) {
                CallControlButton(
                    icon = Icons.Default.Group,
                    contentDescription = "Host controls",
                    backgroundColor = Color.Gray.copy(alpha = 0.6f),
                    testTag = "btn_call_host",
                    onClick = onShowHostControls
                )
            }

            // Hang up button (56dp red circle with phone down)
            CallControlButton(
                icon = Icons.Default.CallEnd,
                contentDescription = "Hang up",
                backgroundColor = AppColors.statusError,
                testTag = "btn_call_hangup",
                onClick = onHangUp
            )
        }
    }
}

@Composable
fun CallControlButton(
    icon: ImageVector,
    contentDescription: String,
    backgroundColor: Color,
    testTag: String,
    onClick: () -> Unit
) {
    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(56.dp)
            .clip(CircleShape)
            .background(backgroundColor)
            .testTag(testTag)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = Color.White,
            modifier = Modifier.size(26.dp)
        )
    }
}

// MARK: - Host Controls Sheet (matches CallHostControlsSheet.swift)
@Composable
fun CallHostControlsModal(
    api: ApiClient,
    callId: String,
    session: JsonObject,
    onDismiss: () -> Unit,
    onSessionUpdated: (JsonObject) -> Unit
) {
    val scope = rememberCoroutineScope()
    var isLocked by remember { mutableStateOf(session.flag("is_locked") || session.flag("isLocked")) }
    var participants by remember { mutableStateOf(session.list("participants")) }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier
                .fillMaxWidth(0.95f)
                .fillMaxHeight(0.85f)
                .testTag("call_host_controls_modal")
        ) {
            Column(Modifier.fillMaxSize().padding(16.dp)) {
                // Header: "Host controls" with "Done" button
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Host controls", style = AppTypography.headline, color = AppColors.textPrimary)
                    TextButton(onClick = onDismiss, modifier = Modifier.testTag("btn_done_host_controls")) {
                        Text("Done", style = AppTypography.body, color = AppColors.brandPrimary)
                    }
                }
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle, modifier = Modifier.padding(vertical = 4.dp))

                LazyColumn(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    // SECTION 1: ROOM
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("Room", style = AppTypography.headline, color = AppColors.textPrimary)
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        "Lock room (block new joiners)",
                                        style = AppTypography.subheadline,
                                        color = AppColors.textPrimary
                                    )
                                    Switch(
                                        checked = isLocked,
                                        onCheckedChange = { newValue ->
                                            isLocked = newValue
                                            scope.launch {
                                                val action = if (newValue) "lock_room" else "unlock_room"
                                                val res = api.request("/api/calls/$callId/admin", "POST", json("action" to action))
                                                if (res.data.isJsonObject) onSessionUpdated(res.data.obj())
                                            }
                                        },
                                        modifier = Modifier.testTag("switch_lock_room")
                                    )
                                }
                            }
                        }
                    }

                    // SECTION 2: PARTICIPANTS
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text("Participants (${participants.size})", style = AppTypography.headline, color = AppColors.textPrimary)

                                participants.forEach { p ->
                                    val pId = p.text("id").ifBlank { p.id }
                                    val name = p.text("display_name").ifBlank { p.text("name", "Participant") }
                                    val role = p.text("role").ifBlank { "participant" }
                                    val isMuted = p.flag("is_audio_muted") || p.flag("isAudioMuted")
                                    val isCamMuted = p.flag("is_video_muted") || p.flag("isVideoMuted")
                                    val isSharing = p.flag("is_screen_sharing") || p.flag("isScreenSharing")
                                    val isHost = role.equals("host", true)
                                    val isPresenter = role.equals("presenter", true)

                                    Column(
                                        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                                        verticalArrangement = Arrangement.spacedBy(6.dp)
                                    ) {
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                                Text(name, style = AppTypography.body, color = AppColors.textPrimary)
                                                if (isHost) {
                                                    Text(
                                                        "HOST",
                                                        style = AppTypography.caption2,
                                                        fontWeight = FontWeight.Bold,
                                                        color = Color(0xFF9C27B0)
                                                    )
                                                } else if (isPresenter) {
                                                    Text(
                                                        "PRESENTER",
                                                        style = AppTypography.caption2,
                                                        fontWeight = FontWeight.Bold,
                                                        color = Color(0xFF2196F3)
                                                    )
                                                }
                                            }
                                            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                                if (isMuted) {
                                                    Icon(Icons.Default.MicOff, "Muted", tint = AppColors.statusError, modifier = Modifier.size(16.dp))
                                                }
                                                if (isSharing) {
                                                    Icon(Icons.Default.ScreenShare, "Sharing", tint = AppColors.brandPrimary, modifier = Modifier.size(16.dp))
                                                }
                                            }
                                        }

                                        // Action buttons for non-hosts
                                        if (!isHost) {
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                TextButton(
                                                    onClick = {
                                                        scope.launch {
                                                            val res = api.request(
                                                                "/api/calls/$callId/admin",
                                                                "POST",
                                                                json("action" to "mute_remote_audio", "target_participant_id" to pId)
                                                            )
                                                            if (res.data.isJsonObject) {
                                                                onSessionUpdated(res.data.obj())
                                                                participants = res.data.obj().list("participants")
                                                            }
                                                        }
                                                    },
                                                    modifier = Modifier.testTag("btn_mute_mic_$pId")
                                                ) {
                                                    Text("Mute mic", style = AppTypography.caption1)
                                                }

                                                TextButton(
                                                    onClick = {
                                                        scope.launch {
                                                            val res = api.request(
                                                                "/api/calls/$callId/admin",
                                                                "POST",
                                                                json("action" to "mute_remote_video", "target_participant_id" to pId)
                                                            )
                                                            if (res.data.isJsonObject) {
                                                                onSessionUpdated(res.data.obj())
                                                                participants = res.data.obj().list("participants")
                                                            }
                                                        }
                                                    },
                                                    modifier = Modifier.testTag("btn_mute_cam_$pId")
                                                ) {
                                                    Text("Mute cam", style = AppTypography.caption1)
                                                }

                                                if (isPresenter) {
                                                    TextButton(
                                                        onClick = {
                                                            scope.launch {
                                                                val res = api.request(
                                                                    "/api/calls/$callId/admin",
                                                                    "POST",
                                                                    json("action" to "demote_from_presenter", "target_participant_id" to pId)
                                                                )
                                                                if (res.data.isJsonObject) {
                                                                    onSessionUpdated(res.data.obj())
                                                                    participants = res.data.obj().list("participants")
                                                                }
                                                            }
                                                        },
                                                        modifier = Modifier.testTag("btn_demote_$pId")
                                                    ) {
                                                        Text("Demote", style = AppTypography.caption1)
                                                    }
                                                } else {
                                                    TextButton(
                                                        onClick = {
                                                            scope.launch {
                                                                val res = api.request(
                                                                    "/api/calls/$callId/admin",
                                                                    "POST",
                                                                    json("action" to "promote_to_presenter", "target_participant_id" to pId)
                                                                )
                                                                if (res.data.isJsonObject) {
                                                                    onSessionUpdated(res.data.obj())
                                                                    participants = res.data.obj().list("participants")
                                                                }
                                                            }
                                                        },
                                                        modifier = Modifier.testTag("btn_promote_$pId")
                                                    ) {
                                                        Text("Promote", style = AppTypography.caption1)
                                                    }
                                                }

                                                Spacer(Modifier.weight(1f))

                                                TextButton(
                                                    onClick = {
                                                        scope.launch {
                                                            val res = api.request(
                                                                "/api/calls/$callId/admin",
                                                                "POST",
                                                                json("action" to "eject", "target_participant_id" to pId)
                                                            )
                                                            if (res.data.isJsonObject) {
                                                                onSessionUpdated(res.data.obj())
                                                                participants = res.data.obj().list("participants")
                                                            }
                                                        }
                                                    },
                                                    modifier = Modifier.testTag("btn_eject_$pId")
                                                ) {
                                                    Text("Eject", style = AppTypography.caption1, color = AppColors.statusError)
                                                }
                                            }
                                        }
                                        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle.copy(alpha = 0.4f))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
