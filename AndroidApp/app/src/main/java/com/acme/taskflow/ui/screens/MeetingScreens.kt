package com.acme.taskflow.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.google.gson.JsonObject
import java.time.Instant
import java.time.ZoneId

@Composable
fun MeetingsScreen(vm: AppViewModel, api: ApiClient) {
    var scope by rememberSaveable { mutableStateOf("upcoming") }
    var selected by rememberSaveable { mutableStateOf<String?>(null) }
    var create by remember { mutableStateOf(false) }
    val remote = rememberRemote(api, "/api/meetings", vm.revision, query = mapOf("scope" to scope), paged = true)
    if (selected != null) { key(selected) { MeetingDetail(vm, api, selected!!) { selected = null } }; return }
    Column {
        Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("upcoming", "past").forEach { item -> FilterChip(scope == item, { scope = item }, label = { Text(label(item)) }) }
            }
            ToolButton(Icons.Default.Add, "Schedule meeting") { create = true }
        }
        RemoteStatus(remote)
        LazyColumn {
            if (!remote.loading && remote.error == null && remote.data.rows().isEmpty()) item { Text("No $scope meetings.", Modifier.padding(24.dp)) }
            items(remote.data.rows(), key = { it.id }) { meeting ->
                ListItem(headlineContent = { Text(meeting.text("title")) },
                    supportingContent = { Text("${dateLabel(meeting.text("scheduled_start_at"))}\n${meeting.text("host_display_name")} / ${label(meeting.text("status"))}") },
                    leadingContent = { Icon(Icons.Default.Event, null) }, modifier = Modifier.clickable { selected = meeting.id })
                HorizontalDivider()
            }
        }
    }
    if (create) MeetingEditor(api, null, { create = false }) { vm.changed() }
}

@Composable
private fun MeetingEditor(api: ApiClient, meeting: JsonObject?, onDismiss: () -> Unit, onSaved: () -> Unit) {
    val members = rememberRemote(api, "/api/organizations/${api.orgId}/members")
    EditorDialog(if (meeting == null) "Schedule meeting" else "Edit meeting", listOf(
        FormField("title", "Title", meeting?.text("title").orEmpty(), required = true),
        FormField("agenda", "Agenda", meeting?.text("agenda").orEmpty(), multiline = true),
        FormField("scheduled_start_at", "Start", meeting?.text("scheduled_start_at") ?: Instant.now().plusSeconds(3600).toString(), required = true, date = true),
        FormField("scheduled_end_at", "End", meeting?.text("scheduled_end_at") ?: Instant.now().plusSeconds(7200).toString(), required = true, date = true),
        FormField("member_id", "Invite member", options = members.data.rows().map { Choice(it.text("user_id"), it.text("display_name")) })
    ), onDismiss) { payload ->
        require(Instant.parse(payload.text("scheduled_end_at")).isAfter(Instant.parse(payload.text("scheduled_start_at")))) { "End time must be after start time." }
        val member = payload.remove("member_id")?.asString.orEmpty()
        payload.addProperty("timezone", ZoneId.systemDefault().id)
        payload.add("member_ids", json("ids" to if (member.isBlank()) emptyList<String>() else listOf(member)).get("ids"))
        api.request(if (meeting == null) "/api/meetings" else "/api/meetings/${meeting.id}", if (meeting == null) "POST" else "PUT", payload)
        if (meeting != null && member.isNotBlank()) api.request("/api/meetings/${meeting.id}/participants", "POST", json("member_ids" to listOf(member)))
        onSaved()
    }
}

@Composable
private fun MeetingDetail(vm: AppViewModel, api: ApiClient, id: String, onBack: () -> Unit) {
    BackHandler(onBack = onBack)
    val remote = rememberRemote(api, "/api/meetings/$id", vm.revision)
    val notes = rememberRemote(api, "/api/meetings/$id/notes", vm.revision)
    val summary = rememberRemote(api, "/api/meetings/$id/summary", vm.revision)
    val meeting = remote.data.obj()
    val host = meeting.child("my_participant").text("role") in listOf("host", "co_host")
    val action = rememberAction()
    var editor by remember { mutableStateOf<String?>(null) }
    var confirmation by remember { mutableStateOf<String?>(null) }
    var ticket by remember { mutableStateOf<JsonObject?>(null) }
    val context = LocalContext.current
    Column {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ToolButton(Icons.Default.ArrowBack, "Back to meetings", onClick = onBack)
            Text("Meeting", Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            if (host) ToolButton(Icons.Default.Edit, "Edit meeting") { editor = "Meeting" }
            ToolButton(Icons.Default.Event, "Add to calendar", meeting.id.isNotBlank()) {
                val intent = android.content.Intent(android.content.Intent.ACTION_INSERT).setData(android.provider.CalendarContract.Events.CONTENT_URI)
                    .putExtra(android.provider.CalendarContract.Events.TITLE, meeting.text("title"))
                    .putExtra(android.provider.CalendarContract.Events.DESCRIPTION, meeting.text("agenda"))
                    .putExtra(android.provider.CalendarContract.EXTRA_EVENT_BEGIN_TIME, Instant.parse(meeting.text("scheduled_start_at")).toEpochMilli())
                    .putExtra(android.provider.CalendarContract.EXTRA_EVENT_END_TIME, Instant.parse(meeting.text("scheduled_end_at")).toEpochMilli())
                runCatching { context.startActivity(intent) }.onFailure { action.error = "No calendar app is available." }
            }
        }
        RemoteStatus(remote); ActionStatus(action)
        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            item {
                Text(meeting.text("title"), style = MaterialTheme.typography.headlineSmall)
                Text(dateLabel(meeting.text("scheduled_start_at")))
                Text(label(meeting.text("status")))
                Text(meeting.text("agenda"), modifier = Modifier.padding(vertical = 12.dp))
                val joinState = meeting.child("my_participant").text("join_state")
                if (joinState == "waiting") Text("Waiting for the host to admit you.")
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (meeting.text("status") in listOf("scheduled", "in_progress")) {
                        Button(enabled = !action.busy, onClick = { action.run {
                            if (joinState == "in_meeting") {
                                val conversationId = meeting.text("meeting_chat_conversation_id", meeting.text("conversation_id"))
                                require(conversationId.isNotBlank()) { "Meeting chat is not ready." }
                                ticket = api.request("/api/calls/initiate", "POST", json("conversation_id" to conversationId, "meeting_id" to id, "has_video" to true)).data.obj()
                            } else api.request("/api/meetings/$id/join", "POST")
                            vm.changed()
                        } }) { Text(if (joinState == "in_meeting") "Open call" else "Join") }
                        TextButton(enabled = !action.busy, onClick = { action.run { api.request("/api/meetings/$id/participants/me/rsvp", "PUT", json("status" to "accepted")); vm.changed() } }) { Text("Accept") }
                        TextButton(enabled = !action.busy, onClick = { action.run { api.request("/api/meetings/$id/participants/me/rsvp", "PUT", json("status" to "declined")); vm.changed() } }) { Text("Decline") }
                    }
                    if (joinState in listOf("waiting", "in_meeting")) TextButton(onClick = { confirmation = "Leave" }) { Text("Leave") }
                    if (host && meeting.text("status") == "in_progress") TextButton(onClick = { confirmation = "End" }) { Text("End meeting") }
                    if (host && meeting.text("status") == "scheduled") TextButton(onClick = { confirmation = "Cancel" }) { Text("Cancel meeting") }
                }
            }
            item { Text("Participants", style = MaterialTheme.typography.titleMedium) }
            items(meeting.list("participants"), key = { it.id }) { participant ->
                ListItem(headlineContent = { Text(participant.text("display_name", participant.text("guest_email"))) },
                    supportingContent = { Text("${label(participant.text("role"))} / ${label(participant.text("join_state"))}") }, trailingContent = {
                        if (host && participant.text("join_state") == "waiting") Row {
                            ToolButton(Icons.Default.Check, "Admit participant", !action.busy) { action.run { api.request("/api/meetings/$id/participants/${participant.id}/admit", "POST"); vm.changed() } }
                            ToolButton(Icons.Default.Close, "Deny participant", !action.busy) { action.run { api.request("/api/meetings/$id/participants/${participant.id}/deny", "POST"); vm.changed() } }
                        }
                    })
            }
            item {
                Row(verticalAlignment = Alignment.CenterVertically) { Text("Notes", Modifier.weight(1f), style = MaterialTheme.typography.titleMedium); ToolButton(Icons.Default.Edit, "Edit notes", !notes.loading && notes.error == null) { editor = "Notes" } }
                RemoteStatus(notes); Text(notes.data.obj().text("body", "No notes yet."))
            }
            item {
                Row(verticalAlignment = Alignment.CenterVertically) { Text("Summary", Modifier.weight(1f), style = MaterialTheme.typography.titleMedium); ToolButton(Icons.Default.AutoAwesome, "Generate summary", !action.busy) { action.run { api.request("/api/meetings/$id/summary", "POST", json("regenerate" to true)); vm.changed() } } }
                RemoteStatus(summary); Text(summary.data.obj().text("summary_text"))
                summary.data.obj().list("action_items").forEach { Text(it.text("text"), Modifier.padding(vertical = 8.dp)) }
            }
        }
    }
    when (editor) {
        "Meeting" -> MeetingEditor(api, meeting, { editor = null }, vm::changed)
        "Notes" -> EditorDialog("Meeting notes", listOf(FormField("body", "Notes", notes.data.obj().text("body"), multiline = true)), { editor = null }) { payload ->
            payload.addProperty("expected_version", notes.data.obj().number("version")); api.request("/api/meetings/$id/notes", "PUT", payload); vm.changed()
        }
    }
    confirmation?.let { name -> ConfirmDialog("$name meeting?", meeting.text("title"), { confirmation = null }) {
        api.request(if (name == "Cancel") "/api/meetings/$id" else "/api/meetings/$id/${name.lowercase()}", if (name == "Cancel") "DELETE" else "POST"); vm.changed()
    } }
    ticket?.let { CallRoomDialog(api, it) { ticket = null; vm.changed() } }
}
