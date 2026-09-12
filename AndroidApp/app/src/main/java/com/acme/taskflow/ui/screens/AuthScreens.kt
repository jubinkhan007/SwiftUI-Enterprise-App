package com.acme.taskflow.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*

import androidx.compose.foundation.Canvas
import androidx.compose.ui.geometry.Offset

// MARK: - Atmospheric Aurora Background (matching AuthBackground.swift)
@Composable
fun AuthBackground(modifier: Modifier = Modifier) {
    val bg = AppColors.backgroundPrimary
    val brand = AppColors.brandPrimary
    val secondary = AppColors.brandSecondary
    val accent = AppColors.accent

    Canvas(modifier = modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height
        val centerX = w / 2f
        val centerY = h / 2f

        // Base background primary (clean white in light mode)
        drawRect(color = bg)

        // Soft linear brand glow gradient across canvas
        drawRect(
            brush = Brush.linearGradient(
                colors = listOf(
                    brand.copy(alpha = 0.12f),
                    secondary.copy(alpha = 0.08f),
                    accent.copy(alpha = 0.12f)
                ),
                start = Offset.Zero,
                end = Offset(w, h)
            )
        )

        // Top-left aurora cloud (mint / cyan accent glow)
        // Matching SwiftUI: offset(x: -130, y: -240), frame(180, 180) -> radius ~160dp
        val tlX = centerX - 120.dp.toPx()
        val tlY = centerY - 230.dp.toPx()
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    accent.copy(alpha = 0.38f),
                    accent.copy(alpha = 0.16f),
                    Color.Transparent
                ),
                center = Offset(tlX, tlY),
                radius = 160.dp.toPx()
            ),
            center = Offset(tlX, tlY),
            radius = 160.dp.toPx()
        )

        // Brand glow behind lightning badge (center top)
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    brand.copy(alpha = 0.22f),
                    secondary.copy(alpha = 0.10f),
                    Color.Transparent
                ),
                center = Offset(centerX, centerY - 210.dp.toPx()),
                radius = 120.dp.toPx()
            ),
            center = Offset(centerX, centerY - 210.dp.toPx()),
            radius = 120.dp.toPx()
        )

        // Bottom-right aurora cloud (mint / cyan accent glow)
        // Matching SwiftUI: offset(x: 140, y: 120), frame(220, 220) -> radius ~180dp
        val brX = centerX + 130.dp.toPx()
        val brY = centerY + 130.dp.toPx()
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    accent.copy(alpha = 0.32f),
                    accent.copy(alpha = 0.12f),
                    Color.Transparent
                ),
                center = Offset(brX, brY),
                radius = 180.dp.toPx()
            ),
            center = Offset(brX, brY),
            radius = 180.dp.toPx()
        )
    }
}

@Composable
fun AuthScreen(
    vm: AppViewModel,
    initialEmail: String = "alice@acme.com",
    initialPassword: String = "Password123!"
) {
    var register by rememberSaveable { mutableStateOf(false) }
    var email by rememberSaveable { mutableStateOf(initialEmail) }
    var name by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf(initialPassword) }
    var server by rememberSaveable { mutableStateOf(vm.server) }
    var settings by rememberSaveable { mutableStateOf(false) }

    val emailValidation = remember(email) {
        val trimmed = email.trim()
        when {
            trimmed.isEmpty() -> ValidationState.Normal
            android.util.Patterns.EMAIL_ADDRESS.matcher(trimmed).matches() -> ValidationState.Success
            else -> ValidationState.Error("Enter a valid email.")
        }
    }

    val passwordValidation = remember(password) {
        when {
            password.isEmpty() -> ValidationState.Normal
            password.length >= 8 -> ValidationState.Success
            else -> ValidationState.Error("Must be 8+ characters.")
        }
    }

    val displayNameValidation = remember(name) {
        val trimmed = name.trim()
        when {
            trimmed.isEmpty() -> ValidationState.Normal
            trimmed.length >= 2 -> ValidationState.Success
            else -> ValidationState.Error("Display name is required.")
        }
    }

    val canSubmit = !vm.busy &&
            emailValidation is ValidationState.Success &&
            passwordValidation is ValidationState.Success &&
            (!register || displayNameValidation is ValidationState.Success)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .safeDrawingPadding()
            .imePadding(),
        contentAlignment = Alignment.Center
    ) {
        AuthBackground()

        Column(
            modifier = Modifier
                .widthIn(max = 440.dp)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Header (exact match to AuthFlowView.swift header)
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(54.dp)
                        .shadow(
                            elevation = 16.dp,
                            shape = CircleShape,
                            ambientColor = AppColors.brandPrimary.copy(alpha = 0.35f),
                            spotColor = AppColors.brandPrimary.copy(alpha = 0.35f)
                        )
                        .clip(CircleShape)
                        .background(AppColors.brandGlowGradient),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Bolt,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(24.dp)
                    )
                }

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    Text(
                        text = "Enterprise App",
                        style = AppTypography.title2,
                        color = AppColors.textPrimary
                    )
                    Text(
                        text = "Secure access for modern teams.",
                        style = AppTypography.subheadline,
                        color = AppColors.textSecondary
                    )
                }
            }

            // Mode Picker (exact match to modePicker in AuthFlowView.swift)
            IosSegmentedPicker(
                options = listOf("Sign in", "Create account"),
                selectedIndex = if (register) 1 else 0,
                onSelect = {
                    register = it == 1
                    password = ""
                },
                modifier = Modifier.fillMaxWidth()
            )

            // Form Card (matches AppCard(elevation: .high, hasBorderGlow: true) in AuthFlowView.swift)
            IosCard(
                modifier = Modifier.fillMaxWidth(),
                hasBorderGlow = true,
                elevation = 16.dp,
                contentPadding = 16.dp
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = if (register) "Create your account" else "Welcome back",
                        style = AppTypography.headline,
                        color = AppColors.textPrimary
                    )

                    if (register) {
                        IosTextField(
                            label = "Display name",
                            value = name,
                            onValueChange = { name = it },
                            placeholder = "Jane Doe",
                            validationState = displayNameValidation,
                            singleLine = true
                        )
                    }

                    IosTextField(
                        label = "Email",
                        value = email,
                        onValueChange = { email = it },
                        placeholder = "name@company.com",
                        validationState = emailValidation,
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email)
                    )

                    IosTextField(
                        label = "Password",
                        value = password,
                        onValueChange = { password = it },
                        placeholder = "••••••••",
                        validationState = passwordValidation,
                        isSecure = true,
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password)
                    )

                    vm.error?.let {
                        Text(
                            text = it,
                            style = AppTypography.caption1,
                            color = AppColors.statusError
                        )
                    }

                    IosButton(
                        title = if (register) "Create account" else "Sign in",
                        leadingIconComposable = if (!register) { { PersonCheckmarkIcon(tint = Color.White) } } else null,
                        leadingIcon = if (register) Icons.Default.PersonAdd else null,
                        isEnabled = canSubmit,
                        isLoading = vm.busy,
                        onClick = { vm.authenticate(email, password, if (register) name.trim() else null, server) }
                    )

                    if (!register) {
                        Text(
                            text = "Forgot password?",
                            style = AppTypography.caption1,
                            color = AppColors.brandPrimary,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { }
                                .padding(vertical = 4.dp)
                        )
                    }
                }
            }

            // Footer (exact match to AuthFlowView.swift footer)
            Text(
                text = "By continuing, you agree to your organization’s security policies.",
                style = AppTypography.caption1,
                color = AppColors.textTertiary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 12.dp)
            )

            if (settings) {
                IosTextField(
                    label = "Server address",
                    value = server,
                    onValueChange = { server = it },
                    singleLine = true
                )
            }
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

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(AppColors.backgroundSecondary)
            .safeDrawingPadding(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Workspaces",
                    style = AppTypography.largeTitle,
                    color = AppColors.textPrimary,
                    modifier = Modifier.weight(1f)
                )
                IconButton(onClick = { create = true }) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "Create workspace",
                        tint = AppColors.brandPrimary,
                        modifier = Modifier.size(28.dp)
                    )
                }
            }
        }

        item {
            Text(
                text = "Select a Workspace",
                style = AppTypography.title3,
                color = AppColors.textPrimary
            )
        }

        item {
            RemoteStatus(orgs)
            ActionStatus(action)
        }

        items(orgs.data.rows(), key = { it.id }) { org ->
            IosCard(
                modifier = Modifier.fillMaxWidth(),
                onClick = { vm.selectWorkspace(org) }
            ) {
                Row(verticalAlignment = Alignment.Top) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(RoundedCornerShape(AppRadius.medium))
                            .background(AppColors.brandPrimary.copy(alpha = 0.10f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Business,
                            contentDescription = null,
                            tint = AppColors.brandPrimary,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                    Spacer(Modifier.width(14.dp))
                    Column(Modifier.weight(1f)) {
                        Text(
                            text = org.text("name"),
                            style = AppTypography.headline,
                            color = AppColors.textPrimary
                        )
                        if (org.text("description").isNotBlank()) {
                            Text(
                                text = org.text("description"),
                                style = AppTypography.caption1,
                                color = AppColors.textTertiary,
                                modifier = Modifier.padding(top = 2.dp)
                            )
                        }
                        Spacer(Modifier.height(8.dp))
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            IosPill(label(org.text("subscription_tier", "free")))
                            if (org.has("member_count")) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.Group,
                                        contentDescription = null,
                                        tint = AppColors.textTertiary,
                                        modifier = Modifier.size(14.dp)
                                    )
                                    Text(
                                        text = "${org.number("member_count")} members",
                                        style = AppTypography.caption2,
                                        color = AppColors.textTertiary
                                    )
                                }
                            }
                        }
                    }
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = Color(0xFFC7C7CC),
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }

        if (!orgs.loading && orgs.error == null && orgs.data.rows().isEmpty()) {
            item {
                Text(
                    text = "No workspaces yet.",
                    style = AppTypography.body,
                    color = AppColors.textSecondary,
                    modifier = Modifier.padding(16.dp)
                )
            }
        }

        if (invites.data.rows().isNotEmpty()) {
            item {
                IosSectionHeader("Invitations")
            }
            items(invites.data.rows(), key = { "invite-${it.id}" }) { invite ->
                IosCard(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                text = invite.text("org_name"),
                                style = AppTypography.headline,
                                color = AppColors.textPrimary
                            )
                            Text(
                                text = "Role: ${label(invite.text("role"))}",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                        }
                        IosButton(
                            title = "Accept",
                            onClick = {
                                action.run {
                                    api.request("/api/organizations/invites/${invite.id}/accept", "POST")
                                    vm.changed()
                                }
                            },
                            modifier = Modifier.width(100.dp).height(38.dp)
                        )
                    }
                }
            }
        }

        item {
            IosTextField(
                label = "Find a workspace",
                value = search,
                onValueChange = { search = it },
                trailingIcon = {
                    IconButton(onClick = { searchQuery = search.trim() }) {
                        Icon(Icons.Default.Search, "Search", tint = AppColors.brandPrimary)
                    }
                }
            )
        }

        if (searchQuery.isNotEmpty()) {
            item {
                val results = rememberRemote(api, "/api/organizations/search", query = mapOf("query" to searchQuery))
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    RemoteStatus(results)
                    results.data.rows().forEach { org ->
                        IosCard(modifier = Modifier.fillMaxWidth()) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(org.text("name"), style = AppTypography.headline, modifier = Modifier.weight(1f))
                                IosButton(
                                    title = "Request",
                                    onClick = {
                                        action.run {
                                            api.request("/api/organizations/${org.id}/join", "POST")
                                            searchQuery = ""
                                        }
                                    },
                                    modifier = Modifier.width(100.dp).height(36.dp)
                                )
                            }
                        }
                    }
                }
            }
        }

        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = vm::signOut)
                    .padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Logout,
                    contentDescription = null,
                    tint = AppColors.statusError,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = "Sign out",
                    style = AppTypography.body,
                    color = AppColors.statusError
                )
            }
        }
    }

    if (create) {
        EditorDialog(
            title = "Create workspace",
            fields = listOf(
                FormField("name", "Workspace Name", required = true),
                FormField("description", "Description", multiline = true)
            ),
            onDismiss = { create = false }
        ) {
            val org = api.request("/api/organizations", "POST", it).data.obj()
            vm.changed()
            vm.selectWorkspace(org)
        }
    }
}
