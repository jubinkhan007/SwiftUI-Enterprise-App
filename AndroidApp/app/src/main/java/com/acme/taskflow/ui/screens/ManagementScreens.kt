package com.acme.taskflow.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.time.Instant
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@Composable
fun InboxScreen(vm: AppViewModel, api: ApiClient) {
    var unreadOnly by rememberSaveable { mutableStateOf(false) }
    var selectedCategory by rememberSaveable { mutableStateOf("All") }
    val remote = rememberRemote(api, "/api/notifications", vm.revision, query = mapOf("unread" to unreadOnly.toString()), paged = true)
    val action = rememberAction()

    val categories = listOf("All", "Mentions", "Assignments", "Updates")

    LaunchedEffect(Unit) {
        while (kotlinx.coroutines.currentCoroutineContext().isActive) {
            kotlinx.coroutines.delay(3000)
            vm.changed()
        }
    }

    val allRows = remote.data.rows()
    val filteredRows = allRows.filter { item ->
        val itemType = item.text("type").lowercase()
        when (selectedCategory) {
            "Mentions" -> itemType.contains("mention")
            "Assignments" -> itemType.contains("assign")
            "Updates" -> itemType.contains("update") || itemType.contains("status")
            else -> true
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
                    IconButton(
                        onClick = {
                            action.run {
                                api.request("/api/notifications/mark-all-read", "POST")
                                vm.changed()
                            }
                        },
                        enabled = !action.busy,
                        modifier = Modifier.testTag("InboxMarkAllReadButton")
                    ) {
                        Icon(
                            imageVector = Icons.Default.CheckCircle,
                            contentDescription = "Mark All Read",
                            tint = AppColors.brandPrimary,
                            modifier = Modifier.size(24.dp)
                        )
                    }

                    FilterChip(
                        selected = unreadOnly,
                        onClick = { unreadOnly = !unreadOnly },
                        label = { Text("Unread", style = AppTypography.caption1) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = AppColors.brandPrimary,
                            selectedLabelColor = Color.White
                        ),
                        modifier = Modifier.testTag("InboxUnreadToggle")
                    )
                }
            }

            // Horizontal Filter Chips (matching iOS filterChips)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                categories.forEach { category ->
                    val isSelected = selectedCategory == category
                    Box(
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(if (isSelected) AppColors.brandPrimary else AppColors.surfaceElevated)
                            .clickable { selectedCategory = category }
                            .padding(horizontal = 14.dp, vertical = 6.dp)
                            .testTag("InboxFilterChip_$category"),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = category,
                            style = AppTypography.subheadline,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (isSelected) Color.White else AppColors.textSecondary
                        )
                    }
                }
            }
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(remote)
        ActionStatus(action)

        LazyColumn(
            modifier = Modifier.fillMaxSize().testTag("InboxLazyColumn"),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            if (!remote.loading && remote.error == null && filteredRows.isEmpty()) {
                item {
                    Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Box(
                                modifier = Modifier
                                    .size(80.dp)
                                    .clip(CircleShape)
                                    .background(AppColors.surfaceElevated),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    Icons.Default.NotificationsNone,
                                    null,
                                    tint = AppColors.brandPrimary,
                                    modifier = Modifier.size(36.dp)
                                )
                            }
                            Text("All caught up!", style = AppTypography.title3, color = AppColors.textPrimary)
                            Text(
                                if (unreadOnly) "No unread notifications right now." else "You have no notifications yet.",
                                style = AppTypography.subheadline,
                                color = AppColors.textSecondary
                            )
                        }
                    }
                }
            }
            items(filteredRows, key = { it.id }) { item ->
                val payload = runCatching { JsonParser.parseString(item.text("payload_json")).obj() }.getOrDefault(JsonObject())
                val isUnread = item.text("read_at").isBlank()
                val callerName = payload.text("actorName", "Team Member")
                val itemType = item.text("type")
                val titleText = when {
                    itemType.contains("assign", ignoreCase = true) -> "New Assignment"
                    itemType.contains("update", ignoreCase = true) || itemType.contains("status", ignoreCase = true) -> "Task Updated"
                    itemType.contains("mention", ignoreCase = true) -> "You were mentioned"
                    itemType == "call.incoming" -> "Incoming Video Call"
                    else -> item.text("title").ifBlank { payload.text("title", label(itemType)) }
                }
                val bodyText = if (itemType == "call.incoming") "$callerName is calling you..." else item.text("body").ifBlank { payload.text("body", payload.text("message")) }

                IosCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .testTag("InboxItemCard_${item.id}")
                ) {
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
                                enabled = !action.busy,
                                modifier = Modifier.testTag("InboxItemReadButton_${item.id}")
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
fun NotificationPreferencesModal(
    conversationId: String,
    conversationTitle: String = "Conversation",
    onDismiss: () -> Unit,
    api: ApiClient,
    onSaved: () -> Unit = {}
) {
    var isMuted by rememberSaveable { mutableStateOf(false) }
    var selectedPreference by rememberSaveable { mutableStateOf("all") }
    var isSaving by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier.fillMaxWidth().padding(16.dp).testTag("NotificationPreferencesModal")
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Notifications",
                        style = AppTypography.headline,
                        color = AppColors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }

                // Section 1: Mute Conversation
                Text("Conversation", style = AppTypography.caption1, color = AppColors.textSecondary)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppRadius.medium))
                        .background(AppColors.surfaceElevated)
                        .padding(horizontal = 14.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Mute this conversation",
                        style = AppTypography.subheadline,
                        color = AppColors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    Switch(
                        checked = isMuted,
                        onCheckedChange = { isMuted = it },
                        colors = SwitchDefaults.colors(checkedThumbColor = Color.White, checkedTrackColor = AppColors.brandPrimary),
                        modifier = Modifier.testTag("MuteSwitch")
                    )
                }

                // Section 2: Alert Frequency
                Text("Notify me", style = AppTypography.caption1, color = AppColors.textSecondary)
                val options = listOf(
                    "all" to "All messages",
                    "mentions" to "Mentions only",
                    "none" to "Nothing"
                )
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppRadius.medium))
                        .background(AppColors.surfaceElevated)
                ) {
                    options.forEachIndexed { index, (value, title) ->
                        val isSelected = selectedPreference == value
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { selectedPreference = value }
                                .padding(horizontal = 14.dp, vertical = 12.dp)
                                .testTag("PrefOption_$value"),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = title,
                                style = AppTypography.subheadline,
                                color = if (isSelected) AppColors.brandPrimary else AppColors.textPrimary,
                                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                                modifier = Modifier.weight(1f)
                            )
                            if (isSelected) {
                                Icon(Icons.Default.Check, null, tint = AppColors.brandPrimary, modifier = Modifier.size(18.dp))
                            }
                        }
                        if (index < options.lastIndex) {
                            HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                        }
                    }
                }

                errorMessage?.let {
                    Text(it, style = AppTypography.caption1, color = AppColors.statusError)
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) {
                        Text("Cancel", color = AppColors.textSecondary)
                    }
                    Spacer(Modifier.width(8.dp))
                    Button(
                        onClick = {
                            isSaving = true
                            errorMessage = null
                            scope.launch {
                                try {
                                    val body = JsonObject().apply {
                                        addProperty("notification_preference", selectedPreference)
                                        addProperty("is_muted", isMuted)
                                    }
                                    api.request("/api/conversations/$conversationId/preferences", "PATCH", body)
                                    onSaved()
                                    onDismiss()
                                } catch (e: Exception) {
                                    errorMessage = e.message ?: "Failed to save preferences"
                                } finally {
                                    isSaving = false
                                }
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary),
                        enabled = !isSaving,
                        modifier = Modifier.testTag("SavePreferencesButton")
                    ) {
                        Text(if (isSaving) "Saving..." else "Save")
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
    val members = rememberRemote(api, "/api/organizations/${api.orgId}/members", vm.revision)
    val invites = rememberRemote(api, "/api/organizations/${api.orgId}/invites", vm.revision)
    val joinRequests = rememberRemote(api, "/api/organizations/${api.orgId}/join-requests", vm.revision)
    val me = rememberRemote(api, "/api/me", query = mapOf("org_id" to api.orgId))
    val permissions = me.data.obj().child("permissions").getAsJsonArray("permissions")?.map { it.asString }.orEmpty()
    val canInvite = "members.invite" in permissions || me.data.obj().text("role") in listOf("owner", "admin")
    val canManageRoles = "members.manage" in permissions || me.data.obj().text("role") in listOf("owner", "admin")
    val canRemoveMembers = "members.remove" in permissions || me.data.obj().text("role") in listOf("owner", "admin")

    var selectedTab by rememberSaveable { mutableIntStateOf(0) } // 0 = Members, 1 = Invites, 2 = Requests
    var showInviteModal by remember { mutableStateOf(false) }
    var showBillingModal by remember { mutableStateOf(false) }
    var memberBeingEdited by remember { mutableStateOf<JsonObject?>(null) }
    var memberToRemove by remember { mutableStateOf<JsonObject?>(null) }
    var inviteToRevoke by remember { mutableStateOf<JsonObject?>(null) }
    val action = rememberAction()
    val clipboardManager = LocalClipboardManager.current
    var copiedToast by remember { mutableStateOf<String?>(null) }

    fun roleBadgeColor(role: String): Color = when (role.lowercase()) {
        "owner" -> Color(0xFF6E56CF) // Purple
        "admin" -> Color(0xFF007AFF) // Blue
        "manager" -> Color(0xFFFF9500) // Amber
        "member" -> Color(0xFF34C759) // Green
        "guest" -> Color(0xFF8E8E93) // Gray
        else -> Color(0xFF8E8E93)
    }

    fun inviteStatusColor(status: String): Color = when (status.lowercase()) {
        "pending" -> Color(0xFFFF9500)
        "accepted" -> Color(0xFF34C759)
        "revoked" -> Color(0xFFFF3B30)
        else -> Color(0xFF8E8E93)
    }

    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        // Header
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Team",
                    style = AppTypography.largeTitle,
                    color = AppColors.textPrimary,
                    modifier = Modifier.weight(1f)
                )
                IconButton(
                    onClick = { showBillingModal = true },
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                        .testTag("btn_billing_settings")
                ) {
                    Icon(Icons.Default.CreditCard, "Billing & Plans", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                }
                if (canInvite) {
                    Spacer(Modifier.width(8.dp))
                    IconButton(
                        onClick = { showInviteModal = true },
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                            .testTag("btn_invite_member")
                    ) {
                        Icon(Icons.Default.PersonAdd, "Invite member", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                    }
                }
            }

            // Segmented 3-Tab Picker (matching TeamManagementView.swift)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(AppRadius.medium))
                    .background(AppColors.surfaceElevated)
                    .padding(3.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                val tabTitles = listOf(
                    "Members (${members.data.rows().size})",
                    "Invites (${invites.data.rows().size})",
                    "Requests (${joinRequests.data.rows().size})"
                )
                tabTitles.forEachIndexed { index, title ->
                    val isSelected = selectedTab == index
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(AppRadius.small))
                            .background(if (isSelected) AppColors.surfacePrimary else Color.Transparent)
                            .clickable { selectedTab = index }
                            .padding(vertical = 8.dp)
                            .testTag("team_tab_$index"),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = title,
                            style = AppTypography.subheadline,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (isSelected) AppColors.textPrimary else AppColors.textSecondary,
                            maxLines = 1
                        )
                    }
                }
            }
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RemoteStatus(if (selectedTab == 0) members else if (selectedTab == 1) invites else joinRequests)
        ActionStatus(action)
        copiedToast?.let {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.statusSuccess.copy(alpha = 0.15f))
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            ) {
                Text(it, style = AppTypography.caption1, color = AppColors.statusSuccess)
            }
        }

        when (selectedTab) {
            0 -> {
                // MEMBERS TAB
                LazyColumn(
                    modifier = Modifier.fillMaxSize().testTag("team_members_list"),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    if (!members.loading && members.error == null && members.data.rows().isEmpty()) {
                        item {
                            Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Icon(Icons.Default.Group, null, tint = AppColors.textTertiary, modifier = Modifier.size(48.dp))
                                    Text("No members yet", style = AppTypography.headline, color = AppColors.textSecondary)
                                }
                            }
                        }
                    }
                    items(members.data.rows(), key = { it.id }) { member ->
                        val role = member.text("role")
                        val isCurrentUser = member.text("user_id") == vm.user?.id
                        val isOwner = role.equals("owner", true)
                        IosCard(modifier = Modifier.fillMaxWidth().testTag("member_row_${member.id}")) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                AppAvatar(member.text("display_name"))
                                Spacer(Modifier.width(12.dp))
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text(member.text("display_name"), style = AppTypography.headline)
                                    Text(member.text("email"), style = AppTypography.caption1, color = AppColors.textSecondary)
                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                        Box(
                                            modifier = Modifier
                                                .clip(RoundedCornerShape(AppRadius.small))
                                                .background(roleBadgeColor(role).copy(alpha = 0.12f))
                                                .padding(horizontal = 8.dp, vertical = 3.dp)
                                        ) {
                                            Text(
                                                text = label(role).replaceFirstChar { it.uppercase() },
                                                style = AppTypography.caption2,
                                                fontWeight = FontWeight.SemiBold,
                                                color = roleBadgeColor(role)
                                            )
                                        }
                                        if (isCurrentUser) {
                                            Text("(You)", style = AppTypography.caption2, color = AppColors.textTertiary)
                                        }
                                    }
                                }
                                if (canManageRoles && !isOwner) {
                                    IconButton(
                                        onClick = { memberBeingEdited = member },
                                        modifier = Modifier.testTag("btn_edit_role_${member.id}")
                                    ) {
                                        Icon(Icons.Default.Edit, "Edit role", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                                    }
                                }
                                if (canRemoveMembers && !isOwner && !isCurrentUser) {
                                    IconButton(
                                        onClick = { memberToRemove = member },
                                        modifier = Modifier.testTag("btn_remove_member_${member.id}")
                                    ) {
                                        Icon(Icons.Default.PersonRemove, "Remove member", tint = AppColors.statusError, modifier = Modifier.size(20.dp))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            1 -> {
                // INVITES TAB
                LazyColumn(
                    modifier = Modifier.fillMaxSize().testTag("team_invites_list"),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    if (!invites.loading && invites.error == null && invites.data.rows().isEmpty()) {
                        item {
                            Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Icon(Icons.Default.MailOutline, null, tint = AppColors.textTertiary, modifier = Modifier.size(48.dp))
                                    Text("No invitations", style = AppTypography.headline, color = AppColors.textSecondary)
                                }
                            }
                        }
                    }
                    items(invites.data.rows(), key = { it.id }) { invite ->
                        val status = invite.text("status", "pending")
                        val role = invite.text("role", "member")
                        IosCard(modifier = Modifier.fillMaxWidth().testTag("invite_row_${invite.id}")) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(42.dp)
                                        .clip(CircleShape)
                                        .background(inviteStatusColor(status).copy(alpha = 0.15f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(Icons.Default.MailOutline, null, tint = inviteStatusColor(status), modifier = Modifier.size(22.dp))
                                }
                                Spacer(Modifier.width(12.dp))
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text(invite.text("email"), style = AppTypography.headline)
                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                        Text(label(role).replaceFirstChar { it.uppercase() }, style = AppTypography.caption1, color = AppColors.textSecondary)
                                        Text("•", color = AppColors.textTertiary)
                                        Text(status.replaceFirstChar { it.uppercase() }, style = AppTypography.caption1, color = inviteStatusColor(status))
                                    }
                                    if (invite.text("expires_at").isNotBlank()) {
                                        Text("Expires ${dateLabel(invite.text("expires_at"))}", style = AppTypography.caption2, color = AppColors.textTertiary)
                                    }
                                }
                                IconButton(
                                    onClick = {
                                        clipboardManager.setText(AnnotatedString(invite.id))
                                        copiedToast = "Invite ID copied to clipboard!"
                                    },
                                    modifier = Modifier.testTag("btn_copy_invite_${invite.id}")
                                ) {
                                    Icon(Icons.Default.ContentCopy, "Copy ID", tint = AppColors.brandPrimary, modifier = Modifier.size(18.dp))
                                }
                                if (canManageRoles && status.equals("pending", true)) {
                                    IconButton(
                                        onClick = { inviteToRevoke = invite },
                                        modifier = Modifier.testTag("btn_revoke_invite_${invite.id}")
                                    ) {
                                        Icon(Icons.Default.Cancel, "Revoke", tint = AppColors.statusError, modifier = Modifier.size(20.dp))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            2 -> {
                // JOIN REQUESTS TAB
                LazyColumn(
                    modifier = Modifier.fillMaxSize().testTag("team_requests_list"),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    if (!joinRequests.loading && joinRequests.error == null && joinRequests.data.rows().isEmpty()) {
                        item {
                            Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Icon(Icons.Default.HourglassEmpty, null, tint = AppColors.textTertiary, modifier = Modifier.size(48.dp))
                                    Text("No pending requests", style = AppTypography.headline, color = AppColors.textSecondary)
                                }
                            }
                        }
                    }
                    items(joinRequests.data.rows(), key = { it.id }) { req ->
                        IosCard(modifier = Modifier.fillMaxWidth().testTag("request_row_${req.id}")) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(42.dp)
                                        .clip(CircleShape)
                                        .background(AppColors.statusWarning.copy(alpha = 0.15f)),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = req.text("user_display_name", req.text("name", "U")).take(1).uppercase(),
                                        style = AppTypography.headline,
                                        color = AppColors.statusWarning
                                    )
                                }
                                Spacer(Modifier.width(12.dp))
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text(req.text("user_display_name", req.text("name", "User")), style = AppTypography.headline)
                                    Text(req.text("user_email", req.text("email")), style = AppTypography.caption1, color = AppColors.textSecondary)
                                    if (req.text("message").isNotBlank()) {
                                        Text("\"${req.text("message")}\"", style = AppTypography.caption2, color = AppColors.textTertiary)
                                    }
                                }
                                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                    IconButton(
                                        onClick = {
                                            action.run {
                                                api.request("/api/organizations/${api.orgId}/join-requests/${req.id}", "POST", json("action" to "reject"))
                                                joinRequests.refresh()
                                                vm.changed()
                                            }
                                        },
                                        modifier = Modifier.testTag("btn_reject_request_${req.id}")
                                    ) {
                                        Icon(Icons.Default.Cancel, "Reject", tint = AppColors.statusError, modifier = Modifier.size(24.dp))
                                    }
                                    IconButton(
                                        onClick = {
                                            action.run {
                                                api.request("/api/organizations/${api.orgId}/join-requests/${req.id}", "POST", json("action" to "accept"))
                                                joinRequests.refresh()
                                                members.refresh()
                                                vm.changed()
                                            }
                                        },
                                        modifier = Modifier.testTag("btn_accept_request_${req.id}")
                                    ) {
                                        Icon(Icons.Default.CheckCircle, "Accept", tint = AppColors.statusSuccess, modifier = Modifier.size(24.dp))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Invite Member Modal
    if (showInviteModal) {
        InviteMemberModal(
            api = api,
            onDismiss = { showInviteModal = false },
            onInvited = {
                showInviteModal = false
                invites.refresh()
                vm.changed()
            }
        )
    }

    // Role Edit Modal
    memberBeingEdited?.let { member ->
        RoleEditModal(
            member = member,
            api = api,
            onDismiss = { memberBeingEdited = null },
            onUpdated = {
                memberBeingEdited = null
                members.refresh()
                vm.changed()
            }
        )
    }

    // Remove Member Confirmation
    memberToRemove?.let { member ->
        ConfirmDialog(
            title = "Remove member?",
            message = "Are you sure you want to remove ${member.text("display_name")} from this organization?",
            onDismiss = { memberToRemove = null }
        ) {
            api.request("/api/organizations/${api.orgId}/members/${member.id}", "DELETE")
            memberToRemove = null
            members.refresh()
            vm.changed()
        }
    }

    // Revoke Invite Confirmation
    inviteToRevoke?.let { invite ->
        ConfirmDialog(
            title = "Revoke invitation?",
            message = "This invitation to ${invite.text("email")} will no longer be valid.",
            onDismiss = { inviteToRevoke = null }
        ) {
            api.request("/api/organizations/${api.orgId}/invites/${invite.id}", "DELETE")
            inviteToRevoke = null
            invites.refresh()
            vm.changed()
        }
    }

    if (showBillingModal) {
        BillingSettingsModal(
            vm = vm,
            api = api,
            onDismiss = { showBillingModal = false }
        )
    }
}

@Composable
private fun InviteMemberModal(
    api: ApiClient,
    onDismiss: () -> Unit,
    onInvited: () -> Unit
) {
    var email by rememberSaveable { mutableStateOf("") }
    var selectedRole by rememberSaveable { mutableStateOf("member") }
    val action = rememberAction()

    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary)
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Invite Member", style = AppTypography.title2, modifier = Modifier.weight(1f))
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }

                ActionStatus(action)

                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("Email Address") },
                    placeholder = { Text("colleague@example.com") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("tf_invite_email")
                )

                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Role", style = AppTypography.subheadline, color = AppColors.textSecondary)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf("guest", "member", "manager", "admin").forEach { r ->
                            val isSel = selectedRole == r
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(AppRadius.small))
                                    .background(if (isSel) AppColors.brandPrimary else AppColors.surfaceElevated)
                                    .clickable { selectedRole = r }
                                    .padding(vertical = 8.dp)
                                    .testTag("chip_role_$r"),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = r.replaceFirstChar { it.uppercase() },
                                    style = AppTypography.caption1,
                                    fontWeight = if (isSel) FontWeight.Bold else FontWeight.Normal,
                                    color = if (isSel) Color.White else AppColors.textSecondary
                                )
                            }
                        }
                    }
                }

                Button(
                    onClick = {
                        action.run {
                            api.request("/api/organizations/${api.orgId}/invites", "POST", json("email" to email.trim(), "role" to selectedRole))
                            onInvited()
                        }
                    },
                    enabled = email.trim().isNotBlank() && !action.busy,
                    modifier = Modifier.fillMaxWidth().testTag("btn_send_invite"),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary)
                ) {
                    Text("Send Invite")
                }
            }
        }
    }
}

@Composable
private fun RoleEditModal(
    member: JsonObject,
    api: ApiClient,
    onDismiss: () -> Unit,
    onUpdated: () -> Unit
) {
    var selectedRole by rememberSaveable { mutableStateOf(member.text("role", "member")) }
    val action = rememberAction()

    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary)
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Edit Member Role", style = AppTypography.title2, modifier = Modifier.weight(1f))
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }

                ActionStatus(action)

                Row(
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(AppRadius.medium)).background(AppColors.surfaceElevated).padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    AppAvatar(member.text("display_name"))
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text(member.text("display_name"), style = AppTypography.headline)
                        Text(member.text("email"), style = AppTypography.caption1, color = AppColors.textSecondary)
                    }
                }

                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Select Role", style = AppTypography.subheadline, color = AppColors.textSecondary)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf("guest", "member", "manager", "admin").forEach { r ->
                            val isSel = selectedRole == r
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(AppRadius.small))
                                    .background(if (isSel) AppColors.brandPrimary else AppColors.surfaceElevated)
                                    .clickable { selectedRole = r }
                                    .padding(vertical = 8.dp)
                                    .testTag("edit_chip_role_$r"),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = r.replaceFirstChar { it.uppercase() },
                                    style = AppTypography.caption1,
                                    fontWeight = if (isSel) FontWeight.Bold else FontWeight.Normal,
                                    color = if (isSel) Color.White else AppColors.textSecondary
                                )
                            }
                        }
                    }
                }

                Button(
                    onClick = {
                        action.run {
                            api.request("/api/organizations/${api.orgId}/members/${member.id}", "PATCH", json("role" to selectedRole))
                            onUpdated()
                        }
                    },
                    enabled = !action.busy,
                    modifier = Modifier.fillMaxWidth().testTag("btn_update_role"),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary)
                ) {
                    Text("Update Role")
                }
            }
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

@Composable
fun BillingSettingsModal(
    vm: AppViewModel,
    api: ApiClient,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val orgRemote = rememberRemote(api, "/api/organizations/${api.orgId}", vm.revision)
    val membersRemote = rememberRemote(api, "/api/organizations/${api.orgId}/members", vm.revision)
    val action = rememberAction()

    val orgObj = orgRemote.data.obj()
    val currentTier = orgObj.text("subscription_tier", orgObj.text("subscriptionTier", "free")).lowercase()
    val memberCount = membersRemote.data.rows().size.coerceAtLeast(1)
    val isPro = currentTier == "pro"
    val isEnterprise = currentTier == "enterprise"
    val isFree = !isPro && !isEnterprise

    var checkoutUrlResult by remember { mutableStateOf<String?>(null) }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .padding(vertical = 12.dp)
                .testTag("modal_billing_settings"),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(20.dp)
            ) {
                // Header Row
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            "Subscription & Billing",
                            style = AppTypography.title2,
                            color = AppColors.textPrimary
                        )
                        Text(
                            "Manage workspace plan, invoices, and quota allocations.",
                            style = AppTypography.caption1,
                            color = AppColors.textSecondary
                        )
                    }
                    IconButton(onClick = onDismiss, modifier = Modifier.testTag("btn_close_billing")) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }

                Spacer(Modifier.height(12.dp))
                ActionStatus(action)

                if (checkoutUrlResult != null) {
                    Text(
                        "Redirect: $checkoutUrlResult",
                        style = AppTypography.caption2,
                        color = AppColors.brandPrimary,
                        modifier = Modifier.testTag("txt_checkout_url")
                    )
                    Spacer(Modifier.height(6.dp))
                }

                // Scrollable Content
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    // Current Plan & Usage Gauge Card
                    IosCard(modifier = Modifier.fillMaxWidth().testTag("card_current_subscription")) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column {
                                    Text("CURRENT PLAN", style = AppTypography.caption2, color = AppColors.textTertiary, fontWeight = FontWeight.Bold)
                                    Text(
                                        currentTier.replaceFirstChar { it.uppercase() } + " Plan",
                                        style = AppTypography.title3,
                                        fontWeight = FontWeight.Bold,
                                        color = AppColors.textPrimary
                                    )
                                }
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(AppRadius.small))
                                        .background(if (isFree) AppColors.surfaceElevated else AppColors.brandPrimary.copy(alpha = 0.15f))
                                        .padding(horizontal = 8.dp, vertical = 4.dp)
                                ) {
                                    Text(
                                        if (isFree) "Free ($0/mo)" else if (isPro) "Active ($19/mo)" else "Active ($99/mo)",
                                        style = AppTypography.caption2,
                                        color = if (isFree) AppColors.textSecondary else AppColors.brandPrimary,
                                        fontWeight = FontWeight.Bold
                                    )
                                }
                            }

                            HorizontalDivider(color = AppColors.borderDefault)

                            // Seat Quota Progress
                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text("Team Members Quota", style = AppTypography.subheadline, color = AppColors.textSecondary)
                                    Text(
                                        if (isFree) "$memberCount / 5 seats" else "$memberCount seats (Unlimited)",
                                        style = AppTypography.subheadline,
                                        fontWeight = FontWeight.SemiBold,
                                        color = AppColors.textPrimary
                                    )
                                }
                                val progress = if (isFree) (memberCount / 5f).coerceIn(0f, 1f) else 0.2f
                                LinearProgressIndicator(
                                    progress = { progress },
                                    modifier = Modifier.fillMaxWidth().height(6.dp).clip(CircleShape),
                                    color = if (isFree && memberCount >= 5) AppColors.statusError else AppColors.brandPrimary,
                                    trackColor = AppColors.surfaceElevated
                                )
                            }
                        }
                    }

                    // Tiers
                    Text("AVAILABLE PLANS", style = AppTypography.caption2, color = AppColors.textTertiary, fontWeight = FontWeight.Bold)

                    // 1. Free Tier Card
                    PlanTierCard(
                        title = "Free",
                        price = "$0",
                        period = "/ month",
                        subtitle = "For small teams and side projects",
                        features = listOf("Up to 5 team members", "1 active project", "100 MB file storage", "Basic Kanban boards"),
                        isCurrent = isFree,
                        ctaText = if (isFree) "Current Plan" else "Downgrade via Portal",
                        tag = "tier_free",
                        onCta = {
                            if (!isFree) {
                                action.run {
                                    val res = api.request("/api/org/billing/portal", "POST")
                                    val url = res.data.obj().text("url")
                                    checkoutUrlResult = url
                                    if (url.isNotEmpty()) {
                                        runCatching {
                                            if (!url.contains("test_mock") && !url.contains("mock")) {
                                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                                }
                                                context.startActivity(intent)
                                            }
                                        }
                                    }
                                    orgRemote.refresh()
                                    vm.changed()
                                }
                            }
                        }
                    )

                    // 2. Pro Tier Card (Highlighted)
                    PlanTierCard(
                        title = "Pro",
                        price = "$19",
                        period = "/ month",
                        subtitle = "For growing teams needing calls and automations",
                        features = listOf(
                            "Unlimited team members",
                            "Unlimited projects & spaces",
                            "50 GB storage",
                            "Live video & audio calling (LiveKit)",
                            "Webhooks & integrations",
                            "Priority support"
                        ),
                        isCurrent = isPro,
                        isFeatured = true,
                        ctaText = if (isPro) "Manage via Stripe Portal" else "Upgrade to Pro ($19)",
                        tag = "tier_pro",
                        onCta = {
                            action.run {
                                val endpoint = if (isPro) "/api/org/billing/portal" else "/api/org/billing/checkout"
                                val res = api.request(endpoint, "POST")
                                val url = res.data.obj().text("url")
                                checkoutUrlResult = url
                                if (url.isNotEmpty()) {
                                    runCatching {
                                        if (!url.contains("test_mock") && !url.contains("mock")) {
                                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                            }
                                            context.startActivity(intent)
                                        }
                                    }
                                }
                                orgRemote.refresh()
                                vm.changed()
                            }
                        }
                    )

                    // 3. Enterprise Tier Card
                    PlanTierCard(
                        title = "Enterprise",
                        price = "$99",
                        period = "/ month",
                        subtitle = "For organizations requiring custom compliance and SSO",
                        features = listOf(
                            "Everything in Pro",
                            "SAML 2.0 & OIDC Single Sign-On",
                            "Custom domain whitelabeling",
                            "Audit log export & retention",
                            "99.9% uptime SLA"
                        ),
                        isCurrent = isEnterprise,
                        ctaText = "Contact Enterprise Sales",
                        tag = "tier_enterprise",
                        onCta = {
                            runCatching {
                                val intent = Intent(Intent.ACTION_SENDTO).apply {
                                    data = Uri.parse("mailto:enterprise@taskflow.local?subject=TaskFlow%20Enterprise%20Subscription")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                context.startActivity(intent)
                            }
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun PlanTierCard(
    title: String,
    price: String,
    period: String,
    subtitle: String,
    features: List<String>,
    isCurrent: Boolean,
    isFeatured: Boolean = false,
    ctaText: String,
    tag: String,
    onCta: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth().testTag(tag),
        shape = RoundedCornerShape(AppRadius.medium),
        colors = CardDefaults.cardColors(
            containerColor = if (isFeatured) AppColors.brandPrimary.copy(alpha = 0.08f) else AppColors.surfaceElevated
        ),
        border = if (isFeatured) androidx.compose.foundation.BorderStroke(1.5.dp, AppColors.brandPrimary)
                 else androidx.compose.foundation.BorderStroke(1.dp, AppColors.borderDefault)
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(title, style = AppTypography.headline, fontWeight = FontWeight.Bold, color = AppColors.textPrimary)
                    if (isFeatured) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(AppRadius.small))
                                .background(AppColors.brandPrimary)
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        ) {
                            Text("Popular", style = AppTypography.caption2, color = Color.White, fontWeight = FontWeight.Bold)
                        }
                    }
                }
                if (isCurrent) {
                    Text("Active", style = AppTypography.caption1, color = AppColors.statusSuccess, fontWeight = FontWeight.Bold)
                }
            }

            Text(subtitle, style = AppTypography.caption1, color = AppColors.textSecondary)

            Row(verticalAlignment = Alignment.Bottom) {
                Text(price, style = AppTypography.title1, fontWeight = FontWeight.ExtraBold, color = AppColors.textPrimary)
                Spacer(Modifier.width(4.dp))
                Text(period, style = AppTypography.caption1, color = AppColors.textTertiary, modifier = Modifier.padding(bottom = 2.dp))
            }

            HorizontalDivider(color = AppColors.borderDefault.copy(alpha = 0.6f))

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                features.forEach { feat ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(Icons.Default.Check, null, tint = AppColors.statusSuccess, modifier = Modifier.size(16.dp))
                        Text(feat, style = AppTypography.caption1, color = AppColors.textPrimary)
                    }
                }
            }

            Spacer(Modifier.height(4.dp))

            Button(
                onClick = onCta,
                enabled = !isCurrent || isFeatured,
                modifier = Modifier.fillMaxWidth().testTag("btn_action_$tag"),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isFeatured) AppColors.brandPrimary else AppColors.surfacePrimary,
                    contentColor = if (isFeatured) Color.White else AppColors.textPrimary,
                    disabledContainerColor = AppColors.surfacePrimary.copy(alpha = 0.5f),
                    disabledContentColor = AppColors.textTertiary
                ),
                shape = RoundedCornerShape(AppRadius.small)
            ) {
                Text(ctaText, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
