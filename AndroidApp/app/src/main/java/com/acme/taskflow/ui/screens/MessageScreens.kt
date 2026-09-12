package com.acme.taskflow.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
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
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*
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

    Row(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        if (wide || selected == null) {
            Column(
                modifier = (if (wide) Modifier.width(320.dp) else Modifier.fillMaxWidth())
                    .fillMaxHeight()
                    .background(AppColors.backgroundSecondary)
            ) {
                // Header & Search
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
                            text = "Messages",
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
                            Icon(Icons.Default.Add, "New conversation", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                        }
                    }

                    IosTextField(
                        label = "Search messages...",
                        value = search,
                        onValueChange = { search = it },
                        singleLine = true,
                        trailingIcon = {
                            IconButton(onClick = { globalQuery = search.trim() }) {
                                Icon(Icons.Default.Search, "Search", tint = AppColors.brandPrimary)
                            }
                        }
                    )
                }

                RemoteStatus(remote)

                if (globalQuery.isNotBlank()) {
                    val results = rememberRemote(api, "/api/search", query = mapOf("q" to globalQuery))
                    RemoteStatus(results)
                    Row(Modifier.padding(horizontal = 16.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("Search Results", style = AppTypography.headline, modifier = Modifier.weight(1f))
                        TextButton(onClick = { globalQuery = "" }) {
                            Text("Clear", color = AppColors.brandPrimary)
                        }
                    }
                    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        items(results.data.rows()) { result ->
                            IosCard(
                                modifier = Modifier.fillMaxWidth(),
                                onClick = {
                                    selected = result.child("message").text("conversation_id")
                                    globalQuery = ""
                                }
                            ) {
                                Text(result.text("conversation_name"), style = AppTypography.headline)
                                Text(result.child("message").text("body"), style = AppTypography.subheadline, color = AppColors.textSecondary)
                            }
                        }
                    }
                } else {
                    val filtered = remote.data.rows().filter { it.text("name", "Direct message").contains(search, true) }
                    if (!remote.loading && filtered.isEmpty()) {
                        Box(Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
                            Text("No conversations yet.", style = AppTypography.body, color = AppColors.textSecondary)
                        }
                    } else {
                        LazyColumn(
                            contentPadding = PaddingValues(16.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(filtered, key = { it.id }) { conversation ->
                                IosCard(
                                    modifier = Modifier.fillMaxWidth(),
                                    onClick = { selected = conversation.id }
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        AppAvatar(conversation.text("name", "DM"))
                                        Spacer(Modifier.width(12.dp))
                                        Column(Modifier.weight(1f)) {
                                            Text(
                                                conversation.text("name", "Direct message"),
                                                style = AppTypography.headline,
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis
                                            )
                                            val lastBody = conversation.child("last_message").text("body")
                                            if (lastBody.isNotBlank()) {
                                                Text(
                                                    lastBody,
                                                    style = AppTypography.caption1,
                                                    color = AppColors.textSecondary,
                                                    maxLines = 1,
                                                    overflow = TextOverflow.Ellipsis
                                                )
                                            }
                                        }
                                        if (conversation.number("unread_count") > 0) {
                                            Box(
                                                modifier = Modifier
                                                    .clip(RoundedCornerShape(AppRadius.pill))
                                                    .background(AppColors.brandPrimary)
                                                    .padding(horizontal = 8.dp, vertical = 2.dp),
                                                contentAlignment = Alignment.Center
                                            ) {
                                                Text(
                                                    conversation.number("unread_count").toString(),
                                                    style = AppTypography.caption2.copy(fontWeight = FontWeight.Bold),
                                                    color = Color.White
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
        }

        if (selected != null) {
            Box(Modifier.weight(1f)) {
                key(selected) {
                    ChatScreen(vm, api, selected!!, lists, onBack = { selected = null })
                }
            }
        }
    }

    if (create) {
        EditorDialog(
            "New conversation",
            listOf(
                FormField("type", "Type", "channel", required = true, options = choices("channel", "dm")),
                FormField("name", "Channel name"),
                FormField("member_id", "Member", options = members.data.rows().filter { it.text("user_id") != vm.user?.id }.map { Choice(it.text("user_id"), it.text("display_name")) })
            ),
            { create = false }
        ) { payload ->
            val memberId = payload.remove("member_id")?.asString.orEmpty()
            if (payload.text("type") == "dm") require(memberId.isNotBlank()) { "Choose a member for the direct message." }
            else require(payload.text("name").isNotBlank()) { "Enter a channel name." }
            payload.add("member_ids", json("ids" to if (memberId.isBlank()) emptyList<String>() else listOf(memberId)).get("ids"))
            selected = api.request("/api/conversations", "POST", payload).data.obj().id
            vm.changed()
        }
    }
}

@Composable
fun ChatScreen(vm: AppViewModel, api: ApiClient, conversationId: String, lists: List<Choice>, onBack: () -> Unit) {
    var parentId by rememberSaveable { mutableStateOf<String?>(null) }
    var pins by rememberSaveable { mutableStateOf(false) }
    var before by rememberSaveable { mutableStateOf("") }
    var older by remember { mutableStateOf<List<JsonObject>>(emptyList()) }
    val details = rememberRemote(api, "/api/conversations/$conversationId", vm.revision)
    val path = when {
        parentId != null -> "/api/messages/$parentId/thread"
        pins -> "/api/conversations/$conversationId/pins"
        else -> "/api/conversations/$conversationId/messages"
    }
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
            if (listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index?.let { it >= messages.size - 3 } != false) {
                listState.animateScrollToItem(messages.size - 1)
            }
        }
    }

    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary).imePadding()) {
        // iOS Navigation Top Bar
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
                    .clickable { if (parentId != null) parentId = null else onBack() }
                    .padding(horizontal = 8.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.ChevronLeft,
                    contentDescription = "Back",
                    tint = AppColors.brandPrimary,
                    modifier = Modifier.size(28.dp)
                )
                Text(
                    text = if (parentId != null) "Thread" else "Messages",
                    style = AppTypography.body,
                    color = AppColors.brandPrimary
                )
            }

            Text(
                text = if (parentId != null) "Thread" else details.data.obj().text("name", "Conversation"),
                style = AppTypography.headline,
                color = AppColors.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f).padding(horizontal = 8.dp)
            )

            IconButton(onClick = { pins = !pins; parentId = null }) {
                Icon(Icons.Default.PushPin, "Pinned", tint = if (pins) AppColors.brandPrimary else AppColors.textSecondary)
            }
            IconButton(
                onClick = {
                    action.run {
                        callTicket = api.request("/api/calls/initiate", "POST", json("conversation_id" to conversationId, "has_video" to true)).data.obj()
                    }
                },
                enabled = !action.busy
            ) {
                Icon(Icons.Default.VideoCall, "Start call", tint = AppColors.brandPrimary)
            }
            IconButton(onClick = { settings = true }) {
                Icon(Icons.Default.Settings, "Settings", tint = AppColors.textSecondary)
            }
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(remote)
        ActionStatus(action)

        if (parentId == null && !pins && remote.data.rows().size >= 50) {
            TextButton(
                enabled = !action.busy,
                onClick = {
                    action.run {
                        val cursor = older.minByOrNull { it.text("created_at") }?.id ?: messages.firstOrNull()?.id.orEmpty()
                        val more = api.request(path, query = mapOf("cursor" to cursor, "limit" to "50")).data.rows()
                        older = (more + older).distinctBy { it.id }
                        before = cursor
                    }
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Load older messages", style = AppTypography.caption1, color = AppColors.brandPrimary)
            }
        }

        // Messages list with iOS chat bubble aesthetics
        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            state = listState,
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(messages, key = { it.id }) { message ->
                val isMe = message.text("sender_id") == vm.user?.id
                var menu by remember { mutableStateOf(false) }

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = if (isMe) Alignment.End else Alignment.Start
                ) {
                    if (!isMe) {
                        Text(
                            text = message.text("sender_name"),
                            style = AppTypography.caption2,
                            color = AppColors.textTertiary,
                            modifier = Modifier.padding(start = 12.dp, bottom = 2.dp)
                        )
                    }

                    Box(
                        modifier = Modifier
                            .widthIn(max = 280.dp)
                            .clip(
                                RoundedCornerShape(
                                    topStart = 16.dp,
                                    topEnd = 16.dp,
                                    bottomStart = if (isMe) 16.dp else 4.dp,
                                    bottomEnd = if (isMe) 4.dp else 16.dp
                                )
                            )
                            .background(if (isMe) AppColors.brandPrimary else AppColors.surfaceElevated)
                            .clickable { menu = true }
                            .padding(horizontal = 14.dp, vertical = 10.dp)
                    ) {
                        Column {
                            Text(
                                text = if (message.text("deleted_at").isNotBlank()) "Message deleted" else message.text("body"),
                                style = AppTypography.body,
                                color = if (isMe) Color.White else AppColors.textPrimary
                            )
                            if (message.flag("is_pinned")) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.padding(top = 4.dp)
                                ) {
                                    Icon(Icons.Default.PushPin, null, tint = if (isMe) Color.White.copy(alpha = 0.8f) else AppColors.textTertiary, modifier = Modifier.size(12.dp))
                                    Text("Pinned", style = AppTypography.caption2, color = if (isMe) Color.White.copy(alpha = 0.8f) else AppColors.textTertiary)
                                }
                            }
                            Text(
                                text = dateLabel(message.text("created_at")),
                                style = AppTypography.caption2,
                                color = if (isMe) Color.White.copy(alpha = 0.7f) else AppColors.textTertiary,
                                modifier = Modifier.padding(top = 4.dp)
                            )
                        }

                        DropdownMenu(menu, onDismissRequest = { menu = false }) {
                            DropdownMenuItem(text = { Text("Reply in thread") }, onClick = { parentId = message.id; menu = false })
                            listOf("Pin", "Bookmark").forEach { name ->
                                DropdownMenuItem(
                                    text = { Text(name) },
                                    onClick = {
                                        menu = false
                                        action.run {
                                            val exists = message.flag(if (name == "Pin") "is_pinned" else "is_bookmarked_by_me")
                                            api.request("/api/messages/${message.id}/${name.lowercase()}", if (exists) "DELETE" else "POST")
                                            vm.changed()
                                        }
                                    }
                                )
                            }
                            listOf("React", "Remind me", "Create task").forEach { name ->
                                DropdownMenuItem(text = { Text(name) }, onClick = { messageEditor = name to message; menu = false })
                            }
                            if (isMe) {
                                listOf("Edit", "Delete").forEach { name ->
                                    DropdownMenuItem(text = { Text(name) }, onClick = { messageEditor = name to message; menu = false })
                                }
                            }
                        }
                    }

                    if (message.list("reactions").isNotEmpty()) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            modifier = Modifier.padding(top = 2.dp)
                        ) {
                            message.list("reactions").forEach { reaction ->
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(AppRadius.pill))
                                        .background(AppColors.surfaceElevated)
                                        .border(BorderStroke(0.5.dp, AppColors.borderSubtle), RoundedCornerShape(AppRadius.pill))
                                        .clickable {
                                            action.run {
                                                val emoji = reaction.text("emoji")
                                                if (reaction.flag("did_react")) api.request("/api/messages/${message.id}/reactions/${android.net.Uri.encode(emoji)}", "DELETE")
                                                else api.request("/api/messages/${message.id}/reactions", "POST", json("emoji" to emoji))
                                                vm.changed()
                                            }
                                        }
                                        .padding(horizontal = 8.dp, vertical = 2.dp)
                                ) {
                                    Text("${reaction.text("emoji")} ${reaction.number("count")}", style = AppTypography.caption2)
                                }
                            }
                        }
                    }

                    if (message.number("reply_count") > 0 && parentId == null) {
                        Text(
                            text = "${message.number("reply_count")} replies",
                            style = AppTypography.caption1.copy(fontWeight = FontWeight.SemiBold),
                            color = AppColors.brandPrimary,
                            modifier = Modifier.clickable { parentId = message.id }.padding(top = 2.dp)
                        )
                    }
                }
            }
        }

        // Action icons row (Draft, Schedule, Templates)
        Row(
            Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 8.dp, vertical = 2.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            IconButton(onClick = {
                action.run {
                    api.request("/api/conversations/$conversationId/draft", "PUT", json("body" to body, "parent_id" to parentId))
                    vm.changed()
                }
            }) {
                Icon(Icons.Default.Save, "Save draft", tint = AppColors.textSecondary, modifier = Modifier.size(20.dp))
            }
            IconButton(onClick = { schedule = true }, enabled = body.isNotBlank()) {
                Icon(Icons.Default.ScheduleSend, "Schedule", tint = if (body.isNotBlank()) AppColors.brandPrimary else AppColors.textTertiary, modifier = Modifier.size(20.dp))
            }
            IconButton(onClick = { showTemplates = true }) {
                Icon(Icons.Default.TextSnippet, "Templates", tint = AppColors.textSecondary, modifier = Modifier.size(20.dp))
            }
        }

        // Input bar
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(AppRadius.large))
                    .background(AppColors.surfaceElevated)
                    .border(BorderStroke(1.dp, AppColors.borderDefault), RoundedCornerShape(AppRadius.large))
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(Modifier.weight(1f)) {
                    if (body.isEmpty()) {
                        Text(
                            text = if (parentId == null) "Message..." else "Reply...",
                            style = AppTypography.body,
                            color = AppColors.textTertiary
                        )
                    }
                    BasicTextField(
                        value = body,
                        onValueChange = { body = it },
                        textStyle = AppTypography.body.copy(color = AppColors.textPrimary),
                        modifier = Modifier.fillMaxWidth(),
                        maxLines = 5
                    )
                }
                IconButton(
                    onClick = {
                        action.run {
                            api.request("/api/conversations/$conversationId/messages", "POST", json("body" to body.trim(), "message_type" to "text", "parent_id" to parentId))
                            body = ""
                            vm.changed()
                        }
                    },
                    enabled = body.isNotBlank() && !action.busy,
                    modifier = Modifier.size(32.dp)
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send",
                        tint = if (body.isNotBlank() && !action.busy) AppColors.brandPrimary else AppColors.textTertiary,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }

    if (schedule) {
        EditorDialog(
            "Schedule message",
            listOf(FormField("scheduled_for", "Send at", Instant.now().plusSeconds(3600).toString(), required = true, date = true)),
            { schedule = false }
        ) { payload ->
            require(Instant.parse(payload.text("scheduled_for")).isAfter(Instant.now())) { "Choose a future time." }
            payload.addProperty("body", body)
            parentId?.let { payload.addProperty("parent_id", it) }
            api.request("/api/conversations/$conversationId/scheduled-messages", "POST", payload)
            body = ""
            vm.changed()
        }
    }

    if (settings) {
        EditorDialog(
            "Conversation settings",
            listOf(
                FormField("name", "Name", details.data.obj().text("name")),
                FormField("topic", "Topic", details.data.obj().text("topic")),
                FormField("description", "Description", details.data.obj().text("description"), multiline = true)
            ),
            { settings = false }
        ) {
            api.request("/api/conversations/$conversationId", "PUT", it)
            vm.changed()
        }
    }

    if (showTemplates) {
        val templates = rememberRemote(api, "/api/templates")
        AlertDialog(
            onDismissRequest = { showTemplates = false },
            title = { Text("Templates", style = AppTypography.headline) },
            text = {
                Column {
                    RemoteStatus(templates)
                    templates.data.rows().forEach { template ->
                        TextButton(onClick = {
                            body = template.text("body")
                            showTemplates = false
                        }) {
                            Text(template.text("name"), color = AppColors.brandPrimary)
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = { showTemplates = false }) {
                    Text("Close", color = AppColors.brandPrimary)
                }
            }
        )
    }

    messageEditor?.let { (name, message) ->
        if (name == "Delete") {
            ConfirmDialog("Delete message?", message.text("body"), { messageEditor = null }) {
                api.request("/api/messages/${message.id}", "DELETE")
                vm.changed()
            }
        } else {
            EditorDialog(
                name,
                when (name) {
                    "React" -> listOf(FormField("emoji", "Reaction", required = true))
                    "Remind me" -> listOf(FormField("remind_at", "Remind at", Instant.now().plusSeconds(3600).toString(), required = true, date = true))
                    "Create task" -> listOf(FormField("title", "Title", message.text("body"), required = true), FormField("list_id", "List", lists.firstOrNull()?.value.orEmpty(), required = true, options = lists))
                    else -> listOf(FormField("body", "Message", message.text("body"), required = true, multiline = true))
                },
                { messageEditor = null }
            ) { payload ->
                val suffix = when (name) {
                    "React" -> "/reactions"
                    "Remind me" -> "/remind"
                    "Create task" -> "/convert-to-task"
                    else -> ""
                }
                api.request("/api/messages/${message.id}$suffix", if (name == "Edit") "PUT" else "POST", payload)
                vm.changed()
            }
        }
    }

    callTicket?.let { ticket ->
        CallRoomDialog(api, ticket, onDismiss = { callTicket = null; vm.changed() })
    }
}
