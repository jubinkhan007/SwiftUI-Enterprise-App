package com.acme.taskflow.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*
import com.google.gson.JsonObject
import java.time.Instant
import java.time.ZoneId

@Composable
fun MeetingsScreen(vm: AppViewModel, api: ApiClient) {
    var scope by rememberSaveable { mutableStateOf("upcoming") }
    var selected by rememberSaveable { mutableStateOf<String?>(null) }
    var create by remember { mutableStateOf(false) }
    val remote = rememberRemote(api, "/api/meetings", vm.revision, query = mapOf("scope" to scope), paged = true)

    if (selected != null) {
        key(selected) {
            MeetingDetail(vm, api, selected!!) { selected = null }
        }
        return
    }

    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Meetings",
                    style = AppTypography.largeTitle,
                    color = AppColors.textPrimary,
                    modifier = Modifier.weight(1f)
                )
                IconButton(
                    onClick = { create = true },
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                ) {
                    Icon(Icons.Default.Add, "Schedule meeting", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("upcoming", "past").forEach { item ->
                    IosFilterChip(
                        title = label(item),
                        isSelected = scope == item,
                        onClick = { scope = item }
                    )
                }
            }
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(remote)

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            if (!remote.loading && remote.error == null && remote.data.rows().isEmpty()) {
                item {
                    Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                        Text("No $scope meetings.", style = AppTypography.body, color = AppColors.textSecondary)
                    }
                }
            }
            items(remote.data.rows(), key = { it.id }) { meeting ->
                IosCard(Modifier.fillMaxWidth(), onClick = { selected = meeting.id }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(RoundedCornerShape(AppRadius.medium))
                                .background(AppColors.brandPrimary.copy(alpha = 0.10f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.Event, null, tint = AppColors.brandPrimary, modifier = Modifier.size(22.dp))
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(meeting.text("title"), style = AppTypography.headline)
                            Text(dateLabel(meeting.text("scheduled_start_at")), style = AppTypography.subheadline, color = AppColors.textSecondary)
                            Text(
                                "${meeting.text("host_display_name")} • ${label(meeting.text("status"))}",
                                style = AppTypography.caption1,
                                color = AppColors.textTertiary
                            )
                        }
                        Icon(Icons.Default.ChevronRight, null, tint = Color(0xFFC7C7CC), modifier = Modifier.size(20.dp))
                    }
                }
            }
        }
    }

    if (create) {
        MeetingEditor(api, null, { create = false }) { vm.changed() }
    }
}

@Composable
private fun MeetingEditor(api: ApiClient, meeting: JsonObject?, onDismiss: () -> Unit, onSaved: () -> Unit) {
    val members = rememberRemote(api, "/api/organizations/${api.orgId}/members")
    EditorDialog(
        if (meeting == null) "Schedule meeting" else "Edit meeting",
        listOf(
            FormField("title", "Title", meeting?.text("title").orEmpty(), required = true),
            FormField("agenda", "Agenda", meeting?.text("agenda").orEmpty(), multiline = true),
            FormField("scheduled_start_at", "Start", meeting?.text("scheduled_start_at") ?: Instant.now().plusSeconds(3600).toString(), required = true, date = true),
            FormField("scheduled_end_at", "End", meeting?.text("scheduled_end_at") ?: Instant.now().plusSeconds(7200).toString(), required = true, date = true),
            FormField("member_id", "Invite member", options = members.data.rows().map { Choice(it.text("user_id"), it.text("display_name")) })
        ),
        onDismiss
    ) { payload ->
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

    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .background(AppColors.surfacePrimary)
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier
                    .clickable(onClick = onBack)
                    .padding(horizontal = 8.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.ChevronLeft,
                    contentDescription = "Back",
                    tint = AppColors.brandPrimary,
                    modifier = Modifier.size(28.dp)
                )
                Text("Meetings", style = AppTypography.body, color = AppColors.brandPrimary)
            }
            Text(
                "Meeting Details",
                style = AppTypography.headline,
                color = AppColors.textPrimary,
                modifier = Modifier.weight(1f).padding(horizontal = 8.dp)
            )
            if (host) {
                IconButton(onClick = { editor = "Meeting" }) {
                    Icon(Icons.Default.Edit, "Edit", tint = AppColors.brandPrimary)
                }
            }
            IconButton(
                onClick = {
                    val intent = android.content.Intent(android.content.Intent.ACTION_INSERT)
                        .setData(android.provider.CalendarContract.Events.CONTENT_URI)
                        .putExtra(android.provider.CalendarContract.Events.TITLE, meeting.text("title"))
                        .putExtra(android.provider.CalendarContract.Events.DESCRIPTION, meeting.text("agenda"))
                    context.startActivity(intent)
                },
                enabled = meeting.id.isNotBlank()
            ) {
                Icon(Icons.Default.Event, "Calendar", tint = AppColors.brandPrimary)
            }
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(remote)
        ActionStatus(action)

        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                IosCard(Modifier.fillMaxWidth()) {
                    Text(meeting.text("title"), style = AppTypography.title2)
                    Spacer(Modifier.height(8.dp))
                    Text(meeting.text("agenda").ifBlank { "No agenda provided." }, style = AppTypography.body, color = AppColors.textSecondary)
                    Spacer(Modifier.height(12.dp))
                    Text(
                        "${dateLabel(meeting.text("scheduled_start_at"))} - ${dateLabel(meeting.text("scheduled_end_at"))}",
                        style = AppTypography.footnote,
                        color = AppColors.brandPrimary
                    )
                }
            }

            item {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    IosButton(
                        title = "Join Call",
                        leadingIcon = Icons.Default.VideoCall,
                        onClick = {
                            action.run {
                                ticket = api.request("/api/calls/initiate", "POST", json("meeting_id" to id, "has_video" to true)).data.obj()
                            }
                        },
                        modifier = Modifier.weight(1f).height(44.dp)
                    )
                    if (host) {
                        IosButton(
                            title = "End",
                            variant = IosButtonVariant.Destructive,
                            onClick = { confirmation = "End meeting" },
                            modifier = Modifier.width(90.dp).height(44.dp)
                        )
                    }
                }
            }

            item {
                IosSectionHeader("Participants")
                IosInsetGroupedCard {
                    val participants = meeting.list("participants")
                    participants.forEachIndexed { index, participant ->
                        IosGroupedRow(
                            title = participant.text("display_name"),
                            subtitle = label(participant.text("role")),
                            icon = Icons.Default.Person,
                            showChevron = false,
                            showDivider = index < participants.lastIndex,
                            onClick = {}
                        )
                    }
                }
            }

            item {
                IosSectionHeader("Notes")
                IosCard(Modifier.fillMaxWidth()) {
                    RemoteStatus(notes)
                    Text(notes.data.obj().text("content").ifBlank { "No meeting notes recorded." }, style = AppTypography.body)
                    Spacer(Modifier.height(8.dp))
                    IosButton(
                        title = "Edit Notes",
                        variant = IosButtonVariant.Secondary,
                        onClick = { editor = "Notes" },
                        modifier = Modifier.fillMaxWidth().height(40.dp)
                    )
                }
            }

            item {
                IosSectionHeader("AI Summary")
                IosCard(Modifier.fillMaxWidth()) {
                    RemoteStatus(summary)
                    Text(summary.data.obj().text("content").ifBlank { "No summary generated yet." }, style = AppTypography.body)
                    Spacer(Modifier.height(8.dp))
                    IosButton(
                        title = "Generate Summary",
                        variant = IosButtonVariant.Secondary,
                        onClick = { action.run { api.request("/api/meetings/$id/summary/generate", "POST"); vm.changed() } },
                        modifier = Modifier.fillMaxWidth().height(40.dp)
                    )
                }
            }
        }
    }

    editor?.let { mode ->
        if (mode == "Meeting") {
            MeetingEditor(api, meeting, { editor = null }) { vm.changed() }
        } else {
            EditorDialog("Edit notes", listOf(FormField("content", "Notes", notes.data.obj().text("content"), multiline = true)), { editor = null }) {
                api.request("/api/meetings/$id/notes", "PUT", it)
                vm.changed()
            }
        }
    }

    confirmation?.let {
        ConfirmDialog("End meeting?", "Are you sure you want to end this meeting for everyone?", { confirmation = null }) {
            api.request("/api/meetings/$id/end", "POST")
            vm.changed()
        }
    }

    ticket?.let { room ->
        CallRoomDialog(api, room, onDismiss = { ticket = null; vm.changed() })
    }
}
