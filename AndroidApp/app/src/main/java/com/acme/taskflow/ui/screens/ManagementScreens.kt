package com.acme.taskflow.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.time.Instant
import kotlinx.coroutines.isActive

@Composable
fun InboxScreen(vm: AppViewModel, api: ApiClient) {
    var unread by rememberSaveable { mutableStateOf(false) }
    val remote = rememberRemote(api, "/api/notifications", vm.revision, query = mapOf("unread" to unread.toString()), paged = true)
    val action = rememberAction()

    LaunchedEffect(Unit) {
        while (kotlinx.coroutines.currentCoroutineContext().isActive) {
            kotlinx.coroutines.delay(3000)
            vm.changed()
        }
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
                    text = "Inbox",
                    style = AppTypography.largeTitle,
                    color = AppColors.textPrimary,
                    modifier = Modifier.weight(1f)
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text("Unread only", style = AppTypography.caption1, color = AppColors.textSecondary)
                    Switch(
                        checked = unread,
                        onCheckedChange = { unread = it },
                        colors = SwitchDefaults.colors(checkedThumbColor = Color.White, checkedTrackColor = AppColors.brandPrimary)
                    )
                }
            }
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(remote)
        ActionStatus(action)

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            if (!remote.loading && remote.error == null && remote.data.rows().isEmpty()) {
                item {
                    Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Icon(Icons.Default.NotificationsNone, null, tint = AppColors.brandPrimary, modifier = Modifier.size(44.dp))
                            Text("All caught up!", style = AppTypography.headline)
                            Text("You have no notifications.", style = AppTypography.caption1, color = AppColors.textSecondary)
                        }
                    }
                }
            }
            items(remote.data.rows(), key = { it.id }) { item ->
                val payload = runCatching { JsonParser.parseString(item.text("payload_json")).obj() }.getOrDefault(JsonObject())
                val isUnread = item.text("read_at").isBlank()
                val callerName = payload.text("actorName", "Team Member")
                val itemType = item.text("type")
                val titleText = if (itemType == "call.incoming") "Incoming Video Call" else item.text("title").ifBlank { payload.text("title", label(itemType)) }
                val bodyText = if (itemType == "call.incoming") "$callerName is calling you..." else item.text("body").ifBlank { payload.text("body", payload.text("message")) }

                IosCard(modifier = Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.Top) {
                        if (isUnread) {
                            Box(
                                modifier = Modifier
                                    .padding(top = 6.dp, end = 10.dp)
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(AppColors.brandPrimary)
                            )
                        }
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(RoundedCornerShape(AppRadius.small))
                                .background(AppColors.brandPrimary.copy(alpha = 0.12f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.Notifications, null, tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                            Text(titleText, style = AppTypography.headline)
                            Text(bodyText, style = AppTypography.subheadline, color = AppColors.textSecondary)
                            Text(dateLabel(item.text("created_at")), style = AppTypography.caption2, color = AppColors.textTertiary, modifier = Modifier.padding(top = 4.dp))
                        }
                        if (isUnread) {
                            IconButton(
                                onClick = {
                                    action.run {
                                        api.request("/api/notifications/${item.id}/read", "POST")
                                        vm.changed()
                                    }
                                },
                                enabled = !action.busy
                            ) {
                                Icon(Icons.Default.Done, "Mark read", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun SessionsScreen(vm: AppViewModel, api: ApiClient) {
    val remote = rememberRemote(api, "/api/me/sessions", vm.revision)
    var selected by remember { mutableStateOf<JsonObject?>(null) }

    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text("Active Sessions", style = AppTypography.largeTitle, color = AppColors.textPrimary)
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(remote)

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(remote.data.rows(), key = { it.id }) { session ->
                IosCard(Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(RoundedCornerShape(AppRadius.small))
                                .background(AppColors.brandPrimary.copy(alpha = 0.12f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.Devices, null, tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(session.text("device_type", "Device"), style = AppTypography.headline)
                            Text(session.text("ip_address"), style = AppTypography.caption1, color = AppColors.textSecondary)
                            Text("Expires ${dateLabel(session.text("expires_at"))}", style = AppTypography.caption2, color = AppColors.textTertiary)
                        }
                        IconButton(onClick = { selected = session }) {
                            Icon(Icons.AutoMirrored.Filled.Logout, "Revoke session", tint = AppColors.statusError, modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }
        }
    }

    selected?.let { session ->
        ConfirmDialog("Revoke session?", "This device will need to sign in again.", { selected = null }) {
            api.request("/api/me/sessions/${session.id}", "DELETE")
            vm.changed()
        }
    }
}

@Composable
fun TeamScreen(vm: AppViewModel, api: ApiClient) {
    val remote = rememberRemote(api, "/api/organizations/${api.orgId}/members", vm.revision)
    val me = rememberRemote(api, "/api/me", query = mapOf("org_id" to api.orgId))
    val permissions = me.data.obj().child("permissions").getAsJsonArray("permissions")?.map { it.asString }.orEmpty()
    var editor by remember { mutableStateOf<Pair<String, JsonObject>?>(null) }
    val action = rememberAction()
    val admin = me.data.obj().text("role") in listOf("owner", "admin")

    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Team Management", style = AppTypography.largeTitle, color = AppColors.textPrimary, modifier = Modifier.weight(1f))
                if ("members.invite" in permissions) {
                    IconButton(
                        onClick = { editor = "Invite member" to JsonObject() },
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                    ) {
                        Icon(Icons.Default.PersonAdd, "Invite member", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                    }
                }
            }
            Text("${remote.data.rows().size} team members", style = AppTypography.caption1, color = AppColors.textSecondary)
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(remote)
        ActionStatus(action)

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(remote.data.rows(), key = { it.id }) { member ->
                IosCard(modifier = Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        AppAvatar(member.text("display_name"))
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(member.text("display_name"), style = AppTypography.headline)
                            Text(member.text("email"), style = AppTypography.caption1, color = AppColors.textSecondary)
                            IosPill(label(member.text("role")), selected = member.text("role") in listOf("owner", "admin"))
                        }
                        if (admin && member.text("user_id") != vm.user?.id) {
                            IconButton(onClick = { editor = "Edit member" to member }) {
                                Icon(Icons.Default.MoreVert, "Actions", tint = AppColors.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    editor?.let { (title, member) ->
        val fields = if (title == "Invite member") listOf(
            FormField("email", "Email", required = true),
            FormField("role", "Role", "member", required = true, options = choices("member", "admin", "viewer"))
        ) else listOf(
            FormField("role", "Role", member.text("role"), required = true, options = choices("member", "admin", "viewer"))
        )
        EditorDialog(title, fields, { editor = null }) { payload ->
            if (title == "Invite member") {
                api.request("/api/organizations/${api.orgId}/invites", "POST", payload)
            } else {
                api.request("/api/organizations/${api.orgId}/members/${member.id}", "PATCH", payload)
            }
            vm.changed()
        }
    }
}

@Composable
fun ProductivityScreen(vm: AppViewModel, api: ApiClient) {
    var tab by rememberSaveable { mutableStateOf("Reminders") }
    val path = when (tab) {
        "Reminders" -> "/api/reminders"
        "Scheduled" -> "/api/scheduled-messages"
        else -> "/api/templates"
    }
    val remote = rememberRemote(api, path, vm.revision)
    val action = rememberAction()
    var editor by remember { mutableStateOf<String?>(null) }

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
                Text("Productivity Hub", style = AppTypography.largeTitle, color = AppColors.textPrimary, modifier = Modifier.weight(1f))
                IconButton(
                    onClick = { editor = tab },
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                ) {
                    Icon(Icons.Default.Add, "Create", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("Reminders", "Scheduled", "Templates").forEach { name ->
                    IosFilterChip(
                        title = name,
                        isSelected = tab == name,
                        onClick = { tab = name }
                    )
                }
            }
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(remote)
        ActionStatus(action)

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            if (!remote.loading && remote.error == null && remote.data.rows().isEmpty()) {
                item {
                    Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                        Text("No items in $tab.", style = AppTypography.body, color = AppColors.textSecondary)
                    }
                }
            }
            items(remote.data.rows(), key = { it.id }) { item ->
                IosCard(modifier = Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(item.text("title", item.text("name", item.text("body"))), style = AppTypography.headline)
                            Text(dateLabel(item.text("remind_at", item.text("scheduled_for", item.text("created_at")))), style = AppTypography.caption1, color = AppColors.textSecondary)
                        }
                        IconButton(onClick = {
                            action.run {
                                api.request("$path/${item.id}", "DELETE")
                                vm.changed()
                            }
                        }) {
                            Icon(Icons.Default.Delete, "Delete", tint = AppColors.statusError, modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }
        }
    }

    editor?.let { title ->
        val fields = when (title) {
            "Reminders" -> listOf(
                FormField("title", "Title", required = true),
                FormField("remind_at", "Remind at", Instant.now().plusSeconds(3600).toString(), required = true, date = true)
            )
            "Scheduled" -> listOf(
                FormField("body", "Message", required = true, multiline = true),
                FormField("scheduled_for", "Send at", Instant.now().plusSeconds(3600).toString(), required = true, date = true)
            )
            else -> listOf(
                FormField("name", "Name", required = true),
                FormField("body", "Template Body", required = true, multiline = true)
            )
        }
        EditorDialog("Create $title", fields, { editor = null }) { payload ->
            api.request(path, "POST", payload)
            vm.changed()
        }
    }
}
