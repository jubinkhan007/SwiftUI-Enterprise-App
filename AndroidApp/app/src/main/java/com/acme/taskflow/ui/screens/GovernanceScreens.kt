package com.acme.taskflow.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*
import com.google.gson.JsonObject

/**
 * Role → permission matrix. Mirrors `PermissionSet.defaultPermissions(for:)` in
 * SharedModels/Enums.swift, which is what the backend enforces. Keep in sync.
 */
object RolePermissions {
    val roles = listOf("owner", "admin", "manager", "member", "viewer", "guest")

    /** Ordered (category, permissions) pairs — every permission in `Permission.allCases`. */
    val categories: List<Pair<String, List<String>>> = listOf(
        "Tasks" to listOf(
            "tasks.read", "tasks.create", "tasks.edit", "tasks.delete", "tasks.assign",
            "tasks.create_subtask", "tasks.change_type", "tasks.relate", "tasks.manage_checklist"
        ),
        "Saved Views" to listOf("views.create", "views.update", "views.delete", "views.share", "views.set_default"),
        "Team & Members" to listOf("members.view", "members.invite", "members.manage", "members.remove"),
        "Projects" to listOf("projects.read", "projects.create", "projects.edit", "projects.delete", "projects.archive"),
        "Agile & Releases" to listOf("sprints.manage", "releases.manage", "issues.edit_bug_fields"),
        "Analytics & Reports" to listOf("analytics.view", "analytics.export", "reports.export"),
        "Collaboration" to listOf("comments.create", "attachments.upload", "attachments.download", "notifications.read"),
        "Workspace Settings" to listOf("org.settings", "org.delete", "audit_log.view")
    )

    private val all: Set<String> = categories.flatMap { it.second }.toSet()

    private val taskCore = setOf(
        "tasks.read", "tasks.create", "tasks.edit", "tasks.assign",
        "tasks.create_subtask", "tasks.change_type", "tasks.relate", "tasks.manage_checklist"
    )
    private val collab = setOf("comments.create", "attachments.upload", "attachments.download", "notifications.read")

    private val guest = setOf("tasks.read", "members.view", "notifications.read")
    private val viewer = setOf(
        "tasks.read", "members.view", "projects.read", "analytics.view",
        "attachments.download", "notifications.read"
    )
    private val member = taskCore + collab + setOf(
        "views.create", "views.update", "views.delete", "members.view", "projects.read", "analytics.view"
    )
    private val manager = taskCore + collab + setOf(
        "tasks.delete",
        "views.create", "views.update", "views.delete", "views.share", "views.set_default",
        "members.view", "members.invite",
        "projects.read", "projects.create", "projects.edit",
        "analytics.view", "analytics.export", "reports.export",
        "sprints.manage", "releases.manage", "issues.edit_bug_fields"
    )
    private val admin = manager + setOf(
        "members.manage", "members.remove",
        "projects.delete", "projects.archive",
        "org.settings", "audit_log.view"
    )

    fun permissionsFor(role: String): Set<String> = when (role.lowercase()) {
        "owner" -> all
        "admin" -> admin
        "manager" -> manager
        "member" -> member
        "viewer" -> viewer
        else -> guest
    }

    val total: Int get() = all.size

    fun displayName(role: String) = role.replaceFirstChar { it.uppercase() }

    fun summary(role: String) = when (role.lowercase()) {
        "owner" -> "Full ownership: billing, workspace deletion, and every admin capability."
        "admin" -> "Team management, member roles, workspace settings, and audit log access."
        "manager" -> "Sprint and release planning, inviting teammates, and analytics export."
        "member" -> "Standard contributor: create and edit tasks, comment, and upload files."
        "viewer" -> "Read-only visibility into tasks, projects, and analytics."
        else -> "Restricted access to assigned tasks and notifications only."
    }

    /** Same palette as TeamScreen / iOS / web console. */
    fun color(role: String): Color = when (role.lowercase()) {
        "owner" -> Color(0xFF6E56CF)
        "admin" -> Color(0xFF007AFF)
        "manager" -> Color(0xFFFF9500)
        "member" -> Color(0xFF34C759)
        else -> Color(0xFF8E8E93)
    }

    /** "tasks.create_subtask" -> "Create subtask" */
    fun label(permission: String): String =
        permission.substringAfterLast('.').replace('_', ' ').replaceFirstChar { it.uppercase() }
}

/**
 * Human-friendly client label and icon for a UserSessionDTO JSON row.
 * Matches `UserSessionDTO.clientLabel` / `deviceSymbol` on iOS.
 */
fun sessionClientLabel(session: JsonObject): String {
    val ua = session.text("user_agent", session.text("userAgent")).lowercase()
    val deviceType = session.text("device_type", session.text("deviceType"))
    return when {
        "okhttp" in ua || "android" in ua -> "Android App"
        "cfnetwork" in ua || "darwin" in ua || "enterpriseapp" in ua -> "iOS App"
        "edg/" in ua -> "Edge"
        "chrome" in ua -> "Chrome"
        "firefox" in ua -> "Firefox"
        "safari" in ua -> "Safari"
        "curl" in ua -> "Command Line"
        deviceType.isNotBlank() -> deviceType.replaceFirstChar { it.uppercase() }
        else -> "Unknown client"
    }
}

fun sessionDeviceIcon(session: JsonObject): ImageVector {
    val combined = (
        session.text("device_type", session.text("deviceType")) + " " +
            session.text("user_agent", session.text("userAgent"))
        ).lowercase()
    return when {
        "ios" in combined || "iphone" in combined || "android" in combined ||
            "mobile" in combined || "cfnetwork" in combined || "okhttp" in combined -> Icons.Default.Smartphone
        "ipad" in combined || "tablet" in combined -> Icons.Default.Tablet
        else -> Icons.Default.Laptop
    }
}

@Composable
fun RolesPermissionsScreen(vm: AppViewModel, api: ApiClient) {
    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text("Roles & Permissions", style = AppTypography.largeTitle, color = AppColors.textPrimary)
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        RolesPermissionsContent(vm = vm, api = api, modifier = Modifier.fillMaxSize())
    }
}

@Composable
fun RolesPermissionsModal(
    vm: AppViewModel,
    api: ApiClient,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .padding(vertical = 12.dp)
                .testTag("modal_roles_permissions"),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.backgroundPrimary)
        ) {
            Column(Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppColors.surfacePrimary)
                        .padding(horizontal = 20.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("Roles & Permissions", style = AppTypography.title2, color = AppColors.textPrimary)
                        Text(
                            "Organization RBAC capability matrix",
                            style = AppTypography.caption1,
                            color = AppColors.textSecondary
                        )
                    }
                    IconButton(onClick = onDismiss, modifier = Modifier.testTag("btn_close_roles_modal")) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                RolesPermissionsContent(vm = vm, api = api, modifier = Modifier.fillMaxSize())
            }
        }
    }
}

@Composable
fun RolesPermissionsContent(
    vm: AppViewModel,
    api: ApiClient,
    modifier: Modifier = Modifier
) {
    val me = rememberRemote(api, "/api/me", vm.revision, query = mapOf("org_id" to api.orgId))
    val myRole = me.data.obj().text("role").lowercase().ifBlank { null }

    var selectedRole by rememberSaveable { mutableStateOf<String?>(null) }
    val activeRole = selectedRole ?: myRole ?: "member"
    var selectedCategory by rememberSaveable { mutableStateOf<String?>(null) }
    val granted = RolePermissions.permissionsFor(activeRole)
    val visibleCategories = RolePermissions.categories.filter { selectedCategory == null || it.first == selectedCategory }

    Column(modifier) {
        RemoteStatus(me)

        LazyColumn(
            modifier = Modifier.fillMaxSize().testTag("roles_matrix_list"),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (myRole != null) {
                item {
                    IosCard(Modifier.fillMaxWidth(), contentPadding = 16.dp) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            RolePill(myRole, selected = false)
                            Spacer(Modifier.width(12.dp))
                            Column {
                                Text("Your role in this workspace", style = AppTypography.caption1, color = AppColors.textSecondary)
                                Text(
                                    "${RolePermissions.permissionsFor(myRole).size} of ${RolePermissions.total} permissions",
                                    style = AppTypography.headline,
                                    color = AppColors.textPrimary
                                )
                            }
                        }
                    }
                }
            }

            item {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    RolePermissions.roles.forEach { role ->
                        val label = RolePermissions.displayName(role) + if (role == myRole) " (You)" else ""
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(AppRadius.pill))
                                .background(if (role == activeRole) RolePermissions.color(role) else AppColors.surfaceElevated)
                                .clickable { selectedRole = role }
                                .padding(horizontal = 14.dp, vertical = 8.dp)
                                .testTag("role_chip_$role")
                        ) {
                            Text(
                                label,
                                style = AppTypography.subheadline,
                                color = if (role == activeRole) Color.White else AppColors.textPrimary
                            )
                        }
                    }
                }
                Spacer(Modifier.height(8.dp))
                Text(RolePermissions.summary(activeRole), style = AppTypography.caption1, color = AppColors.textSecondary)
            }

            item {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    FilterChip(
                        selected = selectedCategory == null,
                        onClick = { selectedCategory = null },
                        label = { Text("All") }
                    )
                    RolePermissions.categories.forEach { (category, _) ->
                        FilterChip(
                            selected = selectedCategory == category,
                            onClick = { selectedCategory = category },
                            label = { Text(category) }
                        )
                    }
                }
            }

            items(visibleCategories, key = { it.first }) { (category, permissions) ->
                IosCard(Modifier.fillMaxWidth(), contentPadding = 16.dp) {
                    Text(category, style = AppTypography.headline, color = AppColors.textPrimary)
                    Spacer(Modifier.height(8.dp))
                    permissions.forEachIndexed { index, permission ->
                        val allowed = permission in granted
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text(RolePermissions.label(permission), style = AppTypography.body, color = AppColors.textPrimary)
                                Text(permission, style = AppTypography.caption2, color = AppColors.textTertiary)
                            }
                            Icon(
                                imageVector = if (allowed) Icons.Default.CheckCircle else Icons.Default.Cancel,
                                contentDescription = if (allowed) "Allowed" else "Not allowed",
                                tint = if (allowed) AppColors.statusSuccess else AppColors.textTertiary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                        if (index < permissions.lastIndex) {
                            HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun SecuritySessionsModal(
    vm: AppViewModel,
    api: ApiClient,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .padding(vertical = 12.dp)
                .testTag("modal_security_sessions"),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.backgroundPrimary)
        ) {
            Column(Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppColors.surfacePrimary)
                        .padding(horizontal = 20.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("Security & Sessions", style = AppTypography.title2, color = AppColors.textPrimary)
                        Text(
                            "Review and revoke active devices",
                            style = AppTypography.caption1,
                            color = AppColors.textSecondary
                        )
                    }
                    IconButton(onClick = onDismiss, modifier = Modifier.testTag("btn_close_sessions_modal")) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                SecuritySessionsContent(vm = vm, api = api, modifier = Modifier.fillMaxSize())
            }
        }
    }
}

@Composable
fun SecuritySessionsContent(
    vm: AppViewModel,
    api: ApiClient,
    modifier: Modifier = Modifier
) {
    val remote = rememberRemote(api, "/api/me/sessions", vm.revision)
    var selected by remember { mutableStateOf<JsonObject?>(null) }
    val sessions = remote.data.rows()

    Column(modifier) {
        RemoteStatus(remote)

        LazyColumn(
            modifier = Modifier.fillMaxSize().testTag("sessions_list"),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            item {
                IosCard(Modifier.fillMaxWidth(), contentPadding = 16.dp) {
                    Row(verticalAlignment = Alignment.Top) {
                        Icon(
                            Icons.Default.Security,
                            contentDescription = null,
                            tint = AppColors.brandPrimary,
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text("Active sessions (${sessions.size})", style = AppTypography.headline, color = AppColors.textPrimary)
                            Spacer(Modifier.height(2.dp))
                            Text(
                                "These devices are currently signed in to your account. Revoke any session you don't recognise.",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                        }
                    }
                }
            }

            items(sessions, key = { it.id }) { session ->
                val clientLabel = sessionClientLabel(session)
                val ip = session.text("ip_address", session.text("ipAddress")).ifBlank { "Unknown IP" }
                val createdAt = session.text("created_at", session.text("createdAt"))
                val expiresAt = session.text("expires_at", session.text("expiresAt"))

                IosCard(Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .clip(RoundedCornerShape(AppRadius.small))
                                .background(AppColors.brandPrimary.copy(alpha = 0.12f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(sessionDeviceIcon(session), null, tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                        }
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(clientLabel, style = AppTypography.headline, color = AppColors.textPrimary)
                            Text(ip, style = AppTypography.caption1, color = AppColors.textSecondary)
                            if (createdAt.isNotBlank()) {
                                Text("Signed in ${dateLabel(createdAt)}", style = AppTypography.caption2, color = AppColors.textTertiary)
                            }
                            if (expiresAt.isNotBlank()) {
                                Text("Expires ${dateLabel(expiresAt)}", style = AppTypography.caption2, color = AppColors.textTertiary)
                            }
                        }
                        IconButton(
                            onClick = { selected = session },
                            modifier = Modifier.testTag("btn_revoke_session_${session.id}")
                        ) {
                            Icon(Icons.AutoMirrored.Filled.Logout, "Revoke session", tint = AppColors.statusError, modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }
        }
    }

    selected?.let { session ->
        val clientLabel = sessionClientLabel(session)
        val ip = session.text("ip_address", session.text("ipAddress")).ifBlank { "Unknown IP" }
        ConfirmDialog(
            title = "Revoke this session?",
            message = "$clientLabel ($ip) will be signed out and must log in again.",
            onDismiss = { selected = null }
        ) {
            api.request("/api/me/sessions/${session.id}", "DELETE")
            selected = null
            remote.refresh()
            vm.changed()
        }
    }
}

@Composable
private fun RolePill(role: String, selected: Boolean) {
    val color = RolePermissions.color(role)
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(AppRadius.pill))
            .background(if (selected) color else color.copy(alpha = 0.15f))
            .padding(horizontal = 10.dp, vertical = 4.dp)
    ) {
        Text(
            RolePermissions.displayName(role),
            style = AppTypography.caption1,
            fontWeight = FontWeight.SemiBold,
            color = if (selected) Color.White else color
        )
    }
}

private val auditCategories = listOf(
    "all" to "All",
    "members" to "Members & Roles",
    "security" to "Security & Sessions",
    "channels" to "Channels",
    "settings" to "Settings & Compliance",
    "tasks" to "Tasks & Projects"
)

fun auditCategoryFor(entry: JsonObject): String {
    val action = entry.text("action").lowercase()
    val resource = entry.text("resource_type", entry.text("resourceType")).lowercase()
    return when {
        "member" in action || "invite" in action || "join_request" in action || resource == "member" || resource == "invite" -> "members"
        "session" in action || "sso" in action || "auth" in action || resource == "session" -> "security"
        "channel" in action || "message" in action || resource == "channel" -> "channels"
        "retention" in action || "compliance" in action || "branding" in action || "org." in action || resource == "org" -> "settings"
        else -> "tasks"
    }
}

fun auditActionColor(action: String): Color {
    val a = action.lowercase()
    return when {
        "delete" in a || "remove" in a || "revoke" in a || "suspend" in a -> Color(0xFFFF3B30)
        "lock" in a || "archive" in a || "purge" in a -> Color(0xFFFF9500)
        "create" in a || "invite" in a || "accept" in a -> Color(0xFF34C759)
        "session" in a -> Color(0xFF6E56CF)
        else -> Color(0xFF007AFF)
    }
}

@Composable
fun AuditLogScreen(vm: AppViewModel, api: ApiClient) {
    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text("Workspace Audit Log", style = AppTypography.largeTitle, color = AppColors.textPrimary)
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        AuditLogContent(vm = vm, api = api, modifier = Modifier.fillMaxSize())
    }
}

@Composable
fun AuditLogModal(
    vm: AppViewModel,
    api: ApiClient,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .padding(vertical = 12.dp)
                .testTag("modal_audit_log"),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.backgroundPrimary)
        ) {
            Column(Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppColors.surfacePrimary)
                        .padding(horizontal = 20.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("Workspace Audit Log", style = AppTypography.title2, color = AppColors.textPrimary)
                        Text(
                            "Real-time security and governance trail",
                            style = AppTypography.caption1,
                            color = AppColors.textSecondary
                        )
                    }
                    IconButton(onClick = onDismiss, modifier = Modifier.testTag("btn_close_audit_modal")) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                AuditLogContent(vm = vm, api = api, modifier = Modifier.fillMaxSize())
            }
        }
    }
}

@Composable
fun AuditLogContent(
    vm: AppViewModel,
    api: ApiClient,
    modifier: Modifier = Modifier
) {
    val remote = rememberRemote(
        api = api,
        path = "/api/organizations/${api.orgId}/audit-log",
        revision = vm.revision,
        query = mapOf("limit" to "200")
    )
    var search by rememberSaveable { mutableStateOf("") }
    var selectedCategory by rememberSaveable { mutableStateOf("all") }

    val allLogs = remote.data.rows()
    val filteredLogs = remember(allLogs, search, selectedCategory) {
        val q = search.trim().lowercase()
        allLogs.filter { entry ->
            if (selectedCategory != "all" && auditCategoryFor(entry) != selectedCategory) return@filter false
            if (q.isEmpty()) return@filter true
            val action = entry.text("action").lowercase()
            val email = entry.text("user_email", entry.text("userEmail")).lowercase()
            val resource = entry.text("resource_type", entry.text("resourceType")).lowercase()
            val details = entry.text("details").lowercase()
            q in action || q in email || q in resource || q in details
        }
    }

    Column(modifier) {
        RemoteStatus(remote)

        LazyColumn(
            modifier = Modifier.fillMaxSize().testTag("audit_log_list"),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            item {
                OutlinedTextField(
                    value = search,
                    onValueChange = { search = it },
                    placeholder = { Text("Search action, actor email, or details…") },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("audit_search_input")
                )
            }

            item {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    auditCategories.forEach { (id, label) ->
                        FilterChip(
                            selected = selectedCategory == id,
                            onClick = { selectedCategory = id },
                            label = { Text(label) }
                        )
                    }
                }
            }

            if (!remote.loading && remote.error == null && filteredLogs.isEmpty()) {
                item {
                    IosCard(Modifier.fillMaxWidth(), contentPadding = 20.dp) {
                        Text("No matching audit entries.", style = AppTypography.body, color = AppColors.textSecondary)
                    }
                }
            }

            items(filteredLogs, key = { it.id }) { entry ->
                val action = entry.text("action")
                val email = entry.text("user_email", entry.text("userEmail", "system")).ifBlank { "system" }
                val resourceType = entry.text("resource_type", entry.text("resourceType"))
                val resourceId = entry.text("resource_id", entry.text("resourceId"))
                val details = entry.text("details")
                val createdAt = entry.text("created_at", entry.text("createdAt"))
                val color = auditActionColor(action)

                IosCard(Modifier.fillMaxWidth(), contentPadding = 14.dp) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(AppRadius.pill))
                                .background(color.copy(alpha = 0.15f))
                                .padding(horizontal = 10.dp, vertical = 3.dp)
                        ) {
                            Text(action, style = AppTypography.caption1, fontWeight = FontWeight.SemiBold, color = color)
                        }
                        Spacer(Modifier.weight(1f))
                        if (createdAt.isNotBlank()) {
                            Text(dateLabel(createdAt), style = AppTypography.caption2, color = AppColors.textTertiary)
                        }
                    }
                    if (details.isNotBlank()) {
                        Spacer(Modifier.height(6.dp))
                        Text(details, style = AppTypography.subheadline, color = AppColors.textPrimary)
                    }
                    Spacer(Modifier.height(4.dp))
                    Text(
                        buildString {
                            append(email)
                            if (resourceType.isNotBlank()) {
                                append(" · ")
                                append(resourceType)
                                if (resourceId.isNotBlank()) append(" #${resourceId.take(8)}")
                            }
                        },
                        style = AppTypography.caption1,
                        color = AppColors.textSecondary
                    )
                }
            }
        }
    }
}

// ============================================================================
// Workspace Branding, Enterprise SSO & Compliance Controls
// ============================================================================

@Composable
fun WorkspaceGovernanceScreen(vm: AppViewModel, api: ApiClient) {
    Column(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .padding(horizontal = 16.dp, vertical = 10.dp)
        ) {
            Text("Branding, SSO & Compliance", style = AppTypography.largeTitle, color = AppColors.textPrimary)
        }
        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        WorkspaceGovernanceContent(vm = vm, api = api, modifier = Modifier.fillMaxSize())
    }
}

@Composable
fun WorkspaceGovernanceModal(
    vm: AppViewModel,
    api: ApiClient,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.92f)
                .padding(vertical = 12.dp)
                .testTag("modal_workspace_governance"),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary)
        ) {
            Column(Modifier.fillMaxSize()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("Branding, SSO & Compliance", style = AppTypography.title2, color = AppColors.textPrimary)
                        Text(
                            "Brand identity, verified domain auto-join, SAML 2.0 SSO, and message retention.",
                            style = AppTypography.caption1,
                            color = AppColors.textSecondary
                        )
                    }
                    IconButton(onClick = onDismiss, modifier = Modifier.testTag("btn_close_workspace_governance")) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

                WorkspaceGovernanceContent(vm = vm, api = api, modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
fun WorkspaceGovernanceContent(
    vm: AppViewModel,
    api: ApiClient,
    modifier: Modifier = Modifier
) {
    val orgRemote = rememberRemote(api, "/api/organizations/${api.orgId}", vm.revision)
    val retentionRemote = rememberRemote(api, "/api/admin/org/retention", vm.revision)
    val action = rememberAction()
    val clipboard = LocalClipboardManager.current

    var selectedTab by rememberSaveable { mutableIntStateOf(0) } // 0 = Branding & Domains, 1 = Enterprise SSO, 2 = Retention & Compliance
    var hydratedRevision by rememberSaveable { mutableIntStateOf(-1) }

    // Branding & Domain state
    var logoUrl by rememberSaveable { mutableStateOf("") }
    var brandColorHex by rememberSaveable { mutableStateOf("#3B82F6") }
    var customDomain by rememberSaveable { mutableStateOf("") }
    var allowedEmailDomains by rememberSaveable { mutableStateOf("") }

    // Enterprise SSO state
    var ssoEnabled by rememberSaveable { mutableStateOf(false) }
    var ssoEntityId by rememberSaveable { mutableStateOf("") }
    var ssoIdpUrl by rememberSaveable { mutableStateOf("") }
    var ssoCertificate by rememberSaveable { mutableStateOf("") }

    // Retention & Compliance state
    var retentionDaysText by rememberSaveable { mutableStateOf("0") }
    var lastPurgeSummary by rememberSaveable { mutableStateOf<String?>(null) }
    var lastExportSummary by rememberSaveable { mutableStateOf<String?>(null) }
    var lastExportUrl by rememberSaveable { mutableStateOf<String?>(null) }
    var statusNotice by rememberSaveable { mutableStateOf<String?>(null) }

    val orgObj = orgRemote.data.obj()
    val retentionObj = retentionRemote.data.obj()

    LaunchedEffect(orgObj, retentionObj, vm.revision) {
        if (orgObj.size() > 0 && hydratedRevision != vm.revision) {
            hydratedRevision = vm.revision
            logoUrl = orgObj.text("logo_url", orgObj.text("logoUrl"))
            brandColorHex = orgObj.text("brand_color_hex", orgObj.text("brandColorHex", "#3B82F6")).ifBlank { "#3B82F6" }
            customDomain = orgObj.text("custom_domain", orgObj.text("customDomain"))
            allowedEmailDomains = orgObj.text("allowed_email_domains", orgObj.text("allowedEmailDomains"))
            ssoEnabled = orgObj.bool("sso_enabled", orgObj.bool("ssoEnabled", false))
            ssoEntityId = orgObj.text("sso_entity_id", orgObj.text("ssoEntityId"))
            ssoIdpUrl = orgObj.text("sso_idp_url", orgObj.text("ssoIdpUrl"))
            ssoCertificate = orgObj.text("sso_certificate", orgObj.text("ssoCertificate"))
            val retDays = retentionObj.int(
                "retention_days",
                retentionObj.int(
                    "retentionDays",
                    orgObj.int("retention_days", orgObj.int("retentionDays", 0))
                )
            )
            retentionDaysText = retDays.toString()
        }
    }

    val tabs = listOf(
        0 to "Branding & Domains",
        1 to "Enterprise SSO",
        2 to "Retention & Compliance"
    )

    Column(modifier) {
        RemoteStatus(orgRemote)
        ActionStatus(action)

        statusNotice?.let { msg ->
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.statusSuccess.copy(alpha = 0.14f))
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            ) {
                Text(msg, style = AppTypography.caption1, color = AppColors.statusSuccess, fontWeight = FontWeight.SemiBold)
            }
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize().testTag("workspace_governance_list"),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    tabs.forEach { (id, title) ->
                        FilterChip(
                            selected = selectedTab == id,
                            onClick = { selectedTab = id },
                            label = { Text(title) },
                            modifier = Modifier.testTag("gov_tab_$id")
                        )
                    }
                }
            }

            when (selectedTab) {
                0 -> {
                    item {
                        IosCard(Modifier.fillMaxWidth(), contentPadding = 16.dp) {
                            Text("Brand Identity", style = AppTypography.headline, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(4.dp))
                            Text(
                                "Customize logo, primary and accent colors, and optional CSS variables.",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                            Spacer(Modifier.height(12.dp))

                            OutlinedTextField(
                                value = logoUrl,
                                onValueChange = { logoUrl = it },
                                label = { Text("Logo URL") },
                                placeholder = { Text("https://cdn.acme.com/logo.png") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("input_brand_logo_url")
                            )
                            Spacer(Modifier.height(10.dp))

                            OutlinedTextField(
                                value = brandColorHex,
                                onValueChange = { brandColorHex = it },
                                label = { Text("Brand Color Hex") },
                                placeholder = { Text("#3B82F6") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("input_brand_primary_hex")
                            )
                            Spacer(Modifier.height(12.dp))

                            Button(
                                onClick = {
                                    action.run {
                                        api.request(
                                            "/api/organizations/${api.orgId}/branding",
                                            "PUT",
                                            json(
                                                "logo_url" to logoUrl.trim().ifBlank { null },
                                                "brand_color_hex" to brandColorHex.trim().ifBlank { null }
                                            )
                                        )
                                        statusNotice = "Brand identity saved."
                                        orgRemote.refresh()
                                        vm.changed()
                                    }
                                },
                                enabled = !action.busy,
                                modifier = Modifier.fillMaxWidth().testTag("btn_save_branding"),
                                colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary)
                            ) {
                                Text("Save Branding")
                            }
                        }
                    }

                    item {
                        IosCard(Modifier.fillMaxWidth(), contentPadding = 16.dp) {
                            Text("Domain & Auto-Join Governance", style = AppTypography.headline, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(4.dp))
                            Text(
                                "Configure custom workspace domain mapping and verified corporate email domains eligible for auto-join.",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                            Spacer(Modifier.height(12.dp))

                            OutlinedTextField(
                                value = customDomain,
                                onValueChange = { customDomain = it },
                                label = { Text("Custom Workspace Domain") },
                                placeholder = { Text("tasks.acme.com") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("input_custom_domain")
                            )
                            Spacer(Modifier.height(10.dp))

                            OutlinedTextField(
                                value = allowedEmailDomains,
                                onValueChange = { allowedEmailDomains = it },
                                label = { Text("Allowed Email Domains (Auto-Join)") },
                                placeholder = { Text("acme.com, engineering.acme.com") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("input_allowed_domains")
                            )
                            Spacer(Modifier.height(12.dp))

                            Button(
                                onClick = {
                                    action.run {
                                        api.request(
                                            "/api/organizations/${api.orgId}/domain-settings",
                                            "PUT",
                                            json(
                                                "custom_domain" to customDomain.trim().ifBlank { null },
                                                "allowed_email_domains" to allowedEmailDomains.trim().ifBlank { null }
                                            )
                                        )
                                        statusNotice = "Domain governance policy saved."
                                        orgRemote.refresh()
                                        vm.changed()
                                    }
                                },
                                enabled = !action.busy,
                                modifier = Modifier.fillMaxWidth().testTag("btn_save_domain_policy"),
                                colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary)
                            ) {
                                Text("Save Domain Policy")
                            }
                        }
                    }
                }

                1 -> {
                    item {
                        IosCard(Modifier.fillMaxWidth(), contentPadding = 16.dp) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Column(Modifier.weight(1f)) {
                                    Text("SAML 2.0 Identity Provider", style = AppTypography.headline, fontWeight = FontWeight.Bold)
                                    Text(
                                        "Connect Okta, Microsoft Entra ID, Google Workspace, or Ping Identity.",
                                        style = AppTypography.caption1,
                                        color = AppColors.textSecondary
                                    )
                                }
                                Switch(
                                    checked = ssoEnabled,
                                    onCheckedChange = { ssoEnabled = it },
                                    modifier = Modifier.testTag("switch_sso_enabled")
                                )
                            }
                            Spacer(Modifier.height(12.dp))

                            OutlinedTextField(
                                value = ssoEntityId,
                                onValueChange = { ssoEntityId = it },
                                label = { Text("Identity Provider Entity ID (Issuer URI)") },
                                placeholder = { Text("http://www.okta.com/exk1234567890") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("input_sso_entity_id")
                            )
                            Spacer(Modifier.height(10.dp))

                            OutlinedTextField(
                                value = ssoIdpUrl,
                                onValueChange = { ssoIdpUrl = it },
                                label = { Text("SSO Entry Point URL (HTTP-POST / Redirect)") },
                                placeholder = { Text("https://acme.okta.com/app/taskflow/sso/saml") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("input_sso_url")
                            )
                            Spacer(Modifier.height(10.dp))

                            OutlinedTextField(
                                value = ssoCertificate,
                                onValueChange = { ssoCertificate = it },
                                label = { Text("X.509 Public Certificate (PEM)") },
                                placeholder = { Text("-----BEGIN CERTIFICATE-----\nMIIDpDCCAoygAwIBAgIG...\n-----END CERTIFICATE-----") },
                                minLines = 3,
                                maxLines = 6,
                                modifier = Modifier.fillMaxWidth().testTag("input_sso_cert_pem")
                            )
                            Spacer(Modifier.height(12.dp))

                            Button(
                                onClick = {
                                    action.run {
                                        api.request(
                                            "/api/organizations/${api.orgId}/sso-settings",
                                            "PUT",
                                            json(
                                                "sso_enabled" to ssoEnabled,
                                                "sso_entity_id" to ssoEntityId.trim().ifBlank { null },
                                                "sso_idp_url" to ssoIdpUrl.trim().ifBlank { null },
                                                "sso_certificate" to ssoCertificate.trim().ifBlank { null }
                                            )
                                        )
                                        statusNotice = "Enterprise SSO configuration saved."
                                        orgRemote.refresh()
                                        vm.changed()
                                    }
                                },
                                enabled = !action.busy,
                                modifier = Modifier.fillMaxWidth().testTag("btn_save_sso"),
                                colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary)
                            ) {
                                Text("Save SSO Configuration")
                            }
                        }
                    }
                }

                2 -> {
                    item {
                        IosCard(Modifier.fillMaxWidth(), contentPadding = 16.dp) {
                            Text("Automated Message Retention", style = AppTypography.headline, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(4.dp))
                            Text(
                                "Set to 0 to keep channel and direct messages indefinitely, or between 1 and 3650 days.",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                            Spacer(Modifier.height(12.dp))

                            OutlinedTextField(
                                value = retentionDaysText,
                                onValueChange = { retentionDaysText = it.filter { ch -> ch.isDigit() } },
                                label = { Text("Retention Window (Days)") },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth().testTag("input_retention_days")
                            )
                            Spacer(Modifier.height(8.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                listOf(
                                    "0" to "Indefinite (0d)",
                                    "30" to "30 Days",
                                    "90" to "90 Days",
                                    "365" to "365 Days"
                                ).forEach { (days, label) ->
                                    FilterChip(
                                        selected = retentionDaysText == days,
                                        onClick = { retentionDaysText = days },
                                        label = { Text(label) }
                                    )
                                }
                            }
                            Spacer(Modifier.height(10.dp))

                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                                Button(
                                    onClick = {
                                        val days = (retentionDaysText.toIntOrNull() ?: 0).coerceIn(0, 3650)
                                        retentionDaysText = days.toString()
                                        action.run {
                                            api.request(
                                                "/api/admin/org/retention",
                                                "PUT",
                                                json("retention_days" to if (days > 0) days else null)
                                            )
                                            statusNotice = if (days == 0) {
                                                "Message retention set to indefinite."
                                            } else {
                                                "Message retention set to $days days."
                                            }
                                            retentionRemote.refresh()
                                            orgRemote.refresh()
                                            vm.changed()
                                        }
                                    },
                                    enabled = !action.busy,
                                    modifier = Modifier.weight(1f).testTag("btn_save_retention"),
                                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary)
                                ) {
                                    Text("Save Policy")
                                }

                                OutlinedButton(
                                    onClick = {
                                        action.run {
                                            val res = api.request("/api/admin/org/retention/purge-now", "POST").data.obj()
                                            val purged = res.int("deleted_count", res.int("deletedCount", res.int("purged_messages", 0)))
                                            lastPurgeSummary = "Purged $purged expired messages"
                                            statusNotice = "Retention sweep completed ($purged messages purged)."
                                            vm.changed()
                                        }
                                    },
                                    enabled = !action.busy && (retentionDaysText.toIntOrNull() ?: 0) > 0,
                                    modifier = Modifier.weight(1f).testTag("btn_purge_expired_now")
                                ) {
                                    Text("Purge Now")
                                }
                            }

                            lastPurgeSummary?.let { summary ->
                                Spacer(Modifier.height(8.dp))
                                Text(summary, style = AppTypography.caption1, color = AppColors.statusWarning)
                            }
                        }
                    }

                    item {
                        IosCard(Modifier.fillMaxWidth(), contentPadding = 16.dp) {
                            Text("Signed Compliance Export", style = AppTypography.headline, fontWeight = FontWeight.Bold)
                            Spacer(Modifier.height(4.dp))
                            Text(
                                "Generate a signed, time-limited compliance archive containing workspace members, channels, projects, tasks, and recent audit logs.",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                            Spacer(Modifier.height(12.dp))

                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                                Button(
                                    onClick = {
                                        action.run {
                                            val res = api.request("/api/admin/org/export?format=json", "POST").data.obj()
                                            val fmt = res.text("format", "json").uppercase()
                                            val bytes = res.int("size_bytes", res.int("sizeBytes", res.int("byte_size", 0)))
                                            val exp = res.text("expires_at", res.text("expiresAt"))
                                            val dl = res.text("download_url", res.text("downloadUrl"))
                                            lastExportSummary = "$fmt archive (${bytes / 1024} KB) · Expires $exp"
                                            lastExportUrl = dl
                                            statusNotice = "Signed JSON compliance export generated."
                                        }
                                    },
                                    enabled = !action.busy,
                                    modifier = Modifier.weight(1f).testTag("btn_export_compliance_json"),
                                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary)
                                ) {
                                    Text("Export JSON")
                                }

                                OutlinedButton(
                                    onClick = {
                                        action.run {
                                            val res = api.request("/api/admin/org/export?format=csv", "POST").data.obj()
                                            val fmt = res.text("format", "csv").uppercase()
                                            val bytes = res.int("size_bytes", res.int("sizeBytes", res.int("byte_size", 0)))
                                            val exp = res.text("expires_at", res.text("expiresAt"))
                                            val dl = res.text("download_url", res.text("downloadUrl"))
                                            lastExportSummary = "$fmt archive (${bytes / 1024} KB) · Expires $exp"
                                            lastExportUrl = dl
                                            statusNotice = "Signed CSV compliance export generated."
                                        }
                                    },
                                    enabled = !action.busy,
                                    modifier = Modifier.weight(1f).testTag("btn_export_compliance_csv")
                                ) {
                                    Text("Export CSV")
                                }
                            }

                            lastExportSummary?.let { summary ->
                                Spacer(Modifier.height(10.dp))
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clip(RoundedCornerShape(AppRadius.medium))
                                        .background(AppColors.surfaceElevated)
                                        .padding(12.dp),
                                    verticalArrangement = Arrangement.spacedBy(6.dp)
                                ) {
                                    Text(summary, style = AppTypography.caption1, fontWeight = FontWeight.SemiBold, color = AppColors.textPrimary)
                                    lastExportUrl?.takeIf { it.isNotBlank() }?.let { url ->
                                        Text(url, style = AppTypography.caption2, color = AppColors.textSecondary)
                                        TextButton(
                                            onClick = {
                                                clipboard.setText(AnnotatedString(url))
                                                statusNotice = "Signed export download path copied to clipboard."
                                            }
                                        ) {
                                            Icon(Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(16.dp))
                                            Spacer(Modifier.width(6.dp))
                                            Text("Copy Signed Download URL")
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
