package com.acme.taskflow.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.acme.taskflow.data.*
import com.acme.taskflow.model.Destination
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.screens.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.retryWhen
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle

@Composable
fun TaskFlowApp(vm: AppViewModel = viewModel()) {
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
    val drawer = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    val wide = LocalConfiguration.current.screenWidthDp >= 840
    val hierarchy = rememberRemote(api, "/api/hierarchy", vm.revision)
    val me = rememberRemote(api, "/api/me")
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
        Column(Modifier.width(290.dp).fillMaxHeight().background(MaterialTheme.colorScheme.surface).padding(12.dp)) {
            TextButton(onClick = { vm.selectWorkspace(null) }) {
                Icon(Icons.Default.Business, null)
                Text(vm.workspace?.text("name").orEmpty(), Modifier.weight(1f).padding(8.dp), maxLines = 2, overflow = TextOverflow.Ellipsis)
                Icon(Icons.Default.UnfoldMore, "Switch workspace")
            }
            HorizontalDivider()
            LazyColumn(Modifier.weight(1f)) {
                items(Destination.entries.size) { index ->
                    val item = Destination.entries[index]
                    NavigationDrawerItem(label = { Text(item.title) }, icon = { Icon(item.icon, null) },
                        selected = destination == item && listId.isBlank(), onClick = {
                            destination = item; listId = ""; listName = ""; scope.launch { drawer.close() }
                        })
                }
                item { Text("SPACES", style = MaterialTheme.typography.labelSmall, modifier = Modifier.padding(16.dp)); RemoteStatus(hierarchy) }
                hierarchy.data.obj().list("spaces").forEach { space ->
                    item { Text(space.child("space").text("name"), style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(12.dp)) }
                    space.list("projects").forEach { project ->
                        item { Text(project.child("project").text("name"), modifier = Modifier.padding(start = 24.dp, top = 8.dp)) }
                        project.list("lists").forEach { list ->
                            item {
                                NavigationDrawerItem(label = { Text(list.text("name")) }, selected = listId == list.id,
                                    modifier = Modifier.padding(start = 24.dp), icon = { Icon(Icons.Default.List, null) }, onClick = {
                                        listId = list.id; listName = list.text("name"); destination = Destination.AllTasks; scope.launch { drawer.close() }
                                    })
                            }
                        }
                    }
                }
            }
            HorizontalDivider()
            Text(vm.user?.text("display_name").orEmpty(), style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(12.dp))
            TextButton(onClick = vm::signOut) { Icon(Icons.Default.Logout, null); Text("Sign out", Modifier.padding(start = 8.dp)) }
        }
    }
    val content: @Composable () -> Unit = {
        Scaffold(topBar = {
            TopAppBar(title = { Text(listName.ifBlank { destination.title }, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = { if (!wide) ToolButton(Icons.Default.Menu, "Open navigation") { scope.launch { drawer.open() } } },
                actions = { ToolButton(Icons.Default.Refresh, "Refresh") { vm.changed() } })
        }) { padding ->
            Column(Modifier.padding(padding).fillMaxSize()) {
                if (!live) Text("Live updates reconnecting", style = MaterialTheme.typography.labelSmall, modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp))
                if (me.error != null) {
                    Text(me.error.orEmpty(), color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(12.dp))
                    TextButton(onClick = vm::expired) { Text("Sign in again") }
                }
                val lists = hierarchy.data.obj().list("spaces").flatMap { it.list("projects") }.flatMap { node ->
                    node.list("lists").map { Choice(it.id, "${node.child("project").text("name")} / ${it.text("name")}") }
                }
                when (destination) {
                    Destination.AllTasks, Destination.MyTasks -> TasksScreen(vm, api, lists, listId, destination == Destination.MyTasks)
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
    if (wide) Row(Modifier.fillMaxSize()) { sidebar(); Box(Modifier.weight(1f)) { content() } }
    else ModalNavigationDrawer(drawerState = drawer, drawerContent = { ModalDrawerSheet { sidebar() } }, content = content)
}
