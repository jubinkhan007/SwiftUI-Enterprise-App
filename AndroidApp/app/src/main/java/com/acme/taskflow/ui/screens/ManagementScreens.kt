package com.acme.taskflow.ui.screens

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
import androidx.compose.ui.unit.dp
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.time.Instant

@Composable
fun InboxScreen(vm: AppViewModel, api: ApiClient) {
    var unread by rememberSaveable { mutableStateOf(false) }
    val remote = rememberRemote(api, "/api/notifications", vm.revision, query = mapOf("unread" to unread.toString()), paged = true)
    val action = rememberAction()
    Column {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("Unread only", Modifier.weight(1f)); Switch(unread, { unread = it })
        }
        RemoteStatus(remote); ActionStatus(action)
        LazyColumn {
            if (!remote.loading && remote.error == null && remote.data.rows().isEmpty()) item { Text("You're all caught up.", Modifier.padding(24.dp)) }
            items(remote.data.rows(), key = { it.id }) { item ->
                val payload = runCatching { JsonParser.parseString(item.text("payload_json")).obj() }.getOrDefault(JsonObject())
                ListItem(headlineContent = { Text(payload.text("title", label(item.text("type")))) },
                    supportingContent = { Text("${payload.text("body", payload.text("message"))}\n${dateLabel(item.text("created_at"))}") },
                    leadingContent = { Icon(Icons.Default.Notifications, null) },
                    trailingContent = { if (item.text("read_at").isBlank()) ToolButton(Icons.Default.Done, "Mark read", !action.busy) { action.run { api.request("/api/notifications/${item.id}/read", "POST"); vm.changed() } } })
                HorizontalDivider()
            }
        }
    }
}

@Composable
fun SessionsScreen(vm: AppViewModel, api: ApiClient) {
    val remote = rememberRemote(api, "/api/me/sessions", vm.revision)
    var selected by remember { mutableStateOf<JsonObject?>(null) }
    Column {
        RemoteStatus(remote)
        LazyColumn {
            items(remote.data.rows(), key = { it.id }) { session ->
                ListItem(headlineContent = { Text(session.text("device_type", "Device")) },
                    supportingContent = { Text("${session.text("ip_address")}\n${session.text("user_agent")}\nExpires ${dateLabel(session.text("expires_at"))}") },
                    leadingContent = { Icon(Icons.Default.Devices, null) },
                    trailingContent = { ToolButton(Icons.Default.Logout, "Revoke session") { selected = session } })
                HorizontalDivider()
            }
        }
    }
    selected?.let { session -> ConfirmDialog("Revoke session?", "This device will need to sign in again.", { selected = null }) {
        api.request("/api/me/sessions/${session.id}", "DELETE"); vm.changed()
    } }
}

@Composable
fun TeamScreen(vm: AppViewModel, api: ApiClient) {
    val remote = rememberRemote(api, "/api/organizations/${api.orgId}/members", vm.revision)
    val me = rememberRemote(api, "/api/me")
    val permissions = me.data.obj().child("permissions").getAsJsonArray("permissions")?.map { it.asString }.orEmpty()
    var editor by remember { mutableStateOf<Pair<String, JsonObject>?>(null) }
    val action = rememberAction()
    val admin = me.data.obj().text("role") in listOf("owner", "admin")
    Column {
        Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("${remote.data.rows().size} members", Modifier.weight(1f))
            ToolButton(Icons.Default.PersonAdd, "Invite member", "members.invite" in permissions) { editor = "Invite member" to JsonObject() }
        }
        RemoteStatus(remote); ActionStatus(action)
        LazyColumn {
            items(remote.data.rows(), key = { it.id }) { member ->
                ListItem(headlineContent = { Text(member.text("display_name")) }, supportingContent = { Text("${member.text("email")}\n${label(member.text("role"))}") },
                    leadingContent = { AppAvatar(member.text("display_name")) }, trailingContent = {
                        if (admin && member.text("role") != "owner") Row {
                            ToolButton(Icons.Default.Edit, "Change role") { editor = "Change role" to member }
                            ToolButton(Icons.Default.PersonRemove, "Remove member") { editor = "Remove member" to member }
                        }
                    })
            }
            if (admin) item {
                val requests = rememberRemote(api, "/api/organizations/${api.orgId}/join-requests", vm.revision)
                Text("Join requests", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(16.dp))
                RemoteStatus(requests)
                requests.data.rows().forEach { request ->
                    ListItem(headlineContent = { Text(request.text("display_name", request.text("user_display_name", request.text("email")))) }, trailingContent = {
                        Row {
                            ToolButton(Icons.Default.Check, "Approve request", !action.busy) { action.run { api.request("/api/organizations/join-requests/${request.id}/respond", "POST", json("action" to "accept")); vm.changed() } }
                            ToolButton(Icons.Default.Close, "Reject request", !action.busy) { action.run { api.request("/api/organizations/join-requests/${request.id}/respond", "POST", json("action" to "reject")); vm.changed() } }
                        }
                    })
                }
            }
        }
    }
    editor?.let { (title, member) ->
        if (title == "Remove member") ConfirmDialog("Remove member?", member.text("display_name"), { editor = null }) {
            api.request("/api/organizations/${api.orgId}/members/${member.id}", "DELETE"); vm.changed()
        } else EditorDialog(title, (if (title == "Invite member") listOf(FormField("email", "Email", required = true)) else emptyList()) +
            FormField("role", "Role", member.text("role", "member"), required = true, options = choices("guest", "viewer", "member", "manager", "admin")), { editor = null }) {
            api.request(if (title == "Invite member") "/api/organizations/${api.orgId}/invites" else "/api/organizations/${api.orgId}/members/${member.id}/role", if (title == "Invite member") "POST" else "PUT", it); vm.changed()
        }
    }
}

@Composable
fun ProductivityScreen(vm: AppViewModel, api: ApiClient) {
    var tab by rememberSaveable { mutableStateOf("Drafts") }
    var editor by remember { mutableStateOf<JsonObject?>(null) }
    var remove by remember { mutableStateOf<JsonObject?>(null) }
    val path = when (tab) { "Templates" -> "/api/templates"; "Reminders" -> "/api/me/reminders"; "Scheduled" -> "/api/me/scheduled-messages"; "Bookmarks" -> "/api/me/bookmarks"; else -> "/api/me/drafts" }
    val remote = rememberRemote(api, path, vm.revision)
    val action = rememberAction()
    Column {
        Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("Drafts", "Templates", "Reminders", "Scheduled", "Bookmarks").forEach { name -> FilterChip(tab == name, { tab = name }, label = { Text(name) }) }
        }
        Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(tab, Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            if (tab in listOf("Templates", "Reminders")) ToolButton(Icons.Default.Add, "Create ${tab.lowercase()}") { editor = JsonObject() }
        }
        RemoteStatus(remote); ActionStatus(action)
        LazyColumn {
            if (!remote.loading && remote.error == null && remote.data.rows().isEmpty()) item { Text("No ${tab.lowercase()}.", Modifier.padding(24.dp)) }
            items(remote.data.rows(), key = { it.id }) { item ->
                Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                    Text(item.text("name", item.text("body", item.child("message").text("body"))), style = MaterialTheme.typography.titleSmall)
                    if (tab == "Templates") Text(item.text("body"))
                    Text(dateLabel(item.text("remind_at", item.text("scheduled_for", item.text("updated_at")))), style = MaterialTheme.typography.bodySmall)
                    Text(label(item.text("status")), style = MaterialTheme.typography.labelSmall)
                    Row {
                        if (tab != "Bookmarks") ToolButton(Icons.Default.Edit, "Edit", !action.busy) { editor = item }
                        ToolButton(Icons.Default.Delete, "Delete", !action.busy) { remove = item }
                        if (tab == "Reminders") {
                            ToolButton(Icons.Default.Snooze, "Snooze 30 minutes", !action.busy) { action.run { api.request("/api/reminders/${item.id}/snooze", "POST", json("minutes" to 30)); vm.changed() } }
                            ToolButton(Icons.Default.Done, "Dismiss reminder", !action.busy) { action.run { api.request("/api/reminders/${item.id}/dismiss", "POST"); vm.changed() } }
                        }
                        if (tab == "Scheduled" && item.text("status") in listOf("pending", "queued")) ToolButton(Icons.Default.Send, "Send now", !action.busy) { action.run { api.request("/api/scheduled-messages/${item.id}/send-now", "POST"); vm.changed() } }
                    }
                }
                HorizontalDivider()
            }
        }
    }
    editor?.let { item ->
        val fields = mutableListOf<FormField>()
        if (tab == "Templates") fields += listOf(FormField("name", "Name", item.text("name"), required = true), FormField("shortcut", "Shortcut", item.text("shortcut")))
        fields += FormField("body", "Body", item.text("body"), required = true, multiline = true)
        if (tab in listOf("Reminders", "Scheduled")) fields += FormField(if (tab == "Reminders") "remind_at" else "scheduled_for", "Date", item.text(if (tab == "Reminders") "remind_at" else "scheduled_for", Instant.now().plusSeconds(3600).toString()), required = true, date = true)
        EditorDialog(if (item.id.isBlank()) "Create" else "Edit", fields, { editor = null }) { payload ->
            val target = when (tab) {
                "Templates" -> if (item.id.isBlank()) "/api/templates" else "/api/templates/${item.id}"
                "Reminders" -> if (item.id.isBlank()) "/api/me/reminders" else "/api/reminders/${item.id}"
                "Scheduled" -> "/api/scheduled-messages/${item.id}"
                else -> "/api/conversations/${item.text("conversation_id")}/draft"
            }
            if (tab == "Templates" && item.id.isBlank()) payload.addProperty("scope", "personal")
            if (tab == "Drafts" && item.text("parent_id").isNotEmpty()) payload.addProperty("parent_id", item.text("parent_id"))
            api.request(target, if (item.id.isBlank()) "POST" else "PUT", payload); vm.changed()
        }
    }
    remove?.let { item -> ConfirmDialog("Delete item?", item.text("name", item.text("body", "Remove this saved item.")), { remove = null }) {
        val target = when (tab) {
            "Templates" -> "/api/templates/${item.id}"
            "Reminders" -> "/api/reminders/${item.id}"
            "Scheduled" -> "/api/scheduled-messages/${item.id}"
            "Bookmarks" -> "/api/messages/${item.text("message_id")}/bookmark"
            else -> "/api/conversations/${item.text("conversation_id")}/draft"
        }
        api.request(target, "DELETE", query = if (tab == "Drafts" && item.text("parent_id").isNotEmpty()) mapOf("parentId" to item.text("parent_id")) else emptyMap()); vm.changed()
    } }
}
