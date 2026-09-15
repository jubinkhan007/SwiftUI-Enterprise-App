package com.acme.taskflow.ui

import androidx.compose.foundation.background
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
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
    var showUserMenu by remember { mutableStateOf(false) }

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
                    .clickable { vm.selectWorkspace(null) }
                    .padding(12.dp),
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
                            Destination.Messages, Destination.Meetings, Destination.Productivity
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
                        if (!live) {
                            Text(
                                text = "Offline",
                                style = AppTypography.caption2,
                                color = AppColors.statusWarning,
                                modifier = Modifier.padding(end = 8.dp)
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
            onCreate = { hierarchyEditor = "Create space" to "/api/spaces" }
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

    if (showUserMenu) {
        ProfileDialog(vm = vm, onDismiss = { showUserMenu = false })
    }
}

@Composable
private fun ProfileDialog(vm: AppViewModel, onDismiss: () -> Unit) {
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
    onCreate: () -> Unit
) {
    val navItems = listOf(
        Destination.AllTasks,
        Destination.MyTasks,
        Destination.Inbox
    )
    val secondaryNavItems = listOf(
        Destination.Messages,
        Destination.Meetings,
        Destination.Productivity
    )
    val spaces = hierarchy.data.obj().list("spaces")

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.backgroundSecondary)
            .safeDrawingPadding(),
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

        // Extra navigation sections (Messages, Meetings, Productivity)
        item {
            IosSectionHeader("COLLABORATION")
            IosInsetGroupedCard {
                secondaryNavItems.forEachIndexed { index, item ->
                    val iconVector = when (item) {
                        Destination.Messages -> Icons.AutoMirrored.Filled.Chat
                        Destination.Meetings -> Icons.Default.Videocam
                        Destination.Productivity -> Icons.Default.Bolt
                        else -> item.icon
                    }
                    IosGroupedRow(
                        title = item.title,
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
