package com.acme.taskflow.ui.screens

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
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

    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text(
                text = "Calls",
                style = AppTypography.largeTitle,
                color = AppColors.textPrimary
            )
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(conversations)
        ActionStatus(action)

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(conversations.data.rows(), key = { it.id }) { conversation ->
                IosCard(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        AppAvatar(conversation.text("name", "DM"))
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(
                                conversation.text("name", "Direct message"),
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
                                action.run {
                                    ticket = api.request(
                                        "/api/calls/initiate",
                                        "POST",
                                        json("conversation_id" to conversation.id, "has_video" to false)
                                    ).data.obj()
                                }
                            },
                            enabled = !action.busy
                        ) {
                            Icon(Icons.Default.Call, "Audio call", tint = AppColors.brandPrimary)
                        }
                        IconButton(
                            onClick = {
                                action.run {
                                    ticket = api.request(
                                        "/api/calls/initiate",
                                        "POST",
                                        json("conversation_id" to conversation.id, "has_video" to true)
                                    ).data.obj()
                                }
                            },
                            enabled = !action.busy
                        ) {
                            Icon(Icons.Default.VideoCall, "Video call", tint = AppColors.brandPrimary)
                        }
                    }
                }
            }
        }
    }
    ticket?.let { CallRoomDialog(api, it) { ticket = null; vm.changed() } }
}

@Composable
fun CallRoomDialog(api: ApiClient, ticket: JsonObject, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val room = remember(ticket) { LiveKit.create(context.applicationContext) }
    val session = ticket.child("session")
    val token = ticket.child("token")
    val action = rememberAction()
    var state by remember { mutableStateOf("Connecting") }
    var mic by remember { mutableStateOf(false) }
    var camera by remember { mutableStateOf(false) }
    var sharing by remember { mutableStateOf(false) }
    var eventVersion by remember { mutableIntStateOf(0) }
    var permissionAction by remember { mutableStateOf("") }

    val permissions = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) action.run {
            if (permissionAction == "mic") {
                check(room.localParticipant.setMicrophoneEnabled(true))
                mic = true
            } else {
                check(room.localParticipant.setCameraEnabled(true))
                camera = true
            }
            eventVersion++
        } else action.error = "Permission was denied. You can still listen to the call."
    }

    val screenCapture = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK && result.data != null) action.run {
            check(room.localParticipant.setScreenShareEnabled(true, ScreenCaptureParams(result.data!!)))
            sharing = true
            eventVersion++
        }
    }

    LaunchedEffect(room) {
        try {
            require(token.text("provider") == "livekit" && token.text("url").isNotBlank()) {
                "The server has not configured a LiveKit media provider."
            }
            launch {
                room.events.collect {
                    state = room.state.toString()
                    eventVersion++
                }
            }
            room.connect(token.text("url"), token.text("token"))
            state = room.state.toString()
            awaitCancellation()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            action.error = e.message
            state = "Disconnected"
        } finally {
            room.disconnect()
            withContext(NonCancellable) {
                runCatching { api.request("/api/calls/${session.id}/leave", "POST") }
            }
        }
    }

    DisposableEffect(room) {
        onDispose {
            room.disconnect()
            room.release()
        }
    }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF0C1017))
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .safeDrawingPadding()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("Active Call", style = AppTypography.headline, color = Color.White)
                        Text(state, style = AppTypography.caption1, color = Color.White.copy(alpha = 0.7f))
                    }
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(AppRadius.pill))
                            .background(if (state.equals("CONNECTED", true)) AppColors.statusSuccess else AppColors.statusWarning)
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Text(
                            text = state.lowercase().replaceFirstChar { it.uppercase() },
                            style = AppTypography.caption2,
                            color = Color.White
                        )
                    }
                }

                ActionStatus(action)

                val tracks = remember(eventVersion) {
                    (listOf(room.localParticipant) + room.remoteParticipants.values).flatMap { participant ->
                        participant.trackPublications.values.mapNotNull { publication ->
                            (publication.track as? VideoTrack)?.takeUnless { publication.muted }?.let { participant.name.orEmpty() to it }
                        }
                    }
                }

                LazyColumn(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(tracks) { (name, track) ->
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(AppRadius.large))
                                .background(Color(0xFF1A202A))
                        ) {
                            Text(
                                text = name,
                                style = AppTypography.caption1,
                                color = Color.White,
                                modifier = Modifier.padding(8.dp)
                            )
                            AndroidView(
                                factory = { rendererContext ->
                                    TextureViewRenderer(rendererContext).also { renderer ->
                                        room.initVideoRenderer(renderer)
                                        track.addRenderer(renderer)
                                    }
                                },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .aspectRatio(16f / 9f),
                                onRelease = { renderer ->
                                    track.removeRenderer(renderer)
                                    renderer.release()
                                }
                            )
                        }
                    }
                    if (tracks.isEmpty()) {
                        items(session.list("participants"), key = { it.id }) { participant ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(AppRadius.medium))
                                    .background(Color(0xFF1A202A))
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                AppAvatar(participant.text("display_name"))
                                Spacer(Modifier.width(12.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(participant.text("display_name"), color = Color.White, style = AppTypography.headline)
                                    Text(label(participant.text("status")), color = Color.White.copy(alpha = 0.6f), style = AppTypography.caption1)
                                }
                            }
                        }
                    }
                }

                // Call Controls Bar (iOS InCallView matching floating pill)
                Box(
                    modifier = Modifier.fillMaxWidth(),
                    contentAlignment = Alignment.Center
                ) {
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(AppRadius.pill))
                            .background(Color(0xFF262E3B))
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(
                            onClick = {
                                if (!mic && ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                                    permissionAction = "mic"
                                    permissions.launch(Manifest.permission.RECORD_AUDIO)
                                } else action.run {
                                    check(room.localParticipant.setMicrophoneEnabled(!mic))
                                    mic = !mic
                                    eventVersion++
                                }
                            },
                            enabled = !action.busy && state.equals("CONNECTED", true),
                            modifier = Modifier
                                .size(44.dp)
                                .clip(CircleShape)
                                .background(if (mic) Color.White.copy(alpha = 0.2f) else Color.Transparent)
                        ) {
                            Icon(
                                imageVector = if (mic) Icons.Default.Mic else Icons.Default.MicOff,
                                contentDescription = "Mic",
                                tint = Color.White
                            )
                        }

                        IconButton(
                            onClick = {
                                if (!camera && ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                                    permissionAction = "camera"
                                    permissions.launch(Manifest.permission.CAMERA)
                                } else action.run {
                                    check(room.localParticipant.setCameraEnabled(!camera))
                                    camera = !camera
                                    eventVersion++
                                }
                            },
                            enabled = !action.busy && state.equals("CONNECTED", true),
                            modifier = Modifier
                                .size(44.dp)
                                .clip(CircleShape)
                                .background(if (camera) Color.White.copy(alpha = 0.2f) else Color.Transparent)
                        ) {
                            Icon(
                                imageVector = if (camera) Icons.Default.Videocam else Icons.Default.VideocamOff,
                                contentDescription = "Camera",
                                tint = Color.White
                            )
                        }

                        IconButton(
                            onClick = {
                                if (sharing) action.run {
                                    room.localParticipant.setScreenShareEnabled(false)
                                    sharing = false
                                    eventVersion++
                                } else {
                                    screenCapture.launch((context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager).createScreenCaptureIntent())
                                }
                            },
                            enabled = !action.busy && state.equals("CONNECTED", true),
                            modifier = Modifier
                                .size(44.dp)
                                .clip(CircleShape)
                                .background(if (sharing) Color.White.copy(alpha = 0.2f) else Color.Transparent)
                        ) {
                            Icon(
                                imageVector = if (sharing) Icons.Default.StopScreenShare else Icons.Default.ScreenShare,
                                contentDescription = "Screen share",
                                tint = Color.White
                            )
                        }

                        IconButton(
                            onClick = onDismiss,
                            modifier = Modifier
                                .size(48.dp)
                                .clip(CircleShape)
                                .background(AppColors.statusError)
                        ) {
                            Icon(
                                imageVector = Icons.Default.CallEnd,
                                contentDescription = "Leave call",
                                tint = Color.White
                            )
                        }
                    }
                }
            }
        }
    }
}
