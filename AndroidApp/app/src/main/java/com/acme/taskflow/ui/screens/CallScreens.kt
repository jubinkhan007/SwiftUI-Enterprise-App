package com.acme.taskflow.ui.screens

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
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
    Column {
        RemoteStatus(conversations); ActionStatus(action)
        LazyColumn {
            items(conversations.data.rows(), key = { it.id }) { conversation ->
                ListItem(headlineContent = { Text(conversation.text("name", "Direct message")) },
                    leadingContent = { AppAvatar(conversation.text("name", "DM")) }, trailingContent = { Row {
                        ToolButton(Icons.Default.Call, "Audio call", !action.busy) { action.run { ticket = api.request("/api/calls/initiate", "POST", json("conversation_id" to conversation.id, "has_video" to false)).data.obj() } }
                        ToolButton(Icons.Default.VideoCall, "Video call", !action.busy) { action.run { ticket = api.request("/api/calls/initiate", "POST", json("conversation_id" to conversation.id, "has_video" to true)).data.obj() } }
                    } })
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
            if (permissionAction == "mic") { check(room.localParticipant.setMicrophoneEnabled(true)); mic = true }
            else { check(room.localParticipant.setCameraEnabled(true)); camera = true }
            eventVersion++
        } else action.error = "Permission was denied. You can still listen to the call."
    }
    val screenCapture = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK && result.data != null) action.run {
            check(room.localParticipant.setScreenShareEnabled(true, ScreenCaptureParams(result.data!!)))
            sharing = true; eventVersion++
        }
    }
    LaunchedEffect(room) {
        try {
            require(token.text("provider") == "livekit" && token.text("url").isNotBlank()) { "The server has not configured a LiveKit media provider." }
            launch { room.events.collect { state = room.state.toString(); eventVersion++ } }
            room.connect(token.text("url"), token.text("token"))
            state = room.state.toString()
            awaitCancellation()
        } catch (e: CancellationException) { throw e
        } catch (e: Exception) { action.error = e.message; state = "Disconnected"
        } finally {
            room.disconnect()
            withContext(NonCancellable) { runCatching { api.request("/api/calls/${session.id}/leave", "POST") } }
        }
    }
    DisposableEffect(room) { onDispose { room.disconnect(); room.release() } }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(Modifier.fillMaxSize()) {
            Column(Modifier.safeDrawingPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Call", style = MaterialTheme.typography.headlineSmall)
                Text(state, style = MaterialTheme.typography.bodySmall)
                ActionStatus(action)
                val tracks = remember(eventVersion) {
                    (listOf(room.localParticipant) + room.remoteParticipants.values).flatMap { participant ->
                        participant.trackPublications.values.mapNotNull { publication ->
                            (publication.track as? VideoTrack)?.takeUnless { publication.muted }?.let { participant.name.orEmpty() to it }
                        }
                    }
                }
                LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(tracks) { (name, track) ->
                        Column {
                            Text(name)
                            AndroidView(factory = { rendererContext -> TextureViewRenderer(rendererContext).also { renderer -> room.initVideoRenderer(renderer); track.addRenderer(renderer) } },
                                modifier = Modifier.fillMaxWidth().aspectRatio(16f / 9f), onRelease = { renderer -> track.removeRenderer(renderer); renderer.release() })
                        }
                    }
                    if (tracks.isEmpty()) items(session.list("participants"), key = { it.id }) { participant ->
                        ListItem(headlineContent = { Text(participant.text("display_name")) }, supportingContent = { Text(label(participant.text("status"))) }, leadingContent = { AppAvatar(participant.text("display_name")) })
                    }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
                    ToolButton(if (mic) Icons.Default.Mic else Icons.Default.MicOff, "Toggle microphone", !action.busy && state.equals("CONNECTED", true)) {
                        if (!mic && ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) { permissionAction = "mic"; permissions.launch(Manifest.permission.RECORD_AUDIO) }
                        else action.run { check(room.localParticipant.setMicrophoneEnabled(!mic)); mic = !mic; eventVersion++ }
                    }
                    ToolButton(if (camera) Icons.Default.Videocam else Icons.Default.VideocamOff, "Toggle camera", !action.busy && state.equals("CONNECTED", true)) {
                        if (!camera && ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) { permissionAction = "camera"; permissions.launch(Manifest.permission.CAMERA) }
                        else action.run { check(room.localParticipant.setCameraEnabled(!camera)); camera = !camera; eventVersion++ }
                    }
                    ToolButton(if (sharing) Icons.Default.StopScreenShare else Icons.Default.ScreenShare, "Toggle screen sharing", !action.busy && state.equals("CONNECTED", true)) {
                        if (sharing) action.run { room.localParticipant.setScreenShareEnabled(false); sharing = false; eventVersion++ }
                        else screenCapture.launch((context.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager).createScreenCaptureIntent())
                    }
                    FilledIconButton(onClick = onDismiss, colors = IconButtonDefaults.filledIconButtonColors(containerColor = MaterialTheme.colorScheme.error)) { Icon(Icons.Default.CallEnd, "Leave call") }
                }
            }
        }
    }
}
