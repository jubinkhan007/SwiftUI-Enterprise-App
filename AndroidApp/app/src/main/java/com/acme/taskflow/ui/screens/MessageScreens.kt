package com.acme.taskflow.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Reply
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*
import com.google.gson.JsonObject
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

// MARK: - Slash Command Models
data class SlashCommand(
    val name: String,
    val description: String,
    val syntax: String,
    val icon: ImageVector
)

private val availableSlashCommands = listOf(
    SlashCommand("task", "Create a task from this message", "/task [title]", Icons.Default.CheckCircle),
    SlashCommand("remind", "Set a personal reminder", "/remind in 20m [text]", Icons.Default.Alarm),
    SlashCommand("poll", "Create a quick interactive poll", "/poll [question]", Icons.Default.Poll),
    SlashCommand("status", "Update your working status", "/status [status]", Icons.Default.Face),
    SlashCommand("shrug", "Append ¯\\_(ツ)_/¯", "/shrug", Icons.Default.SentimentSatisfied),
    SlashCommand("code", "Format text in a code block", "/code [language]", Icons.Default.Code),
    SlashCommand("table", "Insert a markdown table template", "/table", Icons.Default.TableChart)
)

// URL detection regex
private val urlRegex = Regex("""https?://[^\s<>"{}|\^~\[\]`]+""")

@Composable
fun MessagesScreen(vm: AppViewModel, api: ApiClient, lists: List<Choice>) {
    val remote = rememberRemote(api, "/api/conversations", vm.revision)
    val members = rememberRemote(api, "/api/organizations/${api.orgId}/members")
    var selected by rememberSaveable { mutableStateOf<String?>(null) }
    var search by rememberSaveable { mutableStateOf("") }
    var showGlobalSearch by remember { mutableStateOf(false) }
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
                            onClick = { showGlobalSearch = true },
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(AppColors.surfaceElevated)
                        ) {
                            Icon(Icons.Default.Search, "Global Search", tint = AppColors.textPrimary, modifier = Modifier.size(20.dp))
                        }
                        Spacer(Modifier.width(8.dp))
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
                        label = "Filter conversations...",
                        value = search,
                        onValueChange = { search = it },
                        singleLine = true,
                        leadingIcon = {
                            Icon(Icons.Default.FilterList, null, tint = AppColors.textTertiary, modifier = Modifier.size(18.dp))
                        },
                        trailingIcon = {
                            if (search.isNotEmpty()) {
                                IconButton(onClick = { search = "" }) {
                                    Icon(Icons.Default.Close, "Clear", tint = AppColors.textTertiary, modifier = Modifier.size(16.dp))
                                }
                            }
                        }
                    )
                }

                RemoteStatus(remote)

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
                            val isSelected = selected == conversation.id
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
                                            color = if (isSelected) AppColors.brandPrimary else AppColors.textPrimary,
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

        if (selected != null) {
            Box(Modifier.weight(1f)) {
                key(selected) {
                    ChatScreen(vm, api, selected!!, lists, onBack = {
                        selected = null
                        vm.changed()
                    })
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

    if (showGlobalSearch) {
        GlobalSearchDialog(api = api, onSelectConversation = { convId ->
            selected = convId
            showGlobalSearch = false
        }, onDismiss = { showGlobalSearch = false })
    }
}

@Composable
fun ChatScreen(vm: AppViewModel, api: ApiClient, conversationId: String, lists: List<Choice>, onBack: () -> Unit) {
    var activeThreadMessage by remember { mutableStateOf<JsonObject?>(null) }
    var pins by rememberSaveable { mutableStateOf(false) }
    var before by rememberSaveable { mutableStateOf("") }
    var older by remember { mutableStateOf<List<JsonObject>>(emptyList()) }
    val details = rememberRemote(api, "/api/conversations/$conversationId", vm.revision)
    val path = if (pins) "/api/conversations/$conversationId/pins" else "/api/conversations/$conversationId/messages"
    val remote = rememberRemote(api, path, vm.revision)
    val messages = (older + remote.data.rows()).distinctBy { it.id }.sortedBy { it.text("created_at") }

    var body by rememberSaveable(conversationId) { mutableStateOf("") }
    var messageEditor by remember { mutableStateOf<Pair<String, JsonObject>?>(null) }
    var convertToTaskMessage by remember { mutableStateOf<JsonObject?>(null) }
    var reminderMessage by remember { mutableStateOf<JsonObject?>(null) }
    var reactionDetailMessage by remember { mutableStateOf<JsonObject?>(null) }
    var scheduleDialog by remember { mutableStateOf(false) }
    var showScheduledSheet by remember { mutableStateOf(false) }
    var settings by remember { mutableStateOf(false) }
    var showTemplates by remember { mutableStateOf(false) }
    var callTicket by remember { mutableStateOf<JsonObject?>(null) }
    val action = rememberAction()
    val listState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()

    BackHandler { onBack() }

    LaunchedEffect(conversationId) {
        action.run {
            val draft = api.request("/api/conversations/$conversationId/draft").data.obj()
            if (body.isBlank()) body = draft.text("body")
        }
    }

    LaunchedEffect(conversationId, messages.lastOrNull()?.id) {
        messages.lastOrNull()?.id?.let { lastMessageId ->
            runCatching {
                api.request(
                    "/api/conversations/$conversationId/read",
                    method = "POST",
                    body = json("last_read_message_id" to lastMessageId)
                )
            }
        }
    }

    LaunchedEffect(messages.lastOrNull()?.id) {
        if (messages.isNotEmpty()) {
            runCatching {
                listState.scrollToItem(messages.size - 1)
            }
        }
    }

    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary).imePadding()) {
        // Top Bar
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
                    .clickable { onBack() }
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
                    text = "Messages",
                    style = AppTypography.body,
                    color = AppColors.brandPrimary
                )
            }

            Column(Modifier.weight(1f).padding(horizontal = 8.dp)) {
                Text(
                    text = details.data.obj().text("name", "Conversation"),
                    style = AppTypography.headline,
                    color = AppColors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                val topic = details.data.obj().text("topic")
                if (topic.isNotBlank()) {
                    Text(
                        text = topic,
                        style = AppTypography.caption2,
                        color = AppColors.textSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            IconButton(onClick = { pins = !pins }) {
                Icon(Icons.Default.PushPin, "Pinned", tint = if (pins) AppColors.brandPrimary else AppColors.textSecondary)
            }
            IconButton(onClick = { showScheduledSheet = true }) {
                Icon(Icons.Default.Schedule, "Scheduled Messages", tint = AppColors.textSecondary)
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

        if (!pins && remote.data.rows().size >= 50) {
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

        // Messages list
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
                            .semantics(mergeDescendants = true) {
                                contentDescription = "Message options"
                            }
                            .clickable { menu = true }
                            .padding(horizontal = 14.dp, vertical = 10.dp)
                    ) {
                        Column {
                            val msgBody = if (message.text("deleted_at").isNotBlank()) "Message deleted" else message.text("body")
                            Text(
                                text = msgBody,
                                style = AppTypography.body,
                                color = if (isMe) Color.White else AppColors.textPrimary
                            )

                            // Rich Link Preview if link detected
                            val detectedUrl = urlRegex.find(msgBody)?.value
                            if (detectedUrl != null && message.text("deleted_at").isBlank()) {
                                Spacer(Modifier.height(6.dp))
                                LinkPreviewCard(url = detectedUrl, isMe = isMe)
                            }

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
                            DropdownMenuItem(
                                text = { Text("Reply in thread") },
                                leadingIcon = { Icon(Icons.AutoMirrored.Filled.Reply, null, modifier = Modifier.size(18.dp)) },
                                onClick = { activeThreadMessage = message; menu = false }
                            )
                            DropdownMenuItem(
                                text = { Text("Convert to Task") },
                                leadingIcon = { Icon(Icons.Default.TaskAlt, null, modifier = Modifier.size(18.dp)) },
                                onClick = { convertToTaskMessage = message; menu = false }
                            )
                            DropdownMenuItem(
                                text = { Text(if (message.flag("is_pinned")) "Unpin" else "Pin") },
                                leadingIcon = { Icon(Icons.Default.PushPin, null, modifier = Modifier.size(18.dp)) },
                                onClick = {
                                    menu = false
                                    action.run {
                                        val exists = message.flag("is_pinned")
                                        api.request("/api/messages/${message.id}/pin", if (exists) "DELETE" else "POST")
                                        vm.changed()
                                    }
                                }
                            )
                            DropdownMenuItem(
                                text = { Text(if (message.flag("is_bookmarked_by_me")) "Remove Bookmark" else "Bookmark") },
                                leadingIcon = { Icon(Icons.Default.Bookmark, null, modifier = Modifier.size(18.dp)) },
                                onClick = {
                                    menu = false
                                    action.run {
                                        val exists = message.flag("is_bookmarked_by_me")
                                        api.request("/api/messages/${message.id}/bookmark", if (exists) "DELETE" else "POST")
                                        vm.changed()
                                    }
                                }
                            )
                            DropdownMenuItem(
                                text = { Text("React") },
                                leadingIcon = { Icon(Icons.Default.AddReaction, null, modifier = Modifier.size(18.dp)) },
                                onClick = { messageEditor = "React" to message; menu = false }
                            )
                            DropdownMenuItem(
                                text = { Text("Remind me...") },
                                leadingIcon = { Icon(Icons.Default.Alarm, null, modifier = Modifier.size(18.dp)) },
                                onClick = { reminderMessage = message; menu = false }
                            )
                            if (isMe) {
                                DropdownMenuItem(
                                    text = { Text("Edit") },
                                    leadingIcon = { Icon(Icons.Default.Edit, null, modifier = Modifier.size(18.dp)) },
                                    onClick = { messageEditor = "Edit" to message; menu = false }
                                )
                                DropdownMenuItem(
                                    text = { Text("Delete", color = AppColors.statusError) },
                                    leadingIcon = { Icon(Icons.Default.Delete, null, tint = AppColors.statusError, modifier = Modifier.size(18.dp)) },
                                    onClick = { messageEditor = "Delete" to message; menu = false }
                                )
                            }
                        }
                    }

                    // Reactions Pills
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
                                            reactionDetailMessage = message
                                        }
                                        .padding(horizontal = 8.dp, vertical = 2.dp)
                                ) {
                                    Text("${reaction.text("emoji")} ${reaction.number("count")}", style = AppTypography.caption2)
                                }
                            }
                        }
                    }

                    // Thread Replies Row
                    val replyCount = message.number("reply_count").toInt()
                    if (replyCount > 0) {
                        Row(
                            modifier = Modifier
                                .padding(top = 4.dp)
                                .clip(RoundedCornerShape(AppRadius.small))
                                .background(AppColors.brandPrimary.copy(alpha = 0.08f))
                                .clickable { activeThreadMessage = message }
                                .padding(horizontal = 8.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Icon(
                                Icons.AutoMirrored.Filled.Reply,
                                contentDescription = null,
                                tint = AppColors.brandPrimary,
                                modifier = Modifier.size(14.dp)
                            )
                            Text(
                                text = "$replyCount ${if (replyCount == 1) "reply" else "replies"}",
                                style = AppTypography.caption2.copy(fontWeight = FontWeight.SemiBold),
                                color = AppColors.brandPrimary
                            )
                        }
                    }
                }
            }
        }

        // Action Toolbar (Draft, Schedule, Templates)
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
                    api.request("/api/conversations/$conversationId/draft", "PUT", json("body" to body))
                    vm.changed()
                }
            }) {
                Icon(Icons.Default.Save, "Save draft", tint = AppColors.textSecondary, modifier = Modifier.size(20.dp))
            }
            IconButton(onClick = { scheduleDialog = true }, enabled = body.isNotBlank()) {
                Icon(Icons.Default.ScheduleSend, "Schedule", tint = if (body.isNotBlank()) AppColors.brandPrimary else AppColors.textTertiary, modifier = Modifier.size(20.dp))
            }
            IconButton(onClick = { showTemplates = true }) {
                Icon(Icons.Default.TextSnippet, "Templates", tint = AppColors.textSecondary, modifier = Modifier.size(20.dp))
            }
        }

        // Slash Command Suggestion Palette
        if (body.startsWith("/")) {
            val query = body.removePrefix("/").lowercase()
            val filteredCommands = availableSlashCommands.filter { it.name.startsWith(query) || it.syntax.contains(query) }
            if (filteredCommands.isNotEmpty()) {
                SlashCommandPalette(
                    commands = filteredCommands,
                    onSelect = { cmd ->
                        when (cmd.name) {
                            "shrug" -> body = "¯\\_(ツ)_/¯"
                            "code" -> body = "```\n\n```"
                            "table" -> body = "| Header 1 | Header 2 |\n|---|---|\n| Item 1 | Item 2 |"
                            "task" -> {
                                body = ""
                                convertToTaskMessage = json("body" to query.removePrefix("task").trim())
                            }
                            else -> body = "/${cmd.name} "
                        }
                    }
                )
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
                            text = "Message... (type / for commands)",
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
                            var sendText = body.trim()
                            if (sendText.startsWith("/shrug")) {
                                sendText = sendText.replace("/shrug", "¯\\_(ツ)_/¯").trim()
                            }
                            api.request("/api/conversations/$conversationId/messages", "POST", json("body" to sendText, "message_type" to "text"))
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

    // Thread Detail Sheet
    activeThreadMessage?.let { rootMsg ->
        ThreadDetailModal(
            api = api,
            vm = vm,
            conversationId = conversationId,
            rootMessage = rootMsg,
            onDismiss = { activeThreadMessage = null; vm.changed() }
        )
    }

    // Convert to Task Dialog
    convertToTaskMessage?.let { msg ->
        ConvertMessageToTaskDialog(
            api = api,
            message = msg,
            lists = lists,
            onDismiss = { convertToTaskMessage = null },
            onSuccess = {
                convertToTaskMessage = null
                vm.changed()
            }
        )
    }

    // Message Reminder Dialog
    reminderMessage?.let { msg ->
        MessageReminderDialog(
            api = api,
            message = msg,
            onDismiss = { reminderMessage = null },
            onSuccess = { reminderMessage = null; vm.changed() }
        )
    }

    // Reaction Details Modal
    reactionDetailMessage?.let { msg ->
        ReactionDetailsModal(
            api = api,
            message = msg,
            currentUserId = vm.user?.id.orEmpty(),
            onDismiss = { reactionDetailMessage = null },
            onUpdated = { vm.changed() }
        )
    }

    // Schedule Send Dialog
    if (scheduleDialog) {
        ScheduleSendDialog(
            body = body,
            onSchedule = { scheduledTime ->
                scheduleDialog = false
                action.run {
                    api.request(
                        "/api/conversations/$conversationId/scheduled-messages",
                        "POST",
                        json("body" to body.trim(), "scheduled_for" to scheduledTime)
                    )
                    body = ""
                    vm.changed()
                }
            },
            onDismiss = { scheduleDialog = false }
        )
    }

    // Scheduled Messages Drawer
    if (showScheduledSheet) {
        ScheduledMessagesSheet(
            api = api,
            conversationId = conversationId,
            onDismiss = { showScheduledSheet = false; vm.changed() }
        )
    }

    // Channel Settings & Member Management Modal (matching ChannelSettingsView.swift)
    if (settings) {
        ChannelSettingsModal(
            api = api,
            conversationId = conversationId,
            onDismiss = { settings = false },
            onChanged = { vm.changed() },
            onChannelClosed = {
                settings = false
                onBack()
            }
        )
    }

    // Templates Picker
    if (showTemplates) {
        TemplatePickerSheet(
            api = api,
            onSelect = { selectedBody ->
                body = selectedBody
                showTemplates = false
            },
            onDismiss = { showTemplates = false }
        )
    }

    // Generic Message Editor
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
                    "React" -> listOf(FormField("emoji", "Reaction (e.g. 👍, ❤️, 🚀)", required = true))
                    else -> listOf(FormField("body", "Message", message.text("body"), required = true, multiline = true))
                },
                { messageEditor = null }
            ) { payload ->
                val suffix = if (name == "React") "/reactions" else ""
                api.request("/api/messages/${message.id}$suffix", if (name == "Edit") "PUT" else "POST", payload)
                vm.changed()
            }
        }
    }

    callTicket?.let { ticket ->
        CallRoomDialog(api, ticket, onDismiss = { callTicket = null; vm.changed() })
    }
}

// MARK: - Thread Detail Modal
@Composable
fun ThreadDetailModal(
    api: ApiClient,
    vm: AppViewModel,
    conversationId: String,
    rootMessage: JsonObject,
    onDismiss: () -> Unit
) {
    val threadRemote = rememberRemote(api, "/api/messages/${rootMessage.id}/thread", vm.revision)
    val replies = threadRemote.data.obj().list("replies")
    var replyBody by remember { mutableStateOf("") }
    val coroutineScope = rememberCoroutineScope()
    var isSending by remember { mutableStateOf(false) }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.9f)
        ) {
            Column(Modifier.fillMaxSize()) {
                // Header
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        "Thread",
                        style = AppTypography.title3,
                        color = AppColors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

                LazyColumn(
                    modifier = Modifier.weight(1f).padding(horizontal = 16.dp),
                    contentPadding = PaddingValues(vertical = 12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Root Message Card
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(14.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    AppAvatar(rootMessage.text("sender_name"))
                                    Spacer(Modifier.width(10.dp))
                                    Column(Modifier.weight(1f)) {
                                        Text(rootMessage.text("sender_name"), style = AppTypography.headline)
                                        Text(dateLabel(rootMessage.text("created_at")), style = AppTypography.caption2, color = AppColors.textTertiary)
                                    }
                                }
                                Spacer(Modifier.height(8.dp))
                                Text(rootMessage.text("body"), style = AppTypography.body, color = AppColors.textPrimary)
                            }
                        }
                    }

                    item {
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 4.dp)) {
                            Text(
                                "${replies.size} ${if (replies.size == 1) "reply" else "replies"}",
                                style = AppTypography.caption1.copy(fontWeight = FontWeight.Bold),
                                color = AppColors.textSecondary
                            )
                            Spacer(Modifier.width(8.dp))
                            HorizontalDivider(Modifier.weight(1f), thickness = 0.5.dp, color = AppColors.borderSubtle)
                        }
                    }

                    // Replies List
                    items(replies, key = { it.id }) { reply ->
                        val isMe = reply.text("sender_id") == vm.user?.id
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = if (isMe) Arrangement.End else Arrangement.Start
                        ) {
                            if (!isMe) {
                                AppAvatar(reply.text("sender_name"))
                                Spacer(Modifier.width(8.dp))
                            }
                            Column(horizontalAlignment = if (isMe) Alignment.End else Alignment.Start) {
                                if (!isMe) {
                                    Text(reply.text("sender_name"), style = AppTypography.caption2, color = AppColors.textTertiary)
                                }
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(12.dp))
                                        .background(if (isMe) AppColors.brandPrimary else AppColors.surfaceElevated)
                                        .padding(horizontal = 12.dp, vertical = 8.dp)
                                ) {
                                    Text(
                                        reply.text("body"),
                                        style = AppTypography.body,
                                        color = if (isMe) Color.White else AppColors.textPrimary
                                    )
                                }
                                Text(
                                    dateLabel(reply.text("created_at")),
                                    style = AppTypography.caption2,
                                    color = AppColors.textTertiary,
                                    modifier = Modifier.padding(top = 2.dp)
                                )
                            }
                        }
                    }
                }

                // Reply Input Bar
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(AppRadius.medium))
                            .background(AppColors.surfaceElevated)
                            .border(BorderStroke(0.5.dp, AppColors.borderDefault), RoundedCornerShape(AppRadius.medium))
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        if (replyBody.isEmpty()) {
                            Text("Reply to thread...", style = AppTypography.body, color = AppColors.textTertiary)
                        }
                        BasicTextField(
                            value = replyBody,
                            onValueChange = { replyBody = it },
                            textStyle = AppTypography.body.copy(color = AppColors.textPrimary),
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                    Spacer(Modifier.width(8.dp))
                    IconButton(
                        onClick = {
                            if (replyBody.isNotBlank() && !isSending) {
                                coroutineScope.launch {
                                    isSending = true
                                    runCatching {
                                        api.request(
                                            "/api/conversations/$conversationId/messages",
                                            "POST",
                                            json("body" to replyBody.trim(), "parent_id" to rootMessage.id)
                                        )
                                    }
                                    replyBody = ""
                                    isSending = false
                                    vm.changed()
                                }
                            }
                        },
                        enabled = replyBody.isNotBlank() && !isSending
                    ) {
                        Icon(Icons.AutoMirrored.Filled.Send, "Send", tint = if (replyBody.isNotBlank()) AppColors.brandPrimary else AppColors.textTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Slash Command Palette
@Composable
fun SlashCommandPalette(
    commands: List<SlashCommand>,
    onSelect: (SlashCommand) -> Unit
) {
    Card(
        shape = RoundedCornerShape(AppRadius.medium),
        colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .heightIn(max = 220.dp)
    ) {
        LazyColumn(contentPadding = PaddingValues(6.dp)) {
            items(commands) { cmd ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppRadius.small))
                        .clickable { onSelect(cmd) }
                        .padding(horizontal = 10.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(cmd.icon, null, tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(cmd.syntax, style = AppTypography.headline.copy(fontWeight = FontWeight.Bold), color = AppColors.brandPrimary)
                        Text(cmd.description, style = AppTypography.caption2, color = AppColors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Convert Message to Task Dialog
@Composable
fun ConvertMessageToTaskDialog(
    api: ApiClient,
    message: JsonObject,
    lists: List<Choice>,
    onDismiss: () -> Unit,
    onSuccess: () -> Unit
) {
    var title by remember { mutableStateOf(message.text("body")) }
    var selectedListId by remember { mutableStateOf(lists.firstOrNull()?.value.orEmpty()) }
    var priority by remember { mutableStateOf("medium") }
    val coroutineScope = rememberCoroutineScope()
    var isSubmitting by remember { mutableStateOf(false) }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier.fillMaxWidth().padding(16.dp)
        ) {
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("Convert to Task", style = AppTypography.title3, color = AppColors.textPrimary)

                IosTextField(
                    label = "Task Title",
                    value = title,
                    onValueChange = { title = it },
                    modifier = Modifier.fillMaxWidth()
                )

                Column {
                    Text("Target List", style = AppTypography.caption1, color = AppColors.textSecondary)
                    Spacer(Modifier.height(4.dp))
                    LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        items(lists) { choice ->
                            IosFilterChip(
                                title = choice.label,
                                isSelected = selectedListId == choice.value,
                                onClick = { selectedListId = choice.value }
                            )
                        }
                    }
                }

                Column {
                    Text("Priority", style = AppTypography.caption1, color = AppColors.textSecondary)
                    Spacer(Modifier.height(4.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf("low", "medium", "high", "critical").forEach { p ->
                            IosFilterChip(
                                title = p.replaceFirstChar { it.uppercase() },
                                isSelected = priority == p,
                                onClick = { priority = p }
                            )
                        }
                    }
                }

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onDismiss) {
                        Text("Cancel", color = AppColors.textSecondary)
                    }
                    Spacer(Modifier.width(8.dp))
                    Button(
                        onClick = {
                            if (title.isNotBlank() && selectedListId.isNotBlank() && !isSubmitting) {
                                coroutineScope.launch {
                                    isSubmitting = true
                                    val payload = json(
                                        "title" to title.trim(),
                                        "list_id" to selectedListId,
                                        "priority" to priority,
                                        "description" to "Created from message: ${message.text("body")}"
                                    )
                                    val result = runCatching {
                                        api.request("/api/messages/${message.id}/convert-to-task", "POST", payload)
                                    }
                                    if (result.isFailure) {
                                        // Fallback directly to task creation
                                        runCatching {
                                            api.request("/api/tasks", "POST", payload)
                                        }
                                    }
                                    isSubmitting = false
                                    onSuccess()
                                }
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary),
                        enabled = title.isNotBlank() && selectedListId.isNotBlank() && !isSubmitting
                    ) {
                        Text("Create Task", color = Color.White)
                    }
                }
            }
        }
    }
}

// MARK: - Message Reminder Dialog
@Composable
fun MessageReminderDialog(
    api: ApiClient,
    message: JsonObject,
    onDismiss: () -> Unit,
    onSuccess: () -> Unit
) {
    val coroutineScope = rememberCoroutineScope()
    var isSubmitting by remember { mutableStateOf(false) }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier.fillMaxWidth().padding(16.dp)
        ) {
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Remind Me About This", style = AppTypography.title3, color = AppColors.textPrimary)
                Text(
                    message.text("body"),
                    style = AppTypography.caption1,
                    color = AppColors.textSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(Modifier.height(4.dp))

                listOf(
                    "In 20 minutes" to 20L * 60,
                    "In 1 hour" to 60L * 60,
                    "In 3 hours" to 3L * 3600,
                    "Tomorrow morning (9:00 AM)" to 14L * 3600,
                    "Next Monday (9:00 AM)" to 72L * 3600
                ).forEach { (label, seconds) ->
                    TextButton(
                        modifier = Modifier.fillMaxWidth(),
                        onClick = {
                            if (!isSubmitting) {
                                coroutineScope.launch {
                                    isSubmitting = true
                                    val remindAt = Instant.now().plusSeconds(seconds).toString()
                                    runCatching {
                                        api.request(
                                            "/api/messages/${message.id}/remind",
                                            "POST",
                                            json("remind_at" to remindAt, "body" to message.text("body"))
                                        )
                                    }
                                    isSubmitting = false
                                    onSuccess()
                                }
                            }
                        }
                    ) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(label, color = AppColors.textPrimary, style = AppTypography.body)
                            Icon(Icons.Default.ChevronRight, null, tint = AppColors.textTertiary)
                        }
                    }
                }

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onDismiss) {
                        Text("Cancel", color = AppColors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Reaction Details Modal
@Composable
fun ReactionDetailsModal(
    api: ApiClient,
    message: JsonObject,
    currentUserId: String,
    onDismiss: () -> Unit,
    onUpdated: () -> Unit
) {
    val reactions = message.list("reactions")
    var selectedEmoji by remember { mutableStateOf(reactions.firstOrNull()?.text("emoji").orEmpty()) }
    val coroutineScope = rememberCoroutineScope()

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier.fillMaxWidth().padding(16.dp)
        ) {
            Column(Modifier.padding(20.dp)) {
                Text("Reactions", style = AppTypography.title3, color = AppColors.textPrimary)
                Spacer(Modifier.height(12.dp))

                // Reaction Tabs
                LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    items(reactions) { reaction ->
                        val emoji = reaction.text("emoji")
                        val count = reaction.number("count").toInt()
                        IosFilterChip(
                            title = "$emoji $count",
                            isSelected = selectedEmoji == emoji,
                            onClick = { selectedEmoji = emoji }
                        )
                    }
                }

                Spacer(Modifier.height(16.dp))

                val currentReaction = reactions.firstOrNull { it.text("emoji") == selectedEmoji }
                val didReact = currentReaction?.flag("did_react") == true

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        if (didReact) "You reacted with $selectedEmoji" else "React with $selectedEmoji",
                        style = AppTypography.caption1,
                        color = AppColors.textSecondary
                    )
                    TextButton(
                        onClick = {
                            coroutineScope.launch {
                                if (didReact) {
                                    api.request("/api/messages/${message.id}/reactions/${Uri.encode(selectedEmoji)}", "DELETE")
                                } else {
                                    api.request("/api/messages/${message.id}/reactions", "POST", json("emoji" to selectedEmoji))
                                }
                                onUpdated()
                                onDismiss()
                            }
                        }
                    ) {
                        Text(if (didReact) "Remove" else "Add", color = AppColors.brandPrimary)
                    }
                }

                Spacer(Modifier.height(8.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onDismiss) {
                        Text("Close", color = AppColors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Schedule Send Dialog
@Composable
fun ScheduleSendDialog(
    body: String,
    onSchedule: (String) -> Unit,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier.fillMaxWidth().padding(16.dp)
        ) {
            Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Schedule Message", style = AppTypography.title3, color = AppColors.textPrimary)
                Text(body, style = AppTypography.caption1, color = AppColors.textSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis)

                Spacer(Modifier.height(4.dp))

                listOf(
                    "In 30 minutes" to Instant.now().plus(30, ChronoUnit.MINUTES),
                    "Tomorrow morning (9:00 AM)" to Instant.now().plus(14, ChronoUnit.HOURS),
                    "Tomorrow afternoon (2:00 PM)" to Instant.now().plus(19, ChronoUnit.HOURS),
                    "Next Monday (9:00 AM)" to Instant.now().plus(72, ChronoUnit.HOURS)
                ).forEach { (label, instant) ->
                    TextButton(
                        modifier = Modifier.fillMaxWidth(),
                        onClick = { onSchedule(instant.toString()) }
                    ) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(label, color = AppColors.textPrimary, style = AppTypography.body)
                            Icon(Icons.Default.AccessTime, null, tint = AppColors.brandPrimary, modifier = Modifier.size(18.dp))
                        }
                    }
                }

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onDismiss) {
                        Text("Cancel", color = AppColors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Scheduled Messages Drawer/Sheet
@Composable
fun ScheduledMessagesSheet(
    api: ApiClient,
    conversationId: String,
    onDismiss: () -> Unit
) {
    val remote = rememberRemote(api, "/api/me/scheduled-messages")
    val coroutineScope = rememberCoroutineScope()

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier.fillMaxWidth().fillMaxHeight(0.7f).padding(16.dp)
        ) {
            Column(Modifier.fillMaxSize().padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Scheduled Messages", style = AppTypography.title3, color = AppColors.textPrimary, modifier = Modifier.weight(1f))
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, null, tint = AppColors.textSecondary)
                    }
                }
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

                val items = remote.data.rows().filter { it.text("conversation_id") == conversationId }
                if (items.isEmpty()) {
                    Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                        Text("No scheduled messages.", style = AppTypography.body, color = AppColors.textSecondary)
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(items, key = { it.id }) { item ->
                            Card(
                                shape = RoundedCornerShape(AppRadius.medium),
                                colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(Modifier.padding(12.dp)) {
                                    Text(item.text("body"), style = AppTypography.body)
                                    Spacer(Modifier.height(4.dp))
                                    Text("Sends at: ${dateLabel(item.text("scheduled_for"))}", style = AppTypography.caption2, color = AppColors.brandPrimary)
                                    Spacer(Modifier.height(6.dp))
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        TextButton(onClick = {
                                            coroutineScope.launch {
                                                api.request("/api/scheduled-messages/${item.id}/send-now", "POST")
                                                remote.reload()
                                            }
                                        }) {
                                            Text("Send Now", color = AppColors.brandPrimary)
                                        }
                                        TextButton(onClick = {
                                            coroutineScope.launch {
                                                api.request("/api/scheduled-messages/${item.id}", "DELETE")
                                                remote.reload()
                                            }
                                        }) {
                                            Text("Cancel", color = AppColors.statusError)
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
}

// MARK: - Template Picker Sheet
@Composable
fun TemplatePickerSheet(
    api: ApiClient,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val templates = rememberRemote(api, "/api/templates")
    var createMode by remember { mutableStateOf(false) }
    var newName by remember { mutableStateOf("") }
    var newBody by remember { mutableStateOf("") }
    val coroutineScope = rememberCoroutineScope()

    val defaultTemplates = listOf(
        Pair("Daily Standup", "**Yesterday:** \n**Today:** \n**Blockers:** None"),
        Pair("Bug Report", "**Steps to Reproduce:** \n**Expected:** \n**Actual:** "),
        Pair("Code Review Ready", "🚀 Ready for review! Please check PR: "),
        Pair("Meeting Follow-Up", "**Decisions Made:** \n**Next Action Items:** \n- [ ] ")
    )

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier.fillMaxWidth().fillMaxHeight(0.75f).padding(16.dp)
        ) {
            Column(Modifier.fillMaxSize().padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(if (createMode) "Create Template" else "Message Templates", style = AppTypography.title3, color = AppColors.textPrimary, modifier = Modifier.weight(1f))
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, null, tint = AppColors.textSecondary)
                    }
                }
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

                if (createMode) {
                    Column(Modifier.weight(1f).padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        IosTextField(label = "Template Name", value = newName, onValueChange = { newName = it }, modifier = Modifier.fillMaxWidth())
                        IosTextField(label = "Content", value = newBody, onValueChange = { newBody = it }, modifier = Modifier.fillMaxWidth(), singleLine = false)
                    }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        TextButton(onClick = { createMode = false }) { Text("Back", color = AppColors.textSecondary) }
                        Spacer(Modifier.width(8.dp))
                        Button(
                            onClick = {
                                if (newName.isNotBlank() && newBody.isNotBlank()) {
                                    coroutineScope.launch {
                                        api.request("/api/templates", "POST", json("name" to newName.trim(), "body" to newBody.trim(), "scope" to "user"))
                                        createMode = false
                                        templates.reload()
                                    }
                                }
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary),
                            enabled = newName.isNotBlank() && newBody.isNotBlank()
                        ) {
                            Text("Save Template", color = Color.White)
                        }
                    }
                } else {
                    val serverRows = templates.data.rows()
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(vertical = 8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        item {
                            Button(
                                onClick = { createMode = true },
                                colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary.copy(alpha = 0.12f)),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Icon(Icons.Default.Add, null, tint = AppColors.brandPrimary, modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(6.dp))
                                Text("New Template", color = AppColors.brandPrimary)
                            }
                        }

                        if (serverRows.isNotEmpty()) {
                            items(serverRows, key = { it.id }) { template ->
                                Card(
                                    shape = RoundedCornerShape(AppRadius.medium),
                                    colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                                    modifier = Modifier.fillMaxWidth().clickable { onSelect(template.text("body")) }
                                ) {
                                    Column(Modifier.padding(12.dp)) {
                                        Text(template.text("name"), style = AppTypography.headline, color = AppColors.brandPrimary)
                                        Spacer(Modifier.height(2.dp))
                                        Text(template.text("body"), style = AppTypography.caption1, color = AppColors.textSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis)
                                    }
                                }
                            }
                        } else {
                            items(defaultTemplates) { (name, content) ->
                                Card(
                                    shape = RoundedCornerShape(AppRadius.medium),
                                    colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                                    modifier = Modifier.fillMaxWidth().clickable { onSelect(content) }
                                ) {
                                    Column(Modifier.padding(12.dp)) {
                                        Text(name, style = AppTypography.headline, color = AppColors.brandPrimary)
                                        Spacer(Modifier.height(2.dp))
                                        Text(content, style = AppTypography.caption1, color = AppColors.textSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis)
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

// MARK: - Rich Link Preview Card
@Composable
fun LinkPreviewCard(url: String, isMe: Boolean) {
    val context = LocalContext.current
    val uri = remember(url) { runCatching { Uri.parse(url) }.getOrNull() }
    val host = uri?.host.orEmpty().removePrefix("www.")

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(if (isMe) Color.White.copy(alpha = 0.15f) else AppColors.surfacePrimary)
            .border(BorderStroke(0.5.dp, if (isMe) Color.White.copy(alpha = 0.25f) else AppColors.borderSubtle), RoundedCornerShape(8.dp))
            .padding(8.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Default.Language,
                contentDescription = null,
                tint = if (isMe) Color.White else AppColors.brandPrimary,
                modifier = Modifier.size(18.dp)
            )
            Spacer(Modifier.width(8.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    text = host.ifEmpty { "External Link" },
                    style = AppTypography.caption2.copy(fontWeight = FontWeight.Bold),
                    color = if (isMe) Color.White else AppColors.textPrimary,
                    maxLines = 1
                )
                Text(
                    text = url,
                    style = AppTypography.caption2,
                    color = if (isMe) Color.White.copy(alpha = 0.8f) else AppColors.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            IconButton(
                onClick = {
                    uri?.let {
                        runCatching {
                            context.startActivity(Intent(Intent.ACTION_VIEW, it))
                        }
                    }
                },
                modifier = Modifier.size(24.dp)
            ) {
                Icon(
                    Icons.Default.OpenInNew,
                    contentDescription = "Open link",
                    tint = if (isMe) Color.White.copy(alpha = 0.8f) else AppColors.textTertiary,
                    modifier = Modifier.size(14.dp)
                )
            }
        }
    }
}

// MARK: - Global Search Dialog
@Composable
fun GlobalSearchDialog(
    api: ApiClient,
    onSelectConversation: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var query by rememberSaveable { mutableStateOf("") }
    var tab by remember { mutableStateOf("Messages") }
    val searchResults = rememberRemote(
        api,
        if (tab == "Messages") "/api/search" else "/api/search/files",
        query = if (query.isNotBlank()) mapOf("q" to query) else emptyMap()
    )

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier.fillMaxWidth().fillMaxHeight(0.85f).padding(12.dp)
        ) {
            Column(Modifier.fillMaxSize().padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Global Search", style = AppTypography.title3, color = AppColors.textPrimary, modifier = Modifier.weight(1f))
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, null, tint = AppColors.textSecondary)
                    }
                }

                Spacer(Modifier.height(8.dp))

                IosTextField(
                    label = "Search messages or files...",
                    value = query,
                    onValueChange = { query = it },
                    singleLine = true,
                    leadingIcon = { Icon(Icons.Default.Search, null, tint = AppColors.brandPrimary) }
                )

                Spacer(Modifier.height(8.dp))

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("Messages", "Files").forEach { item ->
                        IosFilterChip(
                            title = item,
                            isSelected = tab == item,
                            onClick = { tab = item }
                        )
                    }
                }

                HorizontalDivider(Modifier.padding(vertical = 8.dp), thickness = 0.5.dp, color = AppColors.borderSubtle)
                RemoteStatus(searchResults)

                val results = searchResults.data.rows()
                if (query.isBlank()) {
                    Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                        Text("Type a query to search across all conversations.", style = AppTypography.body, color = AppColors.textSecondary)
                    }
                } else if (!searchResults.loading && results.isEmpty()) {
                    Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                        Text("No results found for \"$query\".", style = AppTypography.body, color = AppColors.textSecondary)
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(results) { row ->
                            val convId = row.child("message").text("conversation_id").ifEmpty { row.text("conversation_id") }
                            IosCard(
                                modifier = Modifier.fillMaxWidth(),
                                onClick = {
                                    if (convId.isNotBlank()) onSelectConversation(convId)
                                }
                            ) {
                                Column {
                                    Text(
                                        row.text("conversation_name", "Conversation"),
                                        style = AppTypography.headline.copy(fontWeight = FontWeight.Bold),
                                        color = AppColors.brandPrimary
                                    )
                                    val matchBody = row.child("message").text("body").ifEmpty { row.text("body", row.text("filename")) }
                                    Text(
                                        matchBody,
                                        style = AppTypography.body,
                                        color = AppColors.textPrimary,
                                        maxLines = 2,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                    val createdAt = row.child("message").text("created_at").ifEmpty { row.text("created_at") }
                                    if (createdAt.isNotBlank()) {
                                        Text(dateLabel(createdAt), style = AppTypography.caption2, color = AppColors.textTertiary, modifier = Modifier.padding(top = 2.dp))
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

// MARK: - Channel Settings & Member Management Modal (matching ChannelSettingsView.swift)
@Composable
fun ChannelSettingsModal(
    api: ApiClient,
    conversationId: String,
    onDismiss: () -> Unit,
    onChanged: () -> Unit,
    onChannelClosed: () -> Unit
) {
    val conversationRemote = rememberRemote(api, "/api/conversations/$conversationId")
    val orgMembersRemote = rememberRemote(api, "/api/organizations/${api.orgId}/members")
    val conversation = conversationRemote.data.obj()

    var name by remember(conversation.text("name")) { mutableStateOf(conversation.text("name")) }
    var topic by remember(conversation.text("topic")) { mutableStateOf(conversation.text("topic")) }
    var description by remember(conversation.text("description")) { mutableStateOf(conversation.text("description")) }
    var isPrivate by remember(conversation.flag("is_private")) { mutableStateOf(conversation.flag("is_private")) }

    var selectedMemberIdToAdd by remember { mutableStateOf("") }
    var isSaving by remember { mutableStateOf(false) }
    var statusMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.9f)
        ) {
            Column(
                Modifier
                    .fillMaxSize()
                    .padding(16.dp)
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Channel Settings",
                        style = AppTypography.headline,
                        color = AppColors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }

                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle, modifier = Modifier.padding(vertical = 6.dp))

                statusMessage?.let {
                    Text(
                        text = it,
                        style = AppTypography.caption1,
                        color = AppColors.brandPrimary,
                        modifier = Modifier.padding(vertical = 4.dp)
                    )
                }

                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .testTag("channel_settings_list"),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // SECTION 1: METADATA
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text("Metadata", style = AppTypography.headline, color = AppColors.textPrimary)

                                IosTextField(
                                    label = "Name",
                                    value = name,
                                    onValueChange = { name = it },
                                    singleLine = true
                                )

                                IosTextField(
                                    label = "Topic",
                                    value = topic,
                                    onValueChange = { topic = it },
                                    singleLine = true
                                )

                                IosTextField(
                                    label = "Description",
                                    value = description,
                                    onValueChange = { description = it },
                                    singleLine = false,
                                    minLines = 2
                                )

                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("Private Channel", style = AppTypography.subheadline, color = AppColors.textPrimary)
                                    Switch(checked = isPrivate, onCheckedChange = { isPrivate = it })
                                }

                                Button(
                                    onClick = {
                                        scope.launch {
                                            isSaving = true
                                            try {
                                                api.request(
                                                    "/api/conversations/$conversationId",
                                                    "PUT",
                                                    json(
                                                        "name" to name.trim(),
                                                        "topic" to topic.trim(),
                                                        "description" to description.trim(),
                                                        "is_private" to isPrivate
                                                    )
                                                )
                                                conversationRemote.refresh()
                                                onChanged()
                                                statusMessage = "Channel updated successfully"
                                            } catch (e: Exception) {
                                                statusMessage = e.message ?: "Failed to save"
                                            } finally {
                                                isSaving = false
                                            }
                                        }
                                    },
                                    enabled = !isSaving,
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary)
                                ) {
                                    Text(if (isSaving) "Saving..." else "Save Changes", style = AppTypography.headline)
                                }
                            }
                        }
                    }

                    // SECTION 2: MEMBERS
                    val rawMembers = conversation.get("members")?.asJsonArray
                    val members = rawMembers?.mapNotNull { it.asJsonObject } ?: emptyList()

                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text("Members (${members.size})", style = AppTypography.headline, color = AppColors.textPrimary)
                                }

                                if (members.isEmpty()) {
                                    Text("No members listed", style = AppTypography.caption1, color = AppColors.textSecondary)
                                } else {
                                    members.forEach { m ->
                                        val displayName = m.text("display_name").ifBlank { m.text("name", "Member") }
                                        val role = m.text("role").ifBlank { "member" }
                                        val mUserId = m.text("user_id").ifBlank { m.id }
                                        val isOwner = role.lowercase() == "owner"

                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            verticalAlignment = Alignment.CenterVertically,
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Row(
                                                verticalAlignment = Alignment.CenterVertically,
                                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                                modifier = Modifier.weight(1f)
                                            ) {
                                                Box(
                                                    modifier = Modifier
                                                        .size(32.dp)
                                                        .clip(CircleShape)
                                                        .background(AppColors.brandPrimary.copy(alpha = 0.15f)),
                                                    contentAlignment = Alignment.Center
                                                ) {
                                                    Text(
                                                        text = displayName.take(1).uppercase().ifBlank { "U" },
                                                        style = AppTypography.caption1,
                                                        color = AppColors.brandPrimary,
                                                        fontWeight = FontWeight.Bold
                                                    )
                                                }
                                                Column {
                                                    Text(displayName, style = AppTypography.subheadline, color = AppColors.textPrimary)
                                                    Text(role.replaceFirstChar { it.uppercase() }, style = AppTypography.caption2, color = AppColors.textTertiary)
                                                }
                                            }

                                            if (!isOwner) {
                                                TextButton(
                                                    onClick = {
                                                        scope.launch {
                                                            try {
                                                                api.request("/api/conversations/$conversationId/members/$mUserId", "DELETE")
                                                                conversationRemote.refresh()
                                                                onChanged()
                                                                statusMessage = "Member removed"
                                                            } catch (e: Exception) {
                                                                statusMessage = e.message ?: "Failed to remove member"
                                                            }
                                                        }
                                                    }
                                                ) {
                                                    Text("Remove", style = AppTypography.caption1, color = AppColors.statusError)
                                                }
                                            }
                                        }
                                        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle.copy(alpha = 0.5f))
                                    }
                                }
                            }
                        }
                    }

                    // SECTION 3: ADD MEMBERS
                    val currentMemberUserIds = members.map { it.text("user_id").ifBlank { it.id } }.toSet()
                    val availableMembers = orgMembersRemote.data.rows().filter {
                        val uid = it.text("user_id").ifBlank { it.id }
                        uid !in currentMemberUserIds
                    }

                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text("Add Member", style = AppTypography.headline, color = AppColors.textPrimary)

                                if (availableMembers.isEmpty()) {
                                    Text("All organization members are already in this channel.", style = AppTypography.caption1, color = AppColors.textSecondary)
                                } else {
                                    val memberChoices = availableMembers.map {
                                        Choice(it.text("user_id").ifBlank { it.id }, it.text("display_name").ifBlank { it.text("email") })
                                    }
                                    ChoiceMenu(
                                        label = "Select Member",
                                        value = selectedMemberIdToAdd,
                                        options = memberChoices,
                                        onChange = { selectedMemberIdToAdd = it }
                                    )

                                    Button(
                                        onClick = {
                                            if (selectedMemberIdToAdd.isNotBlank()) {
                                                scope.launch {
                                                    try {
                                                        api.request(
                                                            "/api/conversations/$conversationId/members",
                                                            "POST",
                                                            json(
                                                                "member_ids" to listOf(selectedMemberIdToAdd),
                                                                "memberIds" to listOf(selectedMemberIdToAdd)
                                                            )
                                                        )
                                                        selectedMemberIdToAdd = ""
                                                        conversationRemote.refresh()
                                                        onChanged()
                                                        statusMessage = "Member added"
                                                    } catch (e: Exception) {
                                                        statusMessage = e.message ?: "Failed to add member"
                                                    }
                                                }
                                            }
                                        },
                                        enabled = selectedMemberIdToAdd.isNotBlank(),
                                        modifier = Modifier.fillMaxWidth(),
                                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary)
                                    ) {
                                        Text("Add Selected Member", style = AppTypography.subheadline)
                                    }
                                }
                            }
                        }
                    }

                    // SECTION 4: LIFECYCLE & DANGER ZONE
                    item {
                        Card(
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text("Lifecycle", style = AppTypography.headline, color = AppColors.textPrimary)

                                val isArchived = conversation.flag("is_archived")
                                OutlinedButton(
                                    onClick = {
                                        scope.launch {
                                            try {
                                                api.request("/api/conversations/$conversationId/archive", "POST")
                                                conversationRemote.refresh()
                                                onChanged()
                                                onChannelClosed()
                                            } catch (e: Exception) {
                                                statusMessage = e.message ?: "Failed to archive channel"
                                            }
                                        }
                                    },
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.outlinedButtonColors(contentColor = AppColors.statusWarning)
                                ) {
                                    Text(if (isArchived) "Unarchive Channel" else "Archive Channel", style = AppTypography.subheadline)
                                }

                                Button(
                                    onClick = {
                                        scope.launch {
                                            try {
                                                api.request("/api/conversations/$conversationId", "DELETE")
                                                onChanged()
                                                onChannelClosed()
                                            } catch (e: Exception) {
                                                statusMessage = e.message ?: "Failed to delete channel"
                                            }
                                        }
                                    },
                                    modifier = Modifier.fillMaxWidth(),
                                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusError)
                                ) {
                                    Text("Delete Channel", style = AppTypography.subheadline, color = Color.White)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

