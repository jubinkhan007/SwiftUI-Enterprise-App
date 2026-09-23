package com.acme.taskflow.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.acme.taskflow.data.*
import com.acme.taskflow.model.Destination
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.screens.*
import com.acme.taskflow.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.retryWhen
import kotlinx.coroutines.launch

@Composable
fun TaskFlowApp(vm: AppViewModel = viewModel()) {
    val context = LocalContext.current
    LaunchedEffect(vm.user, vm.workspace, vm.server) {
        runCatching {
            if (vm.user != null && vm.workspace != null) {
                NotificationService.start(context, vm.server, vm.sessionToken, vm.workspace?.id.orEmpty())
            } else {
                NotificationService.stop(context)
            }
        }
    }
    val api = remember(vm.user, vm.workspace, vm.server) { vm.api }
    if (vm.user == null) AuthScreen(vm)
    else if (vm.workspace == null) WorkspaceScreen(vm, api)
    else key(vm.workspace?.id) { AuthenticatedShell(vm, api) }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AuthenticatedShell(vm: AppViewModel, api: ApiClient) {
    var destination by rememberSaveable { mutableStateOf(Destination.AllTasks) }
    var listId by rememberSaveable { mutableStateOf("") }
    var listName by rememberSaveable { mutableStateOf("") }
    var projectId by rememberSaveable { mutableStateOf("") }
    var showNavigation by rememberSaveable { mutableStateOf(true) }
    var hierarchyEditor by remember { mutableStateOf<Pair<String, String>?>(null) }
    var showCreateHierarchy by remember { mutableStateOf(false) }
    var showSyncCenter by remember { mutableStateOf(false) }
    var showUserMenu by remember { mutableStateOf(false) }
    var showWorkspaceSwitcher by remember { mutableStateOf(false) }

    val drawer = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    val wide = LocalConfiguration.current.screenWidthDp >= 840
    val hierarchy = rememberRemote(api, "/api/hierarchy", vm.revision)
    val me = rememberRemote(api, "/api/me", query = mapOf("org_id" to api.orgId))
    val lifecycleOwner = LocalLifecycleOwner.current
    var live by remember { mutableStateOf(false) }

    LaunchedEffect(api, lifecycleOwner) {
        lifecycleOwner.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            api.events().retryWhen { _, attempt ->
                live = false
                delay((1000L * (1L shl attempt.coerceAtMost(5).toInt())).coerceAtMost(30000L))
                true
            }.collect { event ->
                if (event.text("type") == "connection.open") live = true
                if (event.text("type") !in listOf("pong", "typing.started", "typing.stopped")) vm.changed()
            }
        }
    }

    val sidebar: @Composable () -> Unit = {
        Column(
            Modifier
                .width(300.dp)
                .fillMaxHeight()
                .background(AppColors.backgroundSecondary)
                .padding(16.dp)
        ) {
            // Header Workspace Switcher matching SidebarView.swift
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(AppRadius.medium))
                    .background(AppColors.surfacePrimary)
                    .clickable { showWorkspaceSwitcher = true }
                    .padding(12.dp)
                    .testTag("workspace_header_switcher"),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(RoundedCornerShape(AppRadius.small))
                        .background(AppColors.brandPrimary.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.Business, null, tint = AppColors.brandPrimary, modifier = Modifier.size(18.dp))
                }
                Spacer(Modifier.width(10.dp))
                Text(
                    text = vm.workspace?.text("name").orEmpty(),
                    style = AppTypography.headline,
                    color = AppColors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Icon(Icons.Default.UnfoldMore, "Switch", tint = AppColors.textTertiary, modifier = Modifier.size(18.dp))
            }

            Spacer(Modifier.height(16.dp))

            LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                item {
                    IosSectionHeader("Navigation")
                    IosInsetGroupedCard {
                        val navItems = listOf(
                            Destination.AllTasks, Destination.MyTasks, Destination.Inbox,
                            Destination.Messages, Destination.Meetings, Destination.Calls,
                            Destination.Productivity, Destination.Team
                        )
                        navItems.forEachIndexed { index, item ->
                            val isSelected = destination == item && listId.isBlank() && projectId.isBlank()
                            IosGroupedRow(
                                title = item.title,
                                icon = item.icon,
                                iconTint = if (isSelected) AppColors.brandPrimary else Color(0xFF007AFF),
                                showChevron = true,
                                showDivider = index < navItems.lastIndex,
                                onClick = {
                                    destination = item
                                    listId = ""
                                    listName = ""
                                    projectId = ""
                                    showNavigation = false
                                    scope.launch { drawer.close() }
                                }
                            )
                        }
                    }
                }

                item {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        IosSectionHeader("Spaces", Modifier.weight(1f))
                        IconButton(onClick = { hierarchyEditor = "Create space" to "/api/spaces" }) {
                            Icon(Icons.Default.Add, "Create space", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                        }
                    }
                    RemoteStatus(hierarchy)
                }

                hierarchy.data.obj().list("spaces").forEach { space ->
                    item {
                        IosInsetGroupedCard {
                            IosGroupedRow(
                                title = space.child("space").text("name"),
                                icon = Icons.Default.Business,
                                iconTint = Color(0xFF007AFF),
                                showChevron = true,
                                showDivider = space.list("projects").isNotEmpty(),
                                onClick = {
                                    destination = Destination.AllTasks
                                    listId = ""
                                    projectId = ""
                                    listName = space.child("space").text("name")
                                    showNavigation = false
                                    scope.launch { drawer.close() }
                                }
                            )
                            space.list("projects").forEachIndexed { pIndex, project ->
                                IosGroupedRow(
                                    title = project.child("project").text("name"),
                                    icon = Icons.Default.Folder,
                                    iconTint = Color(0xFF5856D6),
                                    showChevron = true,
                                    showDivider = pIndex < space.list("projects").lastIndex || project.list("lists").isNotEmpty(),
                                    modifier = Modifier.padding(start = 16.dp),
                                    onClick = {
                                        projectId = project.child("project").id
                                        listId = ""
                                        listName = project.child("project").text("name")
                                        destination = Destination.AllTasks
                                        showNavigation = false
                                        scope.launch { drawer.close() }
                                    }
                                )
                                project.list("lists").forEachIndexed { lIndex, list ->
                                    IosGroupedRow(
                                        title = list.text("name"),
                                        icon = Icons.AutoMirrored.Filled.List,
                                        iconTint = Color(0xFF8E8E93),
                                        showChevron = true,
                                        showDivider = lIndex < project.list("lists").lastIndex,
                                        modifier = Modifier.padding(start = 32.dp),
                                        onClick = {
                                            listId = list.id
                                            projectId = project.child("project").id
                                            listName = list.text("name")
                                            destination = Destination.AllTasks
                                            showNavigation = false
                                            scope.launch { drawer.close() }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }

            // User footer
            HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle, modifier = Modifier.padding(vertical = 12.dp))
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .clickable { showUserMenu = true },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    AppAvatar(vm.user?.text("display_name").orEmpty())
                    Spacer(Modifier.width(10.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            text = vm.user?.text("display_name").orEmpty(),
                            style = AppTypography.headline,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            text = vm.user?.text("email").orEmpty(),
                            style = AppTypography.caption1,
                            color = AppColors.textSecondary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
                IconButton(onClick = vm::signOut) {
                    Icon(Icons.AutoMirrored.Filled.Logout, "Sign out", tint = AppColors.statusError, modifier = Modifier.size(20.dp))
                }
            }
        }
    }

    var isDetailOpen by rememberSaveable { mutableStateOf(false) }

    val content: @Composable () -> Unit = {
        val lists = hierarchy.data.obj().list("spaces").flatMap { it.list("projects") }.flatMap { node ->
            node.list("lists").map { Choice(it.id, "${node.child("project").text("name")} / ${it.text("name")}") }
        }
        val currentTitle = listName.ifBlank { destination.title }

        Column(
            Modifier
                .fillMaxSize()
                .background(AppColors.backgroundPrimary)
        ) {
            // Top Navigation Bar matching iOS style (hidden when detail view is presented, matching iOS navigation)
            if (!isDetailOpen) {
                IosTopBar(
                    title = currentTitle,
                    backText = if (!wide) "Workspace" else null,
                    onBack = if (!wide) { { showNavigation = true } } else null,
                    actions = {
                        Row(
                            modifier = Modifier
                                .clip(RoundedCornerShape(AppRadius.small))
                                .clickable { showSyncCenter = true }
                                .padding(horizontal = 6.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(if (live) Color(0xFF34C759) else Color(0xFFFF9500))
                            )
                            Spacer(Modifier.width(6.dp))
                            Text(
                                text = if (live) "Live" else "Offline",
                                style = AppTypography.caption2,
                                color = if (live) AppColors.statusSuccess else AppColors.statusWarning
                            )
                        }
                        IconButton(onClick = { vm.changed() }) {
                            Icon(
                                imageVector = Icons.Default.Refresh,
                                contentDescription = "Refresh",
                                tint = AppColors.brandPrimary,
                                modifier = Modifier.size(22.dp)
                            )
                        }
                    }
                )
            }

            if (me.error != null) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(AppColors.statusError.copy(alpha = 0.1f))
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = me.error.orEmpty(),
                        color = AppColors.statusError,
                        style = AppTypography.caption1,
                        modifier = Modifier.weight(1f)
                    )
                    TextButton(onClick = vm::expired) {
                        Text("Sign in again", style = AppTypography.caption1, color = AppColors.brandPrimary)
                    }
                }
            }

            Box(Modifier.weight(1f)) {
                when (destination) {
                    Destination.AllTasks, Destination.MyTasks -> TasksScreen(
                        vm = vm,
                        api = api,
                        lists = lists,
                        listId = listId,
                        mine = destination == Destination.MyTasks,
                        projectId = projectId,
                        onBackToWorkspace = { showNavigation = true },
                        onDetailActive = { isDetailOpen = it }
                    )
                    Destination.Inbox -> InboxScreen(vm, api)
                    Destination.Messages -> MessagesScreen(vm, api, lists)
                    Destination.Meetings -> MeetingsScreen(vm, api)
                    Destination.Calls -> CallsScreen(vm, api)
                    Destination.Productivity -> ProductivityScreen(vm, api)
                    Destination.Team -> TeamScreen(vm, api)
                    Destination.Sessions -> SessionsScreen(vm, api)
                }
            }
        }
    }

    if (!wide && showNavigation) {
        CompactWorkspaceNavigation(
            vm = vm,
            hierarchy = hierarchy,
            onSelect = { item ->
                destination = item
                listId = ""
                listName = ""
                projectId = ""
                showNavigation = false
            },
            onSelectSpace = { spaceId, spaceTitle ->
                destination = Destination.AllTasks
                listId = ""
                listName = spaceTitle
                projectId = ""
                showNavigation = false
            },
            onCreate = { showCreateHierarchy = true },
            onOpenWorkspaceSwitcher = { showWorkspaceSwitcher = true }
        )
    } else if (wide) {
        Row(Modifier.fillMaxSize()) {
            sidebar()
            Box(Modifier.weight(1f)) { content() }
        }
    } else {
        ModalNavigationDrawer(
            drawerState = drawer,
            drawerContent = { ModalDrawerSheet { sidebar() } },
            content = content
        )
    }

    hierarchyEditor?.let { (title, path) ->
        EditorDialog(
            title = title,
            fields = listOf(FormField("name", "Name", required = true)),
            onDismiss = { hierarchyEditor = null }
        ) {
            api.request(path, "POST", it)
            vm.changed()
        }
    }

    if (showCreateHierarchy) {
        CreateHierarchyItemModal(
            hierarchy = hierarchy,
            api = api,
            vm = vm,
            onDismiss = { showCreateHierarchy = false }
        )
    }

    if (showSyncCenter) {
        SyncCenterModal(
            vm = vm,
            api = api,
            isLive = live,
            onDismiss = { showSyncCenter = false }
        )
    }

    if (showUserMenu) {
        ProfileDialog(
            vm = vm,
            onDismiss = { showUserMenu = false },
            onNavigateToTeam = {
                destination = Destination.Team
                listId = ""
                listName = ""
                projectId = ""
                showNavigation = false
                showUserMenu = false
            }
        )
    }

    if (showWorkspaceSwitcher) {
        WorkspaceSwitcherModal(
            vm = vm,
            api = api,
            onDismiss = { showWorkspaceSwitcher = false }
        )
    }
}

@Composable
private fun ProfileDialog(
    vm: AppViewModel,
    onDismiss: () -> Unit,
    onNavigateToTeam: (() -> Unit)? = null
) {
    var name by rememberSaveable { mutableStateOf(vm.user?.text("display_name").orEmpty()) }
    var email by rememberSaveable { mutableStateOf(vm.user?.text("email").orEmpty()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Profile", style = AppTypography.title2) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    AppAvatar(name)
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text(name.ifBlank { "Your profile" }, style = AppTypography.headline)
                        Text(vm.user?.text("role", "Member")?.replaceFirstChar { it.uppercase() } ?: "Member",
                            style = AppTypography.caption1, color = AppColors.textSecondary)
                    }
                }
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Full name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("Email") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                if (onNavigateToTeam != null) {
                    OutlinedButton(
                        onClick = onNavigateToTeam,
                        modifier = Modifier.fillMaxWidth().testTag("btn_profile_team_management")
                    ) {
                        Icon(Icons.Default.Groups, null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Team Management")
                    }
                }
                vm.error?.let { Text(it, color = AppColors.statusError, style = AppTypography.caption1) }
            }
        },
        confirmButton = {
            TextButton(
                enabled = !vm.busy && name.trim().isNotEmpty() && email.contains("@"),
                onClick = {
                    vm.updateProfile(name, email) { onDismiss() }
                }
            ) {
                Text(if (vm.busy) "Saving..." else "Save")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}

// MARK: - Compact Workspace Navigation Screen (Exact 1:1 match to app_running.png)
@Composable
private fun CompactWorkspaceNavigation(
    vm: AppViewModel,
    hierarchy: RemoteState,
    onSelect: (Destination) -> Unit,
    onSelectSpace: (String, String) -> Unit,
    onCreate: () -> Unit,
    onOpenWorkspaceSwitcher: () -> Unit = {}
) {
    val navItems = listOf(
        Destination.AllTasks,
        Destination.MyTasks,
        Destination.Inbox
    )
    val secondaryNavItems = listOf(
        Destination.Messages,
        Destination.Meetings,
        Destination.Calls,
        Destination.Productivity,
        Destination.Team
    )
    val spaces = hierarchy.data.obj().list("spaces")

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.backgroundSecondary)
            .safeDrawingPadding()
            .testTag("compact_nav_list"),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Top action bar with purple plus icon on right (exact match to app_running.png)
        item {
            Row(
                modifier = Modifier.fillMaxWidth().height(44.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onCreate) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "Create",
                        tint = AppColors.brandPrimary,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }
        }

        // Large title "Workspace" (exact match to app_running.png)
        item {
            Text(
                text = "Workspace",
                style = AppTypography.largeTitle,
                color = AppColors.textPrimary,
                modifier = Modifier.padding(bottom = 8.dp)
            )
        }

        // Workspace switcher banner (matching SidebarView.swift)
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(AppRadius.medium))
                    .background(AppColors.surfacePrimary)
                    .clickable { onOpenWorkspaceSwitcher() }
                    .padding(12.dp)
                    .testTag("workspace_header_switcher"),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(RoundedCornerShape(AppRadius.small))
                        .background(AppColors.brandPrimary.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.Business, null, tint = AppColors.brandPrimary, modifier = Modifier.size(18.dp))
                }
                Spacer(Modifier.width(10.dp))
                Text(
                    text = vm.workspace?.text("name").orEmpty().ifBlank { "Select Workspace" },
                    style = AppTypography.headline,
                    color = AppColors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Icon(Icons.Default.UnfoldMore, "Switch", tint = AppColors.textTertiary, modifier = Modifier.size(18.dp))
            }
        }

        // Section "NAVIGATION" (exact match to app_running.png)
        item {
            IosSectionHeader("NAVIGATION")
            IosInsetGroupedCard {
                navItems.forEachIndexed { index, item ->
                    val iconVector = when (item) {
                        Destination.AllTasks -> Icons.Default.Inbox
                        Destination.MyTasks -> Icons.Default.Person
                        Destination.Inbox -> Icons.Default.Mail
                        else -> item.icon
                    }
                    IosGroupedRow(
                        title = item.title,
                        modifier = Modifier.testTag("nav_item_${item.name.lowercase()}"),
                        icon = iconVector,
                        iconTint = Color(0xFF007AFF),
                        showChevron = true,
                        showDivider = index < navItems.lastIndex,
                        onClick = { onSelect(item) }
                    )
                }
            }
        }

        // Spaces list (exact match to app_running.png second card "Ex1 Space")
        if (spaces.isNotEmpty()) {
            item {
                IosInsetGroupedCard {
                    spaces.forEachIndexed { index, spaceNode ->
                        val spaceObj = spaceNode.child("space")
                        val spaceName = spaceObj.text("name")
                        IosGroupedRow(
                            title = spaceName,
                            icon = Icons.Default.Business,
                            iconTint = Color(0xFF007AFF),
                            showChevron = true,
                            showDivider = index < spaces.lastIndex,
                            onClick = { onSelectSpace(spaceObj.id, spaceName) }
                        )
                    }
                }
            }
        }

        // Extra navigation sections (Messages, Meetings, Productivity, Team)
        item {
            IosSectionHeader("COLLABORATION")
            IosInsetGroupedCard {
                secondaryNavItems.forEachIndexed { index, item ->
                    val iconVector = when (item) {
                        Destination.Messages -> Icons.AutoMirrored.Filled.Chat
                        Destination.Meetings -> Icons.Default.Videocam
                        Destination.Calls -> Icons.Default.Call
                        Destination.Productivity -> Icons.Default.Bolt
                        Destination.Team -> Icons.Default.Groups
                        else -> item.icon
                    }
                    IosGroupedRow(
                        title = item.title,
                        modifier = Modifier.testTag("nav_item_${item.name.lowercase()}"),
                        icon = iconVector,
                        iconTint = Color(0xFF007AFF),
                        showChevron = true,
                        showDivider = index < secondaryNavItems.lastIndex,
                        onClick = { onSelect(item) }
                    )
                }
            }
        }
    }
}

// MARK: - Create Hierarchy Item Modal (matching CreateHierarchyItemSheet.swift)
@Composable
fun CreateHierarchyItemModal(
    hierarchy: RemoteState,
    api: ApiClient,
    vm: AppViewModel,
    onDismiss: () -> Unit
) {
    var mode by rememberSaveable { mutableStateOf("Team") } // "Team", "Project", "List"
    val spaces = hierarchy.data.obj().list("spaces")
    var selectedSpaceId by rememberSaveable { mutableStateOf(spaces.firstOrNull()?.child("space")?.id.orEmpty()) }

    val currentSpace = spaces.firstOrNull { it.child("space").id == selectedSpaceId }
    val projects = currentSpace?.list("projects").orEmpty().map { it.child("project") }
    var selectedProjectId by rememberSaveable(selectedSpaceId) { mutableStateOf(projects.firstOrNull()?.id.orEmpty()) }

    var name by rememberSaveable { mutableStateOf("") }
    var description by rememberSaveable { mutableStateOf("") }
    var color by rememberSaveable { mutableStateOf("#6E56CF") }
    var isSaving by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier.fillMaxWidth().padding(16.dp)
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Header
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Create",
                        style = AppTypography.title2,
                        color = AppColors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    IconButton(onClick = onDismiss, modifier = Modifier.size(28.dp)) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textTertiary)
                    }
                }

                // Mode segmented picker (Team, Project, List)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppRadius.medium))
                        .background(AppColors.surfaceElevated)
                        .padding(3.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    listOf("Team", "Project", "List").forEach { item ->
                        val isSelected = mode == item
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .clip(RoundedCornerShape(AppRadius.small))
                                .background(if (isSelected) AppColors.surfacePrimary else Color.Transparent)
                                .clickable { mode = item }
                                .padding(vertical = 8.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = item,
                                style = AppTypography.caption1.copy(fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal),
                                color = if (isSelected) AppColors.textPrimary else AppColors.textSecondary
                            )
                        }
                    }
                }

                // Team selector for Project and List
                if (mode != "Team") {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("Team", style = AppTypography.caption1, color = AppColors.textSecondary)
                        val spaceOptions = spaces.map { Choice(it.child("space").id, it.child("space").text("name")) }
                        IosDropdownSelector(
                            label = "Select Team",
                            value = selectedSpaceId,
                            options = spaceOptions,
                            onSelect = { selectedSpaceId = it }
                        )
                    }
                }

                // Cascading Project selector for List
                if (mode == "List") {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("Project", style = AppTypography.caption1, color = AppColors.textSecondary)
                        val projectOptions = projects.map { Choice(it.id, it.text("name")) }
                        if (projectOptions.isNotEmpty()) {
                            IosDropdownSelector(
                                label = "Select Project",
                                value = selectedProjectId,
                                options = projectOptions,
                                onSelect = { selectedProjectId = it }
                            )
                        } else {
                            Text(
                                "No projects in this team yet. Create a project first.",
                                style = AppTypography.caption1,
                                color = AppColors.textTertiary
                            )
                        }
                    }
                }

                // Name field
                IosTextField(
                    label = when (mode) {
                        "Team" -> "Team Name (Required)"
                        "Project" -> "Project Name (Required)"
                        else -> "List Name (Required)"
                    },
                    value = name,
                    onValueChange = { name = it },
                    singleLine = true
                )

                // Description field
                if (mode != "List") {
                    IosTextField(
                        label = "Description (Optional)",
                        value = description,
                        onValueChange = { description = it },
                        singleLine = false,
                        minLines = 2
                    )
                }

                // Color selection for List
                if (mode == "List") {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("Color", style = AppTypography.caption1, color = AppColors.textSecondary)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            listOf("#6E56CF", "#007AFF", "#34C759", "#FF9500", "#FF3B30").forEach { hex ->
                                val swatchColor = Color(android.graphics.Color.parseColor(hex))
                                val isSelected = color.equals(hex, ignoreCase = true)
                                Box(
                                    modifier = Modifier
                                        .size(32.dp)
                                        .clip(CircleShape)
                                        .background(swatchColor)
                                        .border(
                                            if (isSelected) BorderStroke(3.dp, AppColors.textPrimary) else BorderStroke(0.dp, Color.Transparent),
                                            CircleShape
                                        )
                                        .clickable { color = hex }
                                )
                            }
                        }
                    }
                }

                if (errorMessage != null) {
                    Text(errorMessage!!, style = AppTypography.caption1, color = AppColors.statusError)
                }

                // Actions
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    IosButton(
                        title = "Cancel",
                        onClick = onDismiss,
                        variant = IosButtonVariant.Secondary,
                        modifier = Modifier.weight(1f)
                    )
                    val canCreate = name.isNotBlank() && !isSaving && (mode == "Team" || selectedSpaceId.isNotBlank()) && (mode != "List" || selectedProjectId.isNotBlank())
                    IosButton(
                        title = if (isSaving) "Creating..." else "Create",
                        isEnabled = canCreate,
                        isLoading = isSaving,
                        onClick = {
                            scope.launch {
                                isSaving = true
                                errorMessage = null
                                val result = runCatching {
                                    val trimmedName = name.trim()
                                    val trimmedDesc = description.trim().ifEmpty { null }
                                    when (mode) {
                                        "Team" -> {
                                            api.request("/api/spaces", "POST", json("name" to trimmedName, "description" to trimmedDesc))
                                        }
                                        "Project" -> {
                                            api.request("/api/spaces/$selectedSpaceId/projects", "POST", json("name" to trimmedName, "description" to trimmedDesc))
                                        }
                                        "List" -> {
                                            api.request("/api/projects/$selectedProjectId/lists", "POST", json("name" to trimmedName, "color" to color))
                                        }
                                    }
                                }
                                isSaving = false
                                if (result.isSuccess) {
                                    vm.changed()
                                    onDismiss()
                                } else {
                                    errorMessage = result.exceptionOrNull()?.message ?: "Failed to create item."
                                }
                            }
                        },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

// MARK: - Workspace Switcher & Discovery Modals (Matching WorkspaceSwitcherView.swift & JoinWorkspaceView.swift)

@Composable
fun WorkspaceSwitcherModal(
    vm: AppViewModel,
    api: ApiClient,
    onDismiss: () -> Unit
) {
    val orgs = rememberRemote(api, "/api/organizations", vm.revision)
    var showJoinModal by remember { mutableStateOf(false) }
    var showCreateModal by remember { mutableStateOf(false) }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
                .testTag("workspace_switcher_modal"),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary)
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Workspaces",
                        style = AppTypography.title2,
                        color = AppColors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    IconButton(onClick = onDismiss, modifier = Modifier.testTag("btn_close_switcher")) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }

                RemoteStatus(orgs)

                LazyColumn(
                    modifier = Modifier.heightIn(max = 240.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(orgs.data.rows(), key = { it.id }) { org ->
                        val isSelected = org.id == vm.workspace?.id
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(AppRadius.medium))
                                .background(if (isSelected) AppColors.brandPrimary.copy(alpha = 0.10f) else AppColors.surfaceElevated)
                                .clickable {
                                    vm.selectWorkspace(org)
                                    onDismiss()
                                }
                                .padding(12.dp)
                                .testTag("org_item_${org.id}"),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(RoundedCornerShape(AppRadius.small))
                                    .background(AppColors.brandPrimary.copy(alpha = 0.15f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = org.text("name").take(1).uppercase(),
                                    style = AppTypography.headline,
                                    color = AppColors.brandPrimary
                                )
                            }
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text(
                                    text = org.text("name"),
                                    style = AppTypography.headline,
                                    color = AppColors.textPrimary
                                )
                                Text(
                                    text = org.text("slug"),
                                    style = AppTypography.caption1,
                                    color = AppColors.textSecondary
                                )
                            }
                            if (isSelected) {
                                Icon(Icons.Default.Check, "Selected", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                            }
                        }
                    }
                }

                HorizontalDivider(color = AppColors.borderSubtle, thickness = 0.5.dp)

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    OutlinedButton(
                        onClick = { showJoinModal = true },
                        modifier = Modifier.weight(1f).testTag("btn_join_workspace")
                    ) {
                        Icon(Icons.Default.PersonAdd, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Join", maxLines = 1)
                    }

                    Button(
                        onClick = { showCreateModal = true },
                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary),
                        modifier = Modifier.weight(1f).testTag("btn_create_workspace")
                    ) {
                        Icon(Icons.Default.Add, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("New", maxLines = 1)
                    }
                }
            }
        }
    }

    if (showJoinModal) {
        JoinWorkspaceModal(
            api = api,
            vm = vm,
            onDismiss = { showJoinModal = false },
            onJoined = {
                showJoinModal = false
                onDismiss()
            }
        )
    }

    if (showCreateModal) {
        CreateWorkspaceModal(
            api = api,
            vm = vm,
            onDismiss = { showCreateModal = false },
            onCreated = {
                showCreateModal = false
                onDismiss()
            }
        )
    }
}

@Composable
fun JoinWorkspaceModal(
    api: ApiClient,
    vm: AppViewModel,
    onDismiss: () -> Unit,
    onJoined: () -> Unit
) {
    var searchQuery by rememberSaveable { mutableStateOf("") }
    var inviteCode by rememberSaveable { mutableStateOf("") }
    var requestStatus by rememberSaveable { mutableStateOf<String?>(null) }
    val action = rememberAction()

    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier.fillMaxWidth().padding(16.dp).testTag("join_workspace_modal"),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary)
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Join Workspace", style = AppTypography.title2, modifier = Modifier.weight(1f))
                    IconButton(onClick = onDismiss, modifier = Modifier.testTag("btn_close_join")) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }

                ActionStatus(action)
                requestStatus?.let {
                    Text(it, color = AppColors.statusSuccess, style = AppTypography.caption1)
                }

                // Search section
                Text("Search Workspaces", style = AppTypography.headline)
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    placeholder = { Text("Search by name…") },
                    leadingIcon = { Icon(Icons.Default.Search, null, tint = AppColors.textTertiary) },
                    modifier = Modifier.fillMaxWidth().testTag("tf_search_workspace"),
                    singleLine = true
                )

                if (searchQuery.isNotBlank()) {
                    val searchResults = rememberRemote(api, "/api/organizations/search", query = mapOf("query" to searchQuery))
                    RemoteStatus(searchResults)
                    LazyColumn(
                        modifier = Modifier.heightIn(max = 140.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        items(searchResults.data.rows(), key = { it.id }) { org ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(AppRadius.small))
                                    .background(AppColors.surfaceElevated)
                                    .padding(10.dp)
                                    .testTag("search_org_item_${org.id}"),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(org.text("name"), style = AppTypography.subheadline, modifier = Modifier.weight(1f))
                                Button(
                                    onClick = {
                                        action.run {
                                            api.request("/api/organizations/${org.id}/join", "POST")
                                            requestStatus = "Join request sent!"
                                        }
                                    },
                                    modifier = Modifier.testTag("btn_request_join_${org.id}")
                                ) {
                                    Text("Request")
                                }
                            }
                        }
                    }
                }

                HorizontalDivider(color = AppColors.borderSubtle, thickness = 0.5.dp)

                // Invite code section
                Text("Have an Invite Code?", style = AppTypography.headline)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedTextField(
                        value = inviteCode,
                        onValueChange = { inviteCode = it },
                        placeholder = { Text("Enter invite ID") },
                        modifier = Modifier.weight(1f).testTag("tf_invite_code"),
                        singleLine = true
                    )
                    Button(
                        onClick = {
                            action.run {
                                api.request("/api/organizations/invites/${inviteCode.trim()}/accept", "POST")
                                vm.changed()
                                onJoined()
                            }
                        },
                        enabled = inviteCode.isNotBlank() && !action.busy,
                        modifier = Modifier.testTag("btn_accept_invite_code")
                    ) {
                        Text("Accept")
                    }
                }
            }
        }
    }
}

@Composable
fun CreateWorkspaceModal(
    api: ApiClient,
    vm: AppViewModel,
    onDismiss: () -> Unit,
    onCreated: () -> Unit
) {
    var name by rememberSaveable { mutableStateOf("") }
    var description by rememberSaveable { mutableStateOf("") }
    val action = rememberAction()

    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier.fillMaxWidth().padding(16.dp).testTag("create_workspace_modal"),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary)
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("New Workspace", style = AppTypography.title2, modifier = Modifier.weight(1f))
                    IconButton(onClick = onDismiss, modifier = Modifier.testTag("btn_close_create_workspace")) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }

                ActionStatus(action)

                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Workspace Name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("tf_new_workspace_name")
                )

                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text("Description (optional)") },
                    minLines = 2,
                    maxLines = 4,
                    modifier = Modifier.fillMaxWidth().testTag("tf_new_workspace_desc")
                )

                Button(
                    onClick = {
                        action.run {
                            val org = api.request("/api/organizations", "POST", json("name" to name.trim(), "description" to description.trim())).data.obj()
                            vm.changed()
                            vm.selectWorkspace(org)
                            onCreated()
                        }
                    },
                    enabled = name.isNotBlank() && !action.busy,
                    modifier = Modifier.fillMaxWidth().testTag("btn_submit_create_workspace"),
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary)
                ) {
                    Text("Create Workspace")
                }
            }
        }
    }
}
