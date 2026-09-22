package com.acme.taskflow.ui.screens

import android.content.Intent
import android.provider.CalendarContract
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

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
                        .testTag("btn_schedule_meeting")
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
                IosCard(
                    Modifier.fillMaxWidth().testTag("meeting_card_${meeting.id}"),
                    onClick = { selected = meeting.id }
                ) {
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
        ScheduleMeetingSheet(api = api, onDismiss = { create = false }) {
            create = false
            vm.changed()
        }
    }
}

// MARK: - Advanced Scheduler Sheet (matches ScheduleMeetingSheet.swift)
@Composable
fun ScheduleMeetingSheet(
    api: ApiClient,
    onDismiss: () -> Unit,
    onCreated: () -> Unit
) {
    val orgMembers = rememberRemote(api, "/api/organizations/${api.orgId}/members")
    val scope = rememberCoroutineScope()

    var title by remember { mutableStateOf("") }
    var agenda by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var durationMinutes by remember { mutableIntStateOf(30) }
    var requiresWaitingRoom by remember { mutableStateOf(true) }
    var allowGuests by remember { mutableStateOf(false) }
    var guestEmailsRaw by remember { mutableStateOf("") }
    val selectedMemberIds = remember { mutableStateListOf<String>() }

    var recurrenceFreq by remember { mutableStateOf("none") } // none, daily, weekly, monthly
    var recurrenceInterval by remember { mutableIntStateOf(1) }
    var recurrenceCount by remember { mutableIntStateOf(10) }

    var isSubmitting by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    val timezone = remember { ZoneId.systemDefault().id }
    val startTime = remember { Instant.now().plusSeconds(1800) }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Card(
            shape = RoundedCornerShape(topStart = AppRadius.large, topEnd = AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .testTag("schedule_meeting_sheet")
        ) {
            Column(Modifier.fillMaxSize()) {
                // Top Bar
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(onClick = onDismiss) {
                        Text("Cancel", style = AppTypography.body, color = AppColors.brandPrimary)
                    }
                    Text("New Meeting", style = AppTypography.headline, color = AppColors.textPrimary)
                    Button(
                        onClick = {
                            if (title.trim().isBlank()) {
                                errorMessage = "Title is required."
                                return@Button
                            }
                            scope.launch {
                                isSubmitting = true
                                errorMessage = null
                                try {
                                    val startInstant = startTime
                                    val endInstant = startInstant.plusSeconds(durationMinutes * 60L)
                                    val guestList = if (allowGuests) {
                                        guestEmailsRaw.split(",")
                                            .map { it.trim() }
                                            .filter { it.isNotEmpty() }
                                    } else emptyList()

                                    val recurrenceObj = if (recurrenceFreq != "none") {
                                        json(
                                            "freq" to recurrenceFreq,
                                            "interval" to recurrenceInterval,
                                            "count" to recurrenceCount
                                        )
                                    } else null

                                    val payload = json(
                                        "title" to title.trim(),
                                        "agenda" to agenda.trim(),
                                        "description" to description.trim(),
                                        "scheduled_start_at" to startInstant.toString(),
                                        "scheduled_end_at" to endInstant.toString(),
                                        "timezone" to timezone,
                                        "requires_waiting_room" to requiresWaitingRoom,
                                        "allow_guests" to allowGuests,
                                        "member_ids" to selectedMemberIds.toList(),
                                        "guest_emails" to guestList
                                    )
                                    if (recurrenceObj != null) {
                                        payload.add("recurrence", recurrenceObj)
                                    }

                                    api.request("/api/meetings", "POST", payload)
                                    onCreated()
                                } catch (e: Exception) {
                                    errorMessage = e.message ?: "Could not create meeting."
                                } finally {
                                    isSubmitting = false
                                }
                            }
                        },
                        enabled = title.trim().isNotBlank() && !isSubmitting,
                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary),
                        shape = RoundedCornerShape(AppRadius.medium),
                        modifier = Modifier.testTag("btn_submit_meeting")
                    ) {
                        if (isSubmitting) {
                            CircularProgressIndicator(modifier = Modifier.size(16.dp), color = Color.White, strokeWidth = 2.dp)
                        } else {
                            Text("Create", style = AppTypography.subheadline, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

                errorMessage?.let { err ->
                    Surface(
                        color = AppColors.statusError.copy(alpha = 0.12f),
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
                        shape = RoundedCornerShape(AppRadius.small)
                    ) {
                        Text(err, style = AppTypography.caption1, color = AppColors.statusError, modifier = Modifier.padding(8.dp))
                    }
                }

                LazyColumn(
                    modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp).testTag("schedule_meeting_list"),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                    contentPadding = PaddingValues(vertical = 12.dp)
                ) {
                    // SECTION 1: DETAILS
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text("Details", style = AppTypography.headline, color = AppColors.textPrimary)
                                IosTextField(
                                    label = "Title",
                                    value = title,
                                    onValueChange = { title = it },
                                    singleLine = true,
                                    modifier = Modifier.testTag("meeting_title_input")
                                )
                                IosTextField(
                                    label = "Agenda (optional)",
                                    value = agenda,
                                    onValueChange = { agenda = it },
                                    singleLine = false,
                                    minLines = 2
                                )
                                IosTextField(
                                    label = "Description (optional)",
                                    value = description,
                                    onValueChange = { description = it },
                                    singleLine = false,
                                    minLines = 2
                                )
                            }
                        }
                    }

                    // SECTION 2: WHEN & DURATION
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text("When", style = AppTypography.headline, color = AppColors.textPrimary)
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("Starts", style = AppTypography.subheadline, color = AppColors.textSecondary)
                                    Text(dateLabel(startTime.toString()), style = AppTypography.subheadline, color = AppColors.textPrimary, fontWeight = FontWeight.Medium)
                                }
                                Text("Duration", style = AppTypography.subheadline, color = AppColors.textSecondary)
                                Row(
                                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    listOf(15, 30, 45, 60, 90, 120).forEach { mins ->
                                        FilterChip(
                                            selected = durationMinutes == mins,
                                            onClick = { durationMinutes = mins },
                                            label = { Text("$mins min", style = AppTypography.caption1) },
                                            colors = FilterChipDefaults.filterChipColors(
                                                selectedContainerColor = AppColors.brandPrimary,
                                                selectedLabelColor = Color.White
                                            ),
                                            shape = RoundedCornerShape(AppRadius.small)
                                        )
                                    }
                                }
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("Time zone", style = AppTypography.caption1, color = AppColors.textSecondary)
                                    Text(timezone, style = AppTypography.caption1, color = AppColors.textTertiary)
                                }
                            }
                        }
                    }

                    // SECTION 3: INVITE PEOPLE
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text("Invite people", style = AppTypography.headline, color = AppColors.textPrimary)
                                val members = orgMembers.data.rows()
                                if (members.isEmpty()) {
                                    Text("No org members available.", style = AppTypography.caption1, color = AppColors.textSecondary)
                                } else {
                                    members.forEach { m ->
                                        val mUserId = m.text("user_id").ifBlank { m.id }
                                        val isSelected = mUserId in selectedMemberIds
                                        Row(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .clickable {
                                                    if (isSelected) selectedMemberIds.remove(mUserId)
                                                    else selectedMemberIds.add(mUserId)
                                                }
                                                .padding(vertical = 4.dp),
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                                Box(
                                                    modifier = Modifier
                                                        .size(28.dp)
                                                        .clip(CircleShape)
                                                        .background(AppColors.brandPrimary.copy(alpha = 0.15f)),
                                                    contentAlignment = Alignment.Center
                                                ) {
                                                    Text(m.text("display_name").take(1).uppercase(), style = AppTypography.caption1, color = AppColors.brandPrimary)
                                                }
                                                Text(m.text("display_name"), style = AppTypography.subheadline, color = AppColors.textPrimary)
                                            }
                                            Checkbox(
                                                checked = isSelected,
                                                onCheckedChange = {
                                                    if (it) selectedMemberIds.add(mUserId)
                                                    else selectedMemberIds.remove(mUserId)
                                                },
                                                colors = CheckboxDefaults.colors(checkedColor = AppColors.brandPrimary)
                                            )
                                        }
                                        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle.copy(alpha = 0.4f))
                                    }
                                }

                                if (allowGuests) {
                                    IosTextField(
                                        label = "Guest emails (comma-separated)",
                                        value = guestEmailsRaw,
                                        onValueChange = { guestEmailsRaw = it },
                                        singleLine = false,
                                        minLines = 2
                                    )
                                }
                            }
                        }
                    }

                    // SECTION 4: RECURRENCE
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text("Recurrence", style = AppTypography.headline, color = AppColors.textPrimary)
                                Row(
                                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                                ) {
                                    listOf("none" to "Does not repeat", "daily" to "Daily", "weekly" to "Weekly", "monthly" to "Monthly").forEach { (key, name) ->
                                        FilterChip(
                                            selected = recurrenceFreq == key,
                                            onClick = { recurrenceFreq = key },
                                            label = { Text(name, style = AppTypography.caption1) },
                                            colors = FilterChipDefaults.filterChipColors(
                                                selectedContainerColor = AppColors.brandPrimary,
                                                selectedLabelColor = Color.White
                                            ),
                                            shape = RoundedCornerShape(AppRadius.small),
                                            modifier = Modifier.testTag("recurrence_$key")
                                        )
                                    }
                                }

                                if (recurrenceFreq != "none") {
                                    val unitLabel = when (recurrenceFreq) {
                                        "daily" -> "day(s)"
                                        "weekly" -> "week(s)"
                                        "monthly" -> "month(s)"
                                        else -> ""
                                    }
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text("Every $recurrenceInterval $unitLabel", style = AppTypography.subheadline, color = AppColors.textPrimary)
                                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                            FilledTonalIconButton(
                                                onClick = { if (recurrenceInterval > 1) recurrenceInterval-- },
                                                modifier = Modifier.size(32.dp)
                                            ) { Text("-", fontWeight = FontWeight.Bold) }
                                            FilledTonalIconButton(
                                                onClick = { if (recurrenceInterval < 10) recurrenceInterval++ },
                                                modifier = Modifier.size(32.dp)
                                            ) { Text("+", fontWeight = FontWeight.Bold) }
                                        }
                                    }
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text("End after $recurrenceCount occurrences", style = AppTypography.subheadline, color = AppColors.textPrimary)
                                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                            FilledTonalIconButton(
                                                onClick = { if (recurrenceCount > 1) recurrenceCount-- },
                                                modifier = Modifier.size(32.dp)
                                            ) { Text("-", fontWeight = FontWeight.Bold) }
                                            FilledTonalIconButton(
                                                onClick = { if (recurrenceCount < 100) recurrenceCount++ },
                                                modifier = Modifier.size(32.dp)
                                            ) { Text("+", fontWeight = FontWeight.Bold) }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // SECTION 5: SETTINGS
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("Settings", style = AppTypography.headline, color = AppColors.textPrimary)
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("Require waiting room", style = AppTypography.subheadline, color = AppColors.textPrimary)
                                    Switch(
                                        checked = requiresWaitingRoom,
                                        onCheckedChange = { requiresWaitingRoom = it },
                                        modifier = Modifier.testTag("switch_waiting_room")
                                    )
                                }
                                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle.copy(alpha = 0.5f))
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("Allow guests via link", style = AppTypography.subheadline, color = AppColors.textPrimary)
                                    Switch(
                                        checked = allowGuests,
                                        onCheckedChange = { allowGuests = it }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Pre-Join Lobby Modal (matches MeetingLobbyView.swift)
@Composable
fun MeetingLobbyModal(
    meeting: JsonObject,
    onDismiss: () -> Unit,
    onJoinSubmitted: (micOn: Boolean, camOn: Boolean) -> Unit
) {
    var micOn by remember { mutableStateOf(true) }
    var camOn by remember { mutableStateOf(false) }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier
                .fillMaxWidth(0.92f)
                .wrapContentHeight()
                .testTag("meeting_lobby_modal")
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Lobby", style = AppTypography.headline, color = AppColors.textPrimary)
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }

                // Video Preview Box
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(Color.Black),
                    contentAlignment = Alignment.Center
                ) {
                    if (!camOn) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(
                                Icons.Default.VideocamOff,
                                contentDescription = "Camera off",
                                tint = Color.White.copy(alpha = 0.7f),
                                modifier = Modifier.size(36.dp)
                            )
                            Text("Camera off", style = AppTypography.caption1, color = Color.White.copy(alpha = 0.7f))
                        }
                    } else {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(
                                Icons.Default.Videocam,
                                contentDescription = "Camera active",
                                tint = AppColors.brandPrimary,
                                modifier = Modifier.size(40.dp)
                            )
                            Text("Camera preview active", style = AppTypography.caption1, color = Color.White.copy(alpha = 0.8f))
                        }
                    }
                }

                // Title and Info
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = meeting.text("title"),
                        style = AppTypography.title2,
                        color = AppColors.textPrimary,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "You're about to join the meeting.",
                        style = AppTypography.subheadline,
                        color = AppColors.textSecondary
                    )
                }

                // Device Controls
                Row(
                    horizontalArrangement = Arrangement.spacedBy(24.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Mic toggle
                    IconButton(
                        onClick = { micOn = !micOn },
                        modifier = Modifier
                            .size(56.dp)
                            .clip(CircleShape)
                            .background(if (micOn) AppColors.brandPrimary else Color.Gray)
                            .testTag("btn_lobby_mic")
                    ) {
                        Icon(
                            if (micOn) Icons.Default.Mic else Icons.Default.MicOff,
                            contentDescription = if (micOn) "Mic on" else "Mic off",
                            tint = Color.White,
                            modifier = Modifier.size(26.dp)
                        )
                    }

                    // Cam toggle
                    IconButton(
                        onClick = { camOn = !camOn },
                        modifier = Modifier
                            .size(56.dp)
                            .clip(CircleShape)
                            .background(if (camOn) AppColors.brandPrimary else Color.Gray)
                            .testTag("btn_lobby_cam")
                    ) {
                        Icon(
                            if (camOn) Icons.Default.Videocam else Icons.Default.VideocamOff,
                            contentDescription = if (camOn) "Camera on" else "Camera off",
                            tint = Color.White,
                            modifier = Modifier.size(26.dp)
                        )
                    }
                }

                // Join Button
                Button(
                    onClick = { onJoinSubmitted(micOn, camOn) },
                    modifier = Modifier.fillMaxWidth().height(48.dp).testTag("btn_lobby_join"),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text("Join meeting", style = AppTypography.buttonLabel, color = Color.White)
                }
            }
        }
    }
}

// MARK: - Waiting Room Modal (matches WaitingRoomView.swift)
@Composable
fun WaitingRoomModal(
    meeting: JsonObject,
    onLeave: () -> Unit
) {
    Dialog(
        onDismissRequest = {},
        properties = DialogProperties(dismissOnBackPress = false, dismissOnClickOutside = false, usePlatformDefaultWidth = false)
    ) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier
                .fillMaxWidth(0.9f)
                .wrapContentHeight()
                .testTag("waiting_room_modal")
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Spacer(Modifier.height(8.dp))
                CircularProgressIndicator(
                    modifier = Modifier.size(48.dp),
                    color = AppColors.brandPrimary,
                    strokeWidth = 3.dp
                )
                Text(
                    text = "Waiting for host…",
                    style = AppTypography.title2,
                    color = AppColors.textPrimary,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "The host will let you in shortly.",
                    style = AppTypography.subheadline,
                    color = AppColors.textSecondary
                )
                Text(
                    text = meeting.text("title"),
                    style = AppTypography.caption1,
                    color = AppColors.textTertiary
                )
                Spacer(Modifier.height(8.dp))
                Button(
                    onClick = onLeave,
                    modifier = Modifier.fillMaxWidth().height(44.dp).testTag("btn_leave_waiting_room"),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusError),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text("Leave waiting room", style = AppTypography.buttonLabel, color = Color.White)
                }
            }
        }
    }
}

// MARK: - Host Controls Panel Modal (matches HostControlsPanel.swift)
@Composable
fun HostControlsModal(
    api: ApiClient,
    meetingId: String,
    initialMeeting: JsonObject? = null,
    onDismiss: () -> Unit,
    onMeetingEnded: () -> Unit
) {
    val remote = rememberRemote(api, "/api/meetings/$meetingId")
    val meeting = if (remote.data.isJsonObject && remote.data.asJsonObject.keySet().isNotEmpty()) remote.data.obj() else (initialMeeting ?: JsonObject())
    val scope = rememberCoroutineScope()
    var selectedParticipantForRole by remember { mutableStateOf<JsonObject?>(null) }

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
                .testTag("host_controls_modal")
        ) {
            Column(Modifier.fillMaxSize().padding(16.dp)) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Host Controls", style = AppTypography.headline, color = AppColors.textPrimary)
                    TextButton(onClick = onDismiss) {
                        Text("Done", style = AppTypography.body, color = AppColors.brandPrimary)
                    }
                }
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle, modifier = Modifier.padding(vertical = 4.dp))

                val participants = meeting.list("participants")
                val waiting = participants.filter {
                    val s = it.text("join_state").ifBlank { it.text("joinState") }
                    s == "waiting"
                }

                LazyColumn(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    // SECTION 1: WAITING ROOM QUEUE
                    if (waiting.isNotEmpty()) {
                        item {
                            Card(
                                shape = RoundedCornerShape(AppRadius.medium),
                                colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                    Text("Waiting room (${waiting.count()})", style = AppTypography.headline, color = AppColors.statusWarning)
                                    waiting.forEach { p ->
                                        val pId = p.text("id").ifBlank { p.id }
                                        val name = p.text("display_name").ifBlank { p.text("name", "Guest") }
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                                Box(
                                                    modifier = Modifier
                                                        .size(32.dp)
                                                        .clip(CircleShape)
                                                        .background(AppColors.statusWarning.copy(alpha = 0.15f)),
                                                    contentAlignment = Alignment.Center
                                                ) {
                                                    Text(name.take(1).uppercase(), style = AppTypography.caption1, color = AppColors.statusWarning)
                                                }
                                                Text(name, style = AppTypography.subheadline, color = AppColors.textPrimary)
                                            }
                                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                                Button(
                                                    onClick = {
                                                        scope.launch {
                                                            api.request("/api/meetings/$meetingId/participants/$pId/admit", "POST")
                                                            remote.refresh()
                                                        }
                                                    },
                                                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusSuccess),
                                                    shape = RoundedCornerShape(AppRadius.small),
                                                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                                    modifier = Modifier.testTag("btn_admit_$pId")
                                                ) {
                                                    Text("Admit", style = AppTypography.caption1, color = Color.White)
                                                }
                                                Button(
                                                    onClick = {
                                                        scope.launch {
                                                            api.request("/api/meetings/$meetingId/participants/$pId/deny", "POST")
                                                            remote.refresh()
                                                        }
                                                    },
                                                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusError),
                                                    shape = RoundedCornerShape(AppRadius.small),
                                                    contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                                                    modifier = Modifier.testTag("btn_deny_$pId")
                                                ) {
                                                    Text("Deny", style = AppTypography.caption1, color = Color.White)
                                                }
                                            }
                                        }
                                        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle.copy(alpha = 0.4f))
                                    }
                                }
                            }
                        }
                    }

                    // SECTION 2: ALL PARTICIPANTS
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text("All participants (${participants.size})", style = AppTypography.headline, color = AppColors.textPrimary)
                                participants.forEach { p ->
                                    val pId = p.text("id").ifBlank { p.id }
                                    val name = p.text("display_name").ifBlank { p.text("name", "Participant") }
                                    val role = p.text("role").ifBlank { "attendee" }
                                    val joinState = p.text("join_state").ifBlank { p.text("joinState", "in_meeting") }

                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable { selectedParticipantForRole = p }
                                            .padding(vertical = 4.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                            Box(
                                                modifier = Modifier
                                                    .size(32.dp)
                                                    .clip(CircleShape)
                                                    .background(AppColors.brandPrimary.copy(alpha = 0.15f)),
                                                contentAlignment = Alignment.Center
                                            ) {
                                                Text(name.take(1).uppercase(), style = AppTypography.caption1, color = AppColors.brandPrimary)
                                            }
                                            Column {
                                                Text(name, style = AppTypography.subheadline, color = AppColors.textPrimary)
                                                Text(role.replaceFirstChar { it.uppercase() }, style = AppTypography.caption2, color = AppColors.textSecondary)
                                            }
                                        }

                                        val (stateText, stateColor) = when (joinState) {
                                            "in_meeting", "inMeeting" -> "in room" to AppColors.statusSuccess
                                            "waiting" -> "waiting" to AppColors.statusWarning
                                            "left" -> "left" to AppColors.textSecondary
                                            "denied" -> "denied" to AppColors.statusError
                                            "removed" -> "removed" to AppColors.statusError
                                            else -> joinState to AppColors.textTertiary
                                        }
                                        Text(stateText, style = AppTypography.caption2, color = stateColor)
                                    }
                                    HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle.copy(alpha = 0.4f))
                                }
                            }
                        }
                    }

                    // SECTION 3: HOST ACTIONS
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                Text("Meeting Actions", style = AppTypography.headline, color = AppColors.textPrimary)
                                Button(
                                    onClick = {
                                        scope.launch {
                                            api.request("/api/meetings/$meetingId/end", "POST")
                                            onDismiss()
                                            onMeetingEnded()
                                        }
                                    },
                                    modifier = Modifier.fillMaxWidth().height(42.dp).testTag("btn_end_meeting_for_all"),
                                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusError),
                                    shape = RoundedCornerShape(AppRadius.small)
                                ) {
                                    Text("End meeting for all", style = AppTypography.subheadline, color = Color.White)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Role & Participant action sheet
    selectedParticipantForRole?.let { p ->
        val pId = p.text("id").ifBlank { p.id }
        val name = p.text("display_name").ifBlank { p.text("name", "Participant") }
        val currentRole = p.text("role")

        AlertDialog(
            onDismissRequest = { selectedParticipantForRole = null },
            title = { Text(name, style = AppTypography.headline) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Change Role:", style = AppTypography.subheadline)
                    listOf("host" to "Host", "co_host" to "Co-host", "presenter" to "Presenter", "attendee" to "Attendee").forEach { (rKey, rLabel) ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    scope.launch {
                                        api.request("/api/meetings/$meetingId/participants/$pId/role", "PUT", json("role" to rKey))
                                        selectedParticipantForRole = null
                                        remote.refresh()
                                    }
                                }
                                .padding(vertical = 6.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(rLabel, style = AppTypography.body, color = AppColors.textPrimary)
                            if (currentRole == rKey) {
                                Icon(Icons.Default.Check, "Selected", tint = AppColors.brandPrimary)
                            }
                        }
                    }
                    HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                    Button(
                        onClick = {
                            scope.launch {
                                api.request("/api/meetings/$meetingId/participants/$pId", "DELETE")
                                selectedParticipantForRole = null
                                remote.refresh()
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusError),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Remove from meeting", style = AppTypography.subheadline, color = Color.White)
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { selectedParticipantForRole = null }) { Text("Cancel") }
            }
        )
    }
}

// MARK: - Meeting Summary & AI Insights Modal (matches MeetingSummaryView.swift)
@Composable
fun MeetingSummaryModal(
    api: ApiClient,
    meetingId: String,
    onDismiss: () -> Unit
) {
    val summaryRemote = rememberRemote(api, "/api/meetings/$meetingId/summary")
    val summary = summaryRemote.data.obj()
    val scope = rememberCoroutineScope()
    var isGenerating by remember { mutableStateOf(false) }
    var newActionItemText by remember { mutableStateOf("") }
    var isAddingActionItem by remember { mutableStateOf(false) }

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
                .testTag("meeting_summary_modal")
        ) {
            Column(Modifier.fillMaxSize().padding(16.dp)) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Meeting Summary", style = AppTypography.headline, color = AppColors.textPrimary)
                    TextButton(onClick = onDismiss) {
                        Text("Done", style = AppTypography.body, color = AppColors.brandPrimary)
                    }
                }
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle, modifier = Modifier.padding(vertical = 4.dp))

                LazyColumn(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    // 1. Summary Card
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth().testTag("card_ai_summary")
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("Summary", style = AppTypography.headline, color = AppColors.textPrimary)
                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                        val src = summary.text("source").ifBlank { "AI" }
                                        Surface(
                                            color = AppColors.brandPrimary.copy(alpha = 0.12f),
                                            shape = RoundedCornerShape(AppRadius.small)
                                        ) {
                                            Text(
                                                src.uppercase(),
                                                style = AppTypography.caption2,
                                                color = AppColors.brandPrimary,
                                                fontWeight = FontWeight.Bold,
                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                            )
                                        }
                                        IconButton(
                                            onClick = {
                                                scope.launch {
                                                    isGenerating = true
                                                    try {
                                                        api.request("/api/meetings/$meetingId/summary", "POST")
                                                        summaryRemote.refresh()
                                                    } finally {
                                                        isGenerating = false
                                                    }
                                                }
                                            },
                                            modifier = Modifier.size(28.dp).testTag("btn_regenerate_summary")
                                        ) {
                                            Icon(Icons.Default.Refresh, "Regenerate", tint = AppColors.brandPrimary, modifier = Modifier.size(18.dp))
                                        }
                                    }
                                }

                                val text = summary.text("summary_text").ifBlank { summary.text("content") }
                                if (text.isNotBlank()) {
                                    Text(text, style = AppTypography.body, color = AppColors.textPrimary)
                                } else {
                                    Column(
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
                                        verticalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        Text("No summary yet.", style = AppTypography.subheadline, color = AppColors.textSecondary)
                                        Button(
                                            onClick = {
                                                scope.launch {
                                                    isGenerating = true
                                                    try {
                                                        api.request("/api/meetings/$meetingId/summary", "POST")
                                                        summaryRemote.refresh()
                                                    } finally {
                                                        isGenerating = false
                                                    }
                                                }
                                            },
                                            colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary),
                                            shape = RoundedCornerShape(AppRadius.small),
                                            modifier = Modifier.testTag("btn_generate_summary")
                                        ) {
                                            if (isGenerating) {
                                                CircularProgressIndicator(modifier = Modifier.size(16.dp), color = Color.White, strokeWidth = 2.dp)
                                            } else {
                                                Icon(Icons.Default.AutoAwesome, null, modifier = Modifier.size(16.dp))
                                                Spacer(Modifier.width(6.dp))
                                                Text("Generate summary", style = AppTypography.caption1)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. Action Items Card
                    val actionItems = summary.list("action_items")
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth().testTag("card_action_items")
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("Action items (${actionItems.size})", style = AppTypography.headline, color = AppColors.textPrimary)
                                if (actionItems.isEmpty()) {
                                    Text("None yet.", style = AppTypography.subheadline, color = AppColors.textSecondary)
                                } else {
                                    actionItems.forEach { item ->
                                        Row(
                                            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                                            verticalAlignment = Alignment.Top,
                                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                                        ) {
                                            Icon(Icons.Default.CheckCircle, null, tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                                Text(item.text("text"), style = AppTypography.body, color = AppColors.textPrimary)
                                                val dueAt = item.text("due_at")
                                                if (dueAt.isNotBlank()) {
                                                    Text("Due ${dateLabel(dueAt)}", style = AppTypography.caption2, color = AppColors.textSecondary)
                                                }
                                                if (item.text("linked_task_id").isNotBlank()) {
                                                    Text("Linked to task", style = AppTypography.caption2, color = AppColors.statusSuccess)
                                                }
                                            }
                                        }
                                        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle.copy(alpha = 0.3f))
                                    }
                                }
                            }
                        }
                    }

                    // 3. Add Action Item Card
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth().testTag("card_add_action_item")
                        ) {
                            Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("Add action item", style = AppTypography.headline, color = AppColors.textPrimary)
                                IosTextField(
                                    label = "Describe a follow-up…",
                                    value = newActionItemText,
                                    onValueChange = { newActionItemText = it },
                                    singleLine = false,
                                    minLines = 2,
                                    modifier = Modifier.testTag("input_action_item")
                                )
                                Button(
                                    onClick = {
                                        val trimmed = newActionItemText.trim()
                                        if (trimmed.isNotBlank()) {
                                            scope.launch {
                                                isAddingActionItem = true
                                                try {
                                                    api.request(
                                                        "/api/meetings/$meetingId/summary/action-items",
                                                        "POST",
                                                        json("text" to trimmed)
                                                    )
                                                    newActionItemText = ""
                                                    summaryRemote.refresh()
                                                } finally {
                                                    isAddingActionItem = false
                                                }
                                            }
                                        }
                                    },
                                    enabled = newActionItemText.trim().isNotBlank() && !isAddingActionItem,
                                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary),
                                    shape = RoundedCornerShape(AppRadius.small),
                                    modifier = Modifier.testTag("btn_add_action_item")
                                ) {
                                    Icon(Icons.Default.Add, null, modifier = Modifier.size(16.dp))
                                    Spacer(Modifier.width(6.dp))
                                    Text("Add", style = AppTypography.caption1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Meeting Detail Screen (matches MeetingDetailView.swift)
@Composable
private fun MeetingDetail(vm: AppViewModel, api: ApiClient, id: String, onBack: () -> Unit) {
    BackHandler(onBack = onBack)
    val remote = rememberRemote(api, "/api/meetings/$id", vm.revision)
    val notes = rememberRemote(api, "/api/meetings/$id/notes", vm.revision)
    val meeting = remote.data.obj()
    val myRole = meeting.child("my_participant").text("role").ifBlank { meeting.child("myParticipant").text("role") }
    val host = myRole in listOf("host", "co_host", "coHost")
    val scope = rememberCoroutineScope()

    var showLobby by remember { mutableStateOf(false) }
    var showWaitingRoom by remember { mutableStateOf(false) }
    var showHostControls by remember { mutableStateOf(false) }
    var showSummary by remember { mutableStateOf(false) }
    var showCancelConfirm by remember { mutableStateOf(false) }
    var editor by remember { mutableStateOf<String?>(null) }
    var ticket by remember { mutableStateOf<JsonObject?>(null) }
    val context = LocalContext.current

    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        // Top Navigation Bar
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
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = AppColors.brandPrimary,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(Modifier.width(4.dp))
                Text("Meetings", style = AppTypography.body, color = AppColors.brandPrimary)
            }
            Text(
                meeting.text("title").ifBlank { "Meeting Details" },
                style = AppTypography.headline,
                color = AppColors.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f).padding(horizontal = 8.dp)
            )

            if (host) {
                IconButton(onClick = { showHostControls = true }, modifier = Modifier.testTag("btn_host_controls_toolbar")) {
                    Icon(Icons.Default.AdminPanelSettings, "Host controls", tint = AppColors.brandPrimary)
                }
            }
            IconButton(
                onClick = {
                    val intent = Intent(Intent.ACTION_INSERT)
                        .setData(CalendarContract.Events.CONTENT_URI)
                        .putExtra(CalendarContract.Events.TITLE, meeting.text("title"))
                        .putExtra(CalendarContract.Events.DESCRIPTION, meeting.text("agenda"))
                    context.startActivity(intent)
                },
                enabled = meeting.id.isNotBlank()
            ) {
                Icon(Icons.Default.Event, "Calendar", tint = AppColors.brandPrimary)
            }
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(remote)

        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // HEADER CARD
            item {
                IosCard(Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        val status = meeting.text("status")
                        Surface(
                            color = when (status) {
                                "in_progress", "inProgress" -> AppColors.statusSuccess.copy(alpha = 0.15f)
                                "scheduled" -> AppColors.brandPrimary.copy(alpha = 0.15f)
                                "ended" -> AppColors.textTertiary.copy(alpha = 0.15f)
                                else -> AppColors.statusError.copy(alpha = 0.15f)
                            },
                            shape = RoundedCornerShape(AppRadius.small)
                        ) {
                            Text(
                                label(status).uppercase(),
                                style = AppTypography.caption2,
                                color = when (status) {
                                    "in_progress", "inProgress" -> AppColors.statusSuccess
                                    "scheduled" -> AppColors.brandPrimary
                                    "ended" -> AppColors.textSecondary
                                    else -> AppColors.statusError
                                },
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp)
                            )
                        }
                        Text(meeting.text("timezone"), style = AppTypography.caption2, color = AppColors.textSecondary)
                    }
                    Spacer(Modifier.height(8.dp))
                    Text(meeting.text("title"), style = AppTypography.title2)
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "${dateLabel(meeting.text("scheduled_start_at"))} - ${dateLabel(meeting.text("scheduled_end_at"))}",
                        style = AppTypography.footnote,
                        color = AppColors.brandPrimary
                    )
                    if (meeting.text("agenda").isNotBlank()) {
                        Spacer(Modifier.height(8.dp))
                        Text(meeting.text("agenda"), style = AppTypography.body, color = AppColors.textPrimary)
                    }
                    if (meeting.text("description").isNotBlank()) {
                        Spacer(Modifier.height(4.dp))
                        Text(meeting.text("description"), style = AppTypography.subheadline, color = AppColors.textSecondary)
                    }
                }
            }

            // PRIMARY ACTIONS
            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        IosButton(
                            title = "Join Meeting",
                            leadingIcon = Icons.Default.VideoCall,
                            onClick = { showLobby = true },
                            modifier = Modifier.weight(1f).height(44.dp).testTag("btn_join_meeting")
                        )
                        if (host) {
                            IosButton(
                                title = "Host Panel",
                                leadingIcon = Icons.Default.Security,
                                variant = IosButtonVariant.Secondary,
                                onClick = { showHostControls = true },
                                modifier = Modifier.weight(1f).height(44.dp).testTag("btn_host_panel")
                            )
                        }
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        IosButton(
                            title = "View Summary",
                            leadingIcon = Icons.Default.Description,
                            variant = IosButtonVariant.Secondary,
                            onClick = { showSummary = true },
                            modifier = Modifier.weight(1f).height(40.dp).testTag("btn_view_summary")
                        )
                        if (host && meeting.text("status") != "ended") {
                            IosButton(
                                title = "Cancel",
                                variant = IosButtonVariant.Destructive,
                                onClick = { showCancelConfirm = true },
                                modifier = Modifier.width(90.dp).height(40.dp)
                            )
                        }
                    }
                }
            }

            // PARTICIPANTS CARD
            item {
                IosSectionHeader("Participants")
                IosInsetGroupedCard {
                    val participants = meeting.list("participants")
                    participants.forEachIndexed { index, participant ->
                        val pRole = participant.text("role")
                        val pName = participant.text("display_name").ifBlank { participant.text("name", "User") }
                        IosGroupedRow(
                            title = pName,
                            subtitle = label(pRole),
                            icon = Icons.Default.Person,
                            showChevron = false,
                            showDivider = index < participants.lastIndex,
                            onClick = {}
                        )
                    }
                }
            }

            // NOTES CARD
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
        }
    }

    // Lobby Modal
    if (showLobby) {
        MeetingLobbyModal(
            meeting = meeting,
            onDismiss = { showLobby = false },
            onJoinSubmitted = { micOn, camOn ->
                showLobby = false
                scope.launch {
                    try {
                        val resp = api.request("/api/meetings/$id/join", "POST")
                        ticket = resp.data.obj()
                        val joinState = ticket?.text("joinState")?.ifBlank { ticket?.text("join_state") }
                        if (joinState == "waiting") {
                            showWaitingRoom = true
                        }
                    } catch (e: Exception) {
                        // error handled
                    }
                }
            }
        )
    }

    // Waiting Room Modal
    if (showWaitingRoom) {
        WaitingRoomModal(
            meeting = meeting,
            onLeave = {
                showWaitingRoom = false
                scope.launch {
                    api.request("/api/meetings/$id/leave", "POST")
                    remote.refresh()
                }
            }
        )
    }

    // Host Controls Modal
    if (showHostControls) {
        HostControlsModal(
            api = api,
            meetingId = id,
            initialMeeting = meeting,
            onDismiss = { showHostControls = false },
            onMeetingEnded = {
                showHostControls = false
                remote.refresh()
                vm.changed()
            }
        )
    }

    // Summary Modal
    if (showSummary) {
        MeetingSummaryModal(
            api = api,
            meetingId = id,
            onDismiss = { showSummary = false }
        )
    }

    // Cancel Meeting Alert
    if (showCancelConfirm) {
        ConfirmDialog(
            title = "Cancel meeting?",
            message = "Are you sure you want to cancel this meeting? Participants will be notified.",
            onDismiss = { showCancelConfirm = false }
        ) {
            scope.launch {
                api.request("/api/meetings/$id", "DELETE")
                showCancelConfirm = false
                remote.refresh()
                vm.changed()
            }
        }
    }

    // Notes Editor
    editor?.let {
        EditorDialog(
            "Edit notes",
            listOf(FormField("content", "Notes", notes.data.obj().text("content"), multiline = true)),
            { editor = null }
        ) { payload ->
            scope.launch {
                api.request("/api/meetings/$id/notes", "PUT", payload)
                editor = null
                notes.refresh()
                vm.changed()
            }
        }
    }

    // In-meeting Call Room
    ticket?.let { room ->
        val joinState = room.text("joinState").ifBlank { room.text("join_state") }
        if (joinState != "waiting") {
            CallRoomDialog(api, room, onDismiss = { ticket = null; vm.changed() })
        }
    }
}
