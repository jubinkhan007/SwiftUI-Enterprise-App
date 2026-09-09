package com.acme.taskflow.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.google.gson.JsonObject
import java.time.Instant

@Composable
fun MessagesScreen(vm: AppViewModel, api: ApiClient, lists: List<Choice>) {
    val remote = rememberRemote(api, "/api/conversations", vm.revision)
    val members = rememberRemote(api, "/api/organizations/${api.orgId}/members")
    var selected by rememberSaveable { mutableStateOf<String?>(null) }
    var search by rememberSaveable { mutableStateOf("") }
    var globalQuery by remember { mutableStateOf("") }
    var create by remember { mutableStateOf(false) }
    val wide = LocalConfiguration.current.screenWidthDp >= 720
    Row(Modifier.fillMaxSize()) {
        if (wide || selected == null) Column(if (wide) Modifier.width(300.dp) else Modifier.fillMaxWidth()) {
            Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(search, { search = it }, label = { Text("Search") }, singleLine = true, modifier = Modifier.weight(1f),
                    trailingIcon = { ToolButton(Icons.Default.Search, "Search all messages") { globalQuery = search.trim() } })
                ToolButton(Icons.Default.Add, "New conversation") { create = true }
            }
            RemoteStatus(remote)
            if (globalQuery.isNotBlank()) {
                val results = rememberRemote(api, "/api/search", query = mapOf("q" to globalQuery))
                RemoteStatus(results)
                TextButton(onClick = { globalQuery = "" }) { Text("Clear results") }
                LazyColumn {
                    items(results.data.rows()) { result ->
                        ListItem(headlineContent = { Text(result.child("message").text("body")) }, supportingContent = { Text(result.text("conversation_name")) },
                            modifier = Modifier.clickable { selected = result.child("message").text("conversation_id"); globalQuery = "" })
                    }
                }
            } else LazyColumn {
                items(remote.data.rows().filter { it.text("name", "Direct message").contains(search, true) }, key = { it.id }) { conversation ->
                    ListItem(headlineContent = { Text(conversation.text("name", "Direct message"), maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        supportingContent = { Text(conversation.child("last_message").text("body"), maxLines = 2, overflow = TextOverflow.Ellipsis) },
                        leadingContent = { AppAvatar(conversation.text("name", "DM")) },
                        trailingContent = { if (conversation.number("unread_count") > 0) Badge { Text(conversation.number("unread_count").toString()) } },
                        modifier = Modifier.clickable { selected = conversation.id })
                    HorizontalDivider()
                }
            }
        }
        if (selected != null) Box(Modifier.weight(1f)) {
            key(selected) { ChatScreen(vm, api, selected!!, lists, onBack = { selected = null }) }
        }
    }
    if (create) EditorDialog("New conversation", listOf(
        FormField("type", "Type", "channel", required = true, options = choices("channel", "dm")),
        FormField("name", "Channel name"),
        FormField("member_id", "Member", options = members.data.rows().filter { it.text("user_id") != vm.user?.id }.map { Choice(it.text("user_id"), it.text("display_name")) })
    ), { create = false }) { payload ->
        val memberId = payload.remove("member_id")?.asString.orEmpty()
        if (payload.text("type") == "dm") require(memberId.isNotBlank()) { "Choose a member for the direct message." }
        else require(payload.text("name").isNotBlank()) { "Enter a channel name." }
        payload.add("member_ids", json("ids" to if (memberId.isBlank()) emptyList<String>() else listOf(memberId)).get("ids"))
        selected = api.request("/api/conversations", "POST", payload).data.obj().id
        vm.changed()
    }
}

@Composable
fun ChatScreen(vm: AppViewModel, api: ApiClient, conversationId: String, lists: List<Choice>, onBack: () -> Unit) {
    var parentId by rememberSaveable { mutableStateOf<String?>(null) }
    var pins by rememberSaveable { mutableStateOf(false) }
    var before by rememberSaveable { mutableStateOf("") }
    var older by remember { mutableStateOf<List<JsonObject>>(emptyList()) }
    val details = rememberRemote(api, "/api/conversations/$conversationId", vm.revision)
    val path = when { parentId != null -> "/api/messages/$parentId/thread"; pins -> "/api/conversations/$conversationId/pins"; else -> "/api/conversations/$conversationId/messages" }
    val remote = rememberRemote(api, path, vm.revision)
    val messages = if (parentId != null) listOf(remote.data.obj().child("root_message")).filter { it.id.isNotBlank() } + remote.data.obj().list("replies")
        else (older + remote.data.rows()).distinctBy { it.id }.sortedBy { it.text("created_at") }
    var body by rememberSaveable(conversationId, parentId) { mutableStateOf("") }
    var messageEditor by remember { mutableStateOf<Pair<String, JsonObject>?>(null) }
    var schedule by remember { mutableStateOf(false) }
    var settings by remember { mutableStateOf(false) }
    var showTemplates by remember { mutableStateOf(false) }
    var callTicket by remember { mutableStateOf<JsonObject?>(null) }
    val action = rememberAction()
    val listState = rememberLazyListState()
    BackHandler { if (parentId != null) parentId = null else onBack() }
    LaunchedEffect(conversationId, parentId) {
        action.run {
            val draft = api.request("/api/conversations/$conversationId/draft", query = parentId?.let { mapOf("parentId" to it) } ?: emptyMap()).data.obj()
            if (body.isBlank()) body = draft.text("body")
        }
    }
    LaunchedEffect(messages.lastOrNull()?.id) {
        if (messages.isNotEmpty()) {
            if (listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index?.let { it >= messages.size - 3 } != false) listState.animateScrollToItem(messages.size - 1)
        }
    }
    Column(Modifier.fillMaxSize().imePadding()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ToolButton(Icons.Default.ArrowBack, "Back") { if (parentId != null) parentId = null else onBack() }
            Text(if (parentId != null) "Thread" else details.data.obj().text("name", "Conversation"), Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            ToolButton(Icons.Default.PushPin, "Pinned messages") { pins = !pins; parentId = null }
            ToolButton(Icons.Default.VideoCall, "Start call", !action.busy) { action.run {
                callTicket = api.request("/api/calls/initiate", "POST", json("conversation_id" to conversationId, "has_video" to true)).data.obj()
            } }
            ToolButton(Icons.Default.Settings, "Conversation settings") { settings = true }
        }
        RemoteStatus(remote); ActionStatus(action)
        if (parentId == null && !pins && remote.data.rows().size >= 50) TextButton(enabled = !action.busy, onClick = { action.run {
            val cursor = older.minByOrNull { it.text("created_at") }?.id ?: messages.firstOrNull()?.id.orEmpty()
            val more = api.request(path, query = mapOf("cursor" to cursor, "limit" to "50")).data.rows()
            older = (more + older).distinctBy { it.id }; before = cursor
        } }) { Text("Load older messages") }
        LazyColumn(Modifier.weight(1f), state = listState, contentPadding = PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(messages, key = { it.id }) { message ->
                var menu by remember { mutableStateOf(false) }
                Column(Modifier.fillMaxWidth().padding(start = if (message.text("sender_id") == vm.user?.id) 24.dp else 0.dp, end = if (message.text("sender_id") == vm.user?.id) 0.dp else 24.dp)) {
                    Surface(shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp), color = if (message.text("sender_id") == vm.user?.id) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.surfaceVariant) {
                        Column(Modifier.fillMaxWidth().padding(12.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(message.text("sender_name"), Modifier.weight(1f), style = MaterialTheme.typography.labelLarge)
                                Box {
                                    ToolButton(Icons.Default.MoreVert, "Message actions", message.text("deleted_at").isBlank()) { menu = true }
                                    DropdownMenu(menu, onDismissRequest = { menu = false }) {
                                        DropdownMenuItem(text = { Text("Reply in thread") }, onClick = { parentId = message.id; menu = false })
                                        listOf("Pin", "Bookmark").forEach { name -> DropdownMenuItem(text = { Text(name) }, onClick = { menu = false; action.run {
                                            val exists = message.flag(if (name == "Pin") "is_pinned" else "is_bookmarked_by_me")
                                            api.request("/api/messages/${message.id}/${name.lowercase()}", if (exists) "DELETE" else "POST"); vm.changed()
                                        } }) }
                                        listOf("React", "Remind me", "Create task").forEach { name -> DropdownMenuItem(text = { Text(name) }, onClick = { messageEditor = name to message; menu = false }) }
                                        if (message.text("sender_id") == vm.user?.id) listOf("Edit", "Delete").forEach { name -> DropdownMenuItem(text = { Text(name) }, onClick = { messageEditor = name to message; menu = false }) }
                                    }
                                }
                            }
                            Text(if (message.text("deleted_at").isNotBlank()) "Message deleted" else message.text("body"))
                            if (message.flag("is_pinned")) Text("Pinned", style = MaterialTheme.typography.labelSmall)
                            message.list("reactions").forEach { reaction -> TextButton(enabled = !action.busy, onClick = { action.run {
                                val emoji = reaction.text("emoji")
                                if (reaction.flag("did_react")) api.request("/api/messages/${message.id}/reactions/${android.net.Uri.encode(emoji)}", "DELETE")
                                else api.request("/api/messages/${message.id}/reactions", "POST", json("emoji" to emoji))
                                vm.changed()
                            } }) { Text("${reaction.text("emoji")} ${reaction.number("count")}") } }
                            if (message.number("reply_count") > 0 && parentId == null) TextButton(onClick = { parentId = message.id }) { Text("${message.number("reply_count")} replies") }
                            Text(dateLabel(message.text("created_at")), style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }
        }
        Row(Modifier.padding(horizontal = 8.dp).horizontalScroll(rememberScrollState())) {
            ToolButton(Icons.Default.Save, "Save draft", !action.busy) { action.run { api.request("/api/conversations/$conversationId/draft", "PUT", json("body" to body, "parent_id" to parentId)); vm.changed() } }
            ToolButton(Icons.Default.ScheduleSend, "Schedule message", body.isNotBlank()) { schedule = true }
            ToolButton(Icons.Default.TextSnippet, "Templates") { showTemplates = true }
            ToolButton(Icons.Default.DoneAll, "Mark conversation read", !action.busy) { action.run { api.request("/api/conversations/$conversationId/read", "POST", json("last_read_message_id" to messages.lastOrNull()?.id)); vm.changed() } }
        }
        Row(Modifier.padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(body, { body = it }, placeholder = { Text(if (parentId == null) "Message" else "Reply") }, modifier = Modifier.weight(1f), maxLines = 5)
            ToolButton(Icons.Default.Send, "Send message", body.isNotBlank() && !action.busy) { action.run {
                api.request("/api/conversations/$conversationId/messages", "POST", json("body" to body.trim(), "message_type" to "text", "parent_id" to parentId))
                body = ""; vm.changed()
            } }
        }
    }
    if (schedule) EditorDialog("Schedule message", listOf(FormField("scheduled_for", "Send at", Instant.now().plusSeconds(3600).toString(), required = true, date = true)), { schedule = false }) { payload ->
        require(Instant.parse(payload.text("scheduled_for")).isAfter(Instant.now())) { "Choose a future time." }
        payload.addProperty("body", body); parentId?.let { payload.addProperty("parent_id", it) }
        api.request("/api/conversations/$conversationId/scheduled-messages", "POST", payload); body = ""; vm.changed()
    }
    if (settings) EditorDialog("Conversation settings", listOf(FormField("name", "Name", details.data.obj().text("name")), FormField("topic", "Topic", details.data.obj().text("topic")), FormField("description", "Description", details.data.obj().text("description"), multiline = true)), { settings = false }) { api.request("/api/conversations/$conversationId", "PUT", it); vm.changed() }
    if (showTemplates) {
        val templates = rememberRemote(api, "/api/templates")
        AlertDialog(onDismissRequest = { showTemplates = false }, title = { Text("Templates") }, text = { Column {
            RemoteStatus(templates)
            templates.data.rows().forEach { template -> TextButton(onClick = { body = template.text("body"); showTemplates = false }) { Text(template.text("name")) } }
        } }, confirmButton = { TextButton(onClick = { showTemplates = false }) { Text("Close") } })
    }
    messageEditor?.let { (name, message) ->
        if (name == "Delete") ConfirmDialog("Delete message?", message.text("body"), { messageEditor = null }) { api.request("/api/messages/${message.id}", "DELETE"); vm.changed() }
        else EditorDialog(name, when (name) {
            "React" -> listOf(FormField("emoji", "Reaction", required = true))
            "Remind me" -> listOf(FormField("remind_at", "Remind at", Instant.now().plusSeconds(3600).toString(), required = true, date = true))
            "Create task" -> listOf(FormField("title", "Title", message.text("body"), required = true), FormField("list_id", "List", lists.firstOrNull()?.value.orEmpty(), required = true, options = lists))
            else -> listOf(FormField("body", "Message", message.text("body"), required = true, multiline = true))
        }, { messageEditor = null }) { payload ->
            val suffix = when (name) { "React" -> "/reactions"; "Remind me" -> "/remind"; "Create task" -> "/convert-to-task"; else -> "" }
            api.request("/api/messages/${message.id}$suffix", if (name == "Edit") "PUT" else "POST", payload); vm.changed()
        }
    }
    callTicket?.let { ticket -> CallRoomDialog(api, ticket, onDismiss = { callTicket = null; vm.changed() }) }
}
