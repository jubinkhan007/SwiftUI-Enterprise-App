package com.acme.taskflow.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.BrandGradient

@Composable
fun AuthScreen(vm: AppViewModel) {
    var register by rememberSaveable { mutableStateOf(false) }
    var email by rememberSaveable { mutableStateOf("") }
    var name by rememberSaveable { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var visible by remember { mutableStateOf(false) }
    var server by rememberSaveable { mutableStateOf(vm.server) }
    var settings by rememberSaveable { mutableStateOf(false) }
    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background).safeDrawingPadding().imePadding(), contentAlignment = Alignment.Center) {
        Column(Modifier.widthIn(max = 480.dp).fillMaxWidth().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Box(Modifier.size(64.dp).clip(CircleShape).background(BrandGradient), contentAlignment = Alignment.Center) {
                Icon(Icons.Default.Bolt, null, tint = androidx.compose.ui.graphics.Color.White, modifier = Modifier.size(32.dp))
            }
            Text("Enterprise App", style = MaterialTheme.typography.headlineSmall)
            Text("Secure access for modern teams.", color = MaterialTheme.colorScheme.onSurfaceVariant)
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                listOf("Sign in", "Create account").forEachIndexed { index, text ->
                    SegmentedButton(selected = register == (index == 1), onClick = { register = index == 1; password = "" },
                        shape = SegmentedButtonDefaults.itemShape(index, 2)) { Text(text) }
                }
            }
            Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text(if (register) "Create your account" else "Welcome back", style = MaterialTheme.typography.titleLarge)
                if (register) OutlinedTextField(name, { name = it }, label = { Text("Display name") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(email, { email = it }, label = { Text("Email") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email), singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(password, { password = it }, label = { Text("Password") }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    visualTransformation = if (visible) VisualTransformation.None else PasswordVisualTransformation(),
                    trailingIcon = { ToolButton(if (visible) Icons.Default.VisibilityOff else Icons.Default.Visibility, "Show password") { visible = !visible } },
                    modifier = Modifier.fillMaxWidth())
                vm.error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                Button(enabled = !vm.busy && android.util.Patterns.EMAIL_ADDRESS.matcher(email.trim()).matches() && password.length >= 8 && (!register || name.trim().length >= 2),
                    onClick = { vm.authenticate(email, password, if (register) name.trim() else null, server) }, modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp)) {
                    if (vm.busy) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                    else { Icon(Icons.Default.Login, null); Spacer(Modifier.width(8.dp)); Text(if (register) "Create account" else "Sign in") }
                }
            }
            Text("By continuing, you agree to your organization's security policies.", style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = { settings = !settings }) { Icon(Icons.Default.Settings, null); Text("Server", Modifier.padding(start = 8.dp)) }
            if (settings) OutlinedTextField(server, { server = it }, label = { Text("Server address") }, singleLine = true, modifier = Modifier.fillMaxWidth())
        }
    }
}

@Composable
fun WorkspaceScreen(vm: AppViewModel, api: ApiClient) {
    val orgs = rememberRemote(api, "/api/organizations", vm.revision)
    val invites = rememberRemote(api, "/api/invites", vm.revision)
    var create by remember { mutableStateOf(false) }
    var search by rememberSaveable { mutableStateOf("") }
    var searchQuery by remember { mutableStateOf("") }
    val action = rememberAction()
    LazyColumn(Modifier.fillMaxSize().safeDrawingPadding(), contentPadding = PaddingValues(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { SectionHeader("Choose Workspace", vm.user?.text("display_name")) { ToolButton(Icons.Default.Add, "Create workspace") { create = true } } }
        item { RemoteStatus(orgs); ActionStatus(action) }
        items(orgs.data.rows(), key = { it.id }) { org ->
            ListItem(headlineContent = { Text(org.text("name")) }, supportingContent = { Text(label(org.text("subscription_tier", "free"))) },
                leadingContent = { AppAvatar(org.text("name")) }, trailingContent = { Icon(Icons.Default.ChevronRight, null) },
                modifier = Modifier.clickable { vm.selectWorkspace(org) })
        }
        if (!orgs.loading && orgs.error == null && orgs.data.rows().isEmpty()) item { Text("No workspaces yet.") }
        item { RemoteStatus(invites) }
        items(invites.data.rows(), key = { "invite-${it.id}" }) { invite ->
            ListItem(headlineContent = { Text(invite.text("org_name")) }, supportingContent = { Text("Invitation: ${label(invite.text("role"))}") },
                trailingContent = { TextButton(enabled = !action.busy, onClick = { action.run {
                    api.request("/api/organizations/invites/${invite.id}/accept", "POST"); vm.changed()
                } }) { Text("Accept") } })
        }
        item {
            OutlinedTextField(search, { search = it }, label = { Text("Find a workspace") }, modifier = Modifier.fillMaxWidth(), singleLine = true,
                trailingIcon = { ToolButton(Icons.Default.Search, "Search workspaces") { searchQuery = search.trim() } })
        }
        if (searchQuery.isNotEmpty()) item {
            val results = rememberRemote(api, "/api/organizations/search", query = mapOf("query" to searchQuery))
            Column {
                RemoteStatus(results)
                results.data.rows().forEach { org ->
                    ListItem(headlineContent = { Text(org.text("name")) }, trailingContent = {
                        TextButton(enabled = !action.busy, onClick = { action.run { api.request("/api/organizations/${org.id}/join", "POST"); searchQuery = "" } }) { Text("Request to join") }
                    })
                }
            }
        }
        item { TextButton(onClick = vm::signOut) { Text("Sign out") } }
    }
    if (create) EditorDialog("Create workspace", listOf(FormField("name", "Name", required = true), FormField("description", "Description", multiline = true)), { create = false }) {
        val org = api.request("/api/organizations", "POST", it).data.obj(); vm.changed(); vm.selectWorkspace(org)
    }
}
