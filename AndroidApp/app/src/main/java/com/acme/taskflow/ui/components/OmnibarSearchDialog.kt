package com.acme.taskflow.ui.components

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.acme.taskflow.data.ApiClient
import com.acme.taskflow.data.double
import com.acme.taskflow.data.json
import com.acme.taskflow.data.list
import com.acme.taskflow.data.text
import com.acme.taskflow.ui.theme.AppColors
import com.acme.taskflow.ui.theme.AppRadius
import com.acme.taskflow.ui.theme.AppSpacing
import com.acme.taskflow.ui.theme.AppTypography
import com.google.gson.JsonObject
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

data class OmnibarSearchResult(
    val id: String,
    val entityType: String,
    val title: String,
    val subtitle: String,
    val deepLink: String,
    val badge: String? = null,
    val similarityScore: Double? = null,
    val matchType: String? = null,
    val highlightSnippet: String? = null
)

data class OmnibarSuggestedTask(
    val title: String,
    val description: String? = null,
    val priority: String = "medium",
    val estimateHours: Double = 2.0
)

data class OmnibarRAGCitation(
    val id: String,
    val entityType: String,
    val title: String,
    val snippet: String,
    val deepLink: String,
    val similarityScore: Double? = null,
    val citationNumber: Int = 1
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OmnibarSearchDialog(
    api: ApiClient,
    onDismiss: () -> Unit,
    onNavigateDeeplink: (String) -> Unit,
    onTaskCreated: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()

    var activeTab by remember { mutableStateOf("all") } // "all", "task", "message", "meeting", "member", "copilot"
    var searchMode by remember { mutableStateOf("hybrid") } // "hybrid", "semantic", "keyword"
    var searchQuery by remember { mutableStateOf("") }
    var isSearching by remember { mutableStateOf(false) }
    var searchResults by remember { mutableStateOf<List<OmnibarSearchResult>>(emptyList()) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    // Copilot State
    var copilotMode by remember { mutableStateOf("rag") } // "rag", "breakdown", or "standup"
    var copilotPrompt by remember { mutableStateOf("") }
    var isCopilotLoading by remember { mutableStateOf(false) }
    var copilotSummary by remember { mutableStateOf<String?>(null) }
    var copilotTasks by remember { mutableStateOf<List<OmnibarSuggestedTask>>(emptyList()) }
    var copilotCitations by remember { mutableStateOf<List<OmnibarRAGCitation>>(emptyList()) }
    var copilotFollowUps by remember { mutableStateOf<List<String>>(emptyList()) }
    var isAddingTasks by remember { mutableStateOf(false) }
    var tasksAddedSuccess by remember { mutableStateOf(false) }

    var isStreaming by remember { mutableStateOf(false) }
    var streamingJob by remember { mutableStateOf<Job?>(null) }
    var cursorVisible by remember { mutableStateOf(true) }

    LaunchedEffect(isStreaming) {
        if (isStreaming) {
            while (true) {
                delay(500)
                cursorVisible = !cursorVisible
            }
        } else {
            cursorVisible = false
        }
    }

    fun startStreamingAsk(query: String) {
        if (query.isBlank()) return
        streamingJob?.cancel()
        isStreaming = true
        isCopilotLoading = true
        errorMessage = null
        copilotSummary = ""
        copilotCitations = emptyList()
        copilotFollowUps = emptyList()

        streamingJob = coroutineScope.launch {
            try {
                api.streamAskKnowledgeBase(query.trim()).collect { event ->
                    when (event.event) {
                        "start" -> {
                            isCopilotLoading = false
                        }
                        "citations" -> {
                            val items = event.citations ?: emptyList()
                            copilotCitations = items.map { item ->
                                OmnibarRAGCitation(
                                    id = item.text("id"),
                                    entityType = item.text("entity_type").ifBlank { item.text("entityType") }.ifBlank { "task" },
                                    title = item.text("title").ifBlank { "Source Item" },
                                    snippet = item.text("snippet"),
                                    deepLink = item.text("deep_link").ifBlank { item.text("deepLink") },
                                    similarityScore = if (item.has("similarity_score")) item.get("similarity_score").asDouble else null,
                                    citationNumber = if (item.has("citation_number")) item.get("citation_number").asInt else 1
                                )
                            }
                        }
                        "token" -> {
                            isCopilotLoading = false
                            val tok = event.token ?: ""
                            copilotSummary = (copilotSummary ?: "") + tok
                        }
                        "follow_ups" -> {
                            val fu = event.suggestedFollowUps ?: emptyList()
                            copilotFollowUps = fu
                        }
                        "done" -> {
                            val resp = event.response
                            if (resp != null) {
                                if (copilotSummary.isNullOrBlank() && resp.has("summary")) {
                                    copilotSummary = resp.text("summary")
                                }
                            }
                            isStreaming = false
                            isCopilotLoading = false
                        }
                        "error" -> {
                            errorMessage = event.error ?: "Streaming error occurred"
                            isStreaming = false
                            isCopilotLoading = false
                        }
                    }
                }
            } catch (e: Exception) {
                if (e !is kotlinx.coroutines.CancellationException) {
                    errorMessage = e.message ?: "Failed to stream knowledge response"
                }
            } finally {
                isStreaming = false
                isCopilotLoading = false
            }
        }
    }

    fun startStreamingBreakdown(query: String) {
        if (query.isBlank()) return
        streamingJob?.cancel()
        isStreaming = true
        isCopilotLoading = true
        errorMessage = null
        copilotSummary = ""
        copilotTasks = emptyList()

        streamingJob = coroutineScope.launch {
            try {
                api.streamBreakdownTask(query.trim()).collect { event ->
                    when (event.event) {
                        "start" -> {
                            isCopilotLoading = false
                        }
                        "token" -> {
                            isCopilotLoading = false
                            val tok = event.token ?: ""
                            copilotSummary = (copilotSummary ?: "") + tok
                        }
                        "done" -> {
                            val resp = event.response
                            if (resp != null) {
                                val rawTasks = resp.list("suggestedTasks").ifEmpty { resp.list("suggested_tasks") }
                                copilotTasks = rawTasks.map { item ->
                                    OmnibarSuggestedTask(
                                        title = item.text("title").ifBlank { "Subtask" },
                                        description = item.text("description").takeIf { it.isNotBlank() },
                                        priority = item.text("priority").ifBlank { "medium" },
                                        estimateHours = item.double("estimateHours", item.double("estimate_hours", 2.0))
                                    )
                                }
                            }
                            isStreaming = false
                            isCopilotLoading = false
                        }
                        "error" -> {
                            errorMessage = event.error ?: "Failed to breakdown task"
                            isStreaming = false
                            isCopilotLoading = false
                        }
                    }
                }
            } catch (e: Exception) {
                if (e !is kotlinx.coroutines.CancellationException) {
                    errorMessage = e.message ?: "Failed to decompose task."
                }
            } finally {
                isStreaming = false
                isCopilotLoading = false
            }
        }
    }

    fun startStreamingStandup() {
        streamingJob?.cancel()
        isStreaming = true
        isCopilotLoading = true
        errorMessage = null
        copilotSummary = ""

        streamingJob = coroutineScope.launch {
            try {
                api.streamGenerateStandupSummary().collect { event ->
                    when (event.event) {
                        "start" -> {
                            isCopilotLoading = false
                        }
                        "token" -> {
                            isCopilotLoading = false
                            val tok = event.token ?: ""
                            copilotSummary = (copilotSummary ?: "") + tok
                        }
                        "done" -> {
                            isStreaming = false
                            isCopilotLoading = false
                        }
                        "error" -> {
                            errorMessage = event.error ?: "Failed to generate standup report"
                            isStreaming = false
                            isCopilotLoading = false
                        }
                    }
                }
            } catch (e: Exception) {
                if (e !is kotlinx.coroutines.CancellationException) {
                    errorMessage = e.message ?: "Failed to generate standup report."
                }
            } finally {
                isStreaming = false
                isCopilotLoading = false
            }
        }
    }

    // Search query debounced runner
    LaunchedEffect(searchQuery, activeTab, searchMode) {
        if (activeTab == "copilot") return@LaunchedEffect
        delay(200) // debounce
        isSearching = true
        errorMessage = null
        try {
            val types = if (activeTab == "all") emptyList() else listOf(activeTab)
            val response = api.search(searchQuery.trim(), types = types, limit = 25, mode = searchMode)
            val rawResults = response.list("results")
            searchResults = rawResults.map { obj ->
                val score = when {
                    obj.has("similarity_score") && !obj.get("similarity_score").isJsonNull -> obj.get("similarity_score").asDouble
                    obj.has("similarityScore") && !obj.get("similarityScore").isJsonNull -> obj.get("similarityScore").asDouble
                    else -> null
                }
                val matchType = obj.text("match_type").ifBlank { obj.text("matchType") }.takeIf { it.isNotBlank() }
                val snippet = obj.text("highlight_snippet").ifBlank { obj.text("highlightSnippet") }.takeIf { it.isNotBlank() }

                OmnibarSearchResult(
                    id = obj.text("id"),
                    entityType = obj.text("entityType").ifBlank { obj.text("entity_type") }.ifBlank { "task" },
                    title = obj.text("title").ifBlank { "Untitled" },
                    subtitle = obj.text("subtitle"),
                    deepLink = obj.text("deepLink").ifBlank { obj.text("deep_link") },
                    badge = obj.text("badge").takeIf { it.isNotBlank() },
                    similarityScore = score,
                    matchType = matchType,
                    highlightSnippet = snippet
                )
            }
        } catch (e: Exception) {
            errorMessage = e.message ?: "Failed to perform search"
        } finally {
            isSearching = false
        }
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.65f))
                .clickable { onDismiss() }
                .padding(horizontal = 16.dp, vertical = 32.dp),
            contentAlignment = Alignment.TopCenter
        ) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .widthIn(max = 680.dp)
                    .clip(RoundedCornerShape(AppRadius.large))
                    .clickable(enabled = false) {}
                    .testTag("omnibar_modal"),
                colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
                elevation = CardDefaults.cardElevation(defaultElevation = 12.dp)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(AppSpacing.md)
                ) {
                    // Header row: Search Field / Title + Close
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        OutlinedTextField(
                            value = searchQuery,
                            onValueChange = { searchQuery = it },
                            modifier = Modifier
                                .weight(1f)
                                .testTag("omnibar_search_input"),
                            placeholder = {
                                Text(
                                    if (activeTab == "copilot") "Search or prompt AI Copilot..." else "Search tasks, messages, meetings, team...",
                                    style = AppTypography.callout,
                                    color = AppColors.textTertiary
                                )
                            },
                            leadingIcon = {
                                Icon(
                                    imageVector = if (activeTab == "copilot") Icons.Default.AutoAwesome else Icons.Default.Search,
                                    contentDescription = null,
                                    tint = if (activeTab == "copilot") Color(0xFF6366F1) else AppColors.brandPrimary,
                                    modifier = Modifier.size(20.dp)
                                )
                            },
                            trailingIcon = {
                                if (searchQuery.isNotEmpty()) {
                                    IconButton(onClick = { searchQuery = "" }) {
                                        Icon(Icons.Default.Clear, contentDescription = "Clear", modifier = Modifier.size(18.dp))
                                    }
                                }
                            },
                            singleLine = true,
                            shape = RoundedCornerShape(AppRadius.medium),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = AppColors.brandPrimary,
                                unfocusedBorderColor = AppColors.borderDefault,
                                focusedContainerColor = AppColors.backgroundSecondary,
                                unfocusedContainerColor = AppColors.backgroundSecondary
                            )
                        )

                        Spacer(Modifier.width(8.dp))

                        IconButton(onClick = onDismiss) {
                            Icon(Icons.Default.Close, contentDescription = "Close", tint = AppColors.textSecondary)
                        }
                    }

                    Spacer(Modifier.height(AppSpacing.sm))

                    // Entity Filter Chips + Copilot Tab
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        FilterChip(
                            selected = activeTab == "all",
                            onClick = { activeTab = "all" },
                            label = { Text("All") },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = AppColors.brandPrimary.copy(alpha = 0.15f),
                                selectedLabelColor = AppColors.brandPrimary
                            )
                        )
                        FilterChip(
                            selected = activeTab == "task",
                            onClick = { activeTab = "task" },
                            label = { Text("Tasks") },
                            leadingIcon = { Icon(Icons.Default.CheckCircle, null, Modifier.size(16.dp)) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = AppColors.brandPrimary.copy(alpha = 0.15f),
                                selectedLabelColor = AppColors.brandPrimary
                            )
                        )
                        FilterChip(
                            selected = activeTab == "message",
                            onClick = { activeTab = "message" },
                            label = { Text("Messages") },
                            leadingIcon = { Icon(Icons.Default.Chat, null, Modifier.size(16.dp)) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = AppColors.brandPrimary.copy(alpha = 0.15f),
                                selectedLabelColor = AppColors.brandPrimary
                            )
                        )
                        FilterChip(
                            selected = activeTab == "meeting",
                            onClick = { activeTab = "meeting" },
                            label = { Text("Meetings") },
                            leadingIcon = { Icon(Icons.Default.VideoCall, null, Modifier.size(16.dp)) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = AppColors.brandPrimary.copy(alpha = 0.15f),
                                selectedLabelColor = AppColors.brandPrimary
                            )
                        )
                        FilterChip(
                            selected = activeTab == "member",
                            onClick = { activeTab = "member" },
                            label = { Text("People") },
                            leadingIcon = { Icon(Icons.Default.Person, null, Modifier.size(16.dp)) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = AppColors.brandPrimary.copy(alpha = 0.15f),
                                selectedLabelColor = AppColors.brandPrimary
                            )
                        )
                        FilterChip(
                            selected = activeTab == "copilot",
                            onClick = { activeTab = "copilot" },
                            label = { Text("✨ AI Copilot", fontWeight = FontWeight.Bold) },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = Color(0xFF6366F1).copy(alpha = 0.2f),
                                selectedLabelColor = Color(0xFF6366F1)
                            )
                        )
                    }

                    // Search Engine Mode Selector (Hybrid, Semantic, Keyword)
                    if (activeTab != "copilot") {
                        Spacer(Modifier.height(AppSpacing.xs))
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(AppRadius.small))
                                .background(AppColors.backgroundSecondary.copy(alpha = 0.7f))
                                .padding(3.dp),
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            val modes = listOf(
                                Triple("hybrid", "✨ Hybrid (AI)", "Keyword + Dense Vector Semantic Matching"),
                                Triple("semantic", "🧠 Semantic", "Vector concept clusters & cosine similarity"),
                                Triple("keyword", "🔍 Keyword", "Standard lexical substring search")
                            )
                            modes.forEach { (modeKey, modeTitle, _) ->
                                val isSelected = searchMode == modeKey
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .clip(RoundedCornerShape(AppRadius.small))
                                        .background(if (isSelected) AppColors.brandPrimary.copy(alpha = 0.22f) else Color.Transparent)
                                        .clickable { searchMode = modeKey }
                                        .padding(vertical = 5.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = modeTitle,
                                        style = AppTypography.caption2,
                                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                        color = if (isSelected) AppColors.brandPrimary else AppColors.textSecondary
                                    )
                                }
                            }
                        }
                    }

                    Spacer(Modifier.height(AppSpacing.sm))
                    HorizontalDivider(color = AppColors.borderDefault)
                    Spacer(Modifier.height(AppSpacing.sm))

                    // Content View
                    if (activeTab == "copilot") {
                        // AI COPILOT VIEW
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(max = 480.dp)
                                .verticalScroll(rememberScrollState())
                        ) {
                            // Submode Selector (Ask AI vs Task Breakdown vs Daily Standup)
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(AppRadius.medium))
                                    .background(AppColors.backgroundSecondary)
                                    .padding(4.dp),
                                horizontalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                Button(
                                    onClick = {
                                        copilotMode = "rag"
                                        copilotSummary = null
                                        copilotTasks = emptyList()
                                        copilotCitations = emptyList()
                                        copilotFollowUps = emptyList()
                                        tasksAddedSuccess = false
                                    },
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = if (copilotMode == "rag") AppColors.brandPrimary else Color.Transparent,
                                        contentColor = if (copilotMode == "rag") Color.White else AppColors.textSecondary
                                    ),
                                    shape = RoundedCornerShape(AppRadius.small),
                                    contentPadding = PaddingValues(vertical = 8.dp)
                                ) {
                                    Icon(Icons.Default.AutoAwesome, contentDescription = null, modifier = Modifier.size(14.dp))
                                    Spacer(Modifier.width(4.dp))
                                    Text("Ask AI", style = AppTypography.footnote, fontWeight = FontWeight.SemiBold)
                                }

                                Button(
                                    onClick = {
                                        copilotMode = "breakdown"
                                        copilotSummary = null
                                        copilotTasks = emptyList()
                                        copilotCitations = emptyList()
                                        copilotFollowUps = emptyList()
                                        tasksAddedSuccess = false
                                    },
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = if (copilotMode == "breakdown") AppColors.brandPrimary else Color.Transparent,
                                        contentColor = if (copilotMode == "breakdown") Color.White else AppColors.textSecondary
                                    ),
                                    shape = RoundedCornerShape(AppRadius.small),
                                    contentPadding = PaddingValues(vertical = 8.dp)
                                ) {
                                    Icon(Icons.Default.AccountTree, contentDescription = null, modifier = Modifier.size(14.dp))
                                    Spacer(Modifier.width(4.dp))
                                    Text("Breakdown", style = AppTypography.footnote, fontWeight = FontWeight.SemiBold)
                                }

                                Button(
                                    onClick = {
                                        copilotMode = "standup"
                                        copilotSummary = null
                                        copilotTasks = emptyList()
                                        copilotCitations = emptyList()
                                        copilotFollowUps = emptyList()
                                        tasksAddedSuccess = false
                                    },
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = if (copilotMode == "standup") AppColors.brandPrimary else Color.Transparent,
                                        contentColor = if (copilotMode == "standup") Color.White else AppColors.textSecondary
                                    ),
                                    shape = RoundedCornerShape(AppRadius.small),
                                    contentPadding = PaddingValues(vertical = 8.dp)
                                ) {
                                    Icon(Icons.Default.Today, contentDescription = null, modifier = Modifier.size(14.dp))
                                    Spacer(Modifier.width(4.dp))
                                    Text("Standup", style = AppTypography.footnote, fontWeight = FontWeight.SemiBold)
                                }
                            }

                            Spacer(Modifier.height(AppSpacing.md))

                            if (copilotMode == "rag") {
                                // Ask Knowledge Base (RAG) Mode
                                Text(
                                    "Ask questions across project tasks, conversations, and meetings with grounded source citations.",
                                    style = AppTypography.caption1,
                                    color = AppColors.textSecondary
                                )
                                Spacer(Modifier.height(8.dp))

                                OutlinedTextField(
                                    value = copilotPrompt,
                                    onValueChange = { copilotPrompt = it },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .testTag("copilot_rag_input"),
                                    placeholder = {
                                        Text("e.g. What was discussed about the login screen bug?")
                                    },
                                    minLines = 2,
                                    maxLines = 4,
                                    shape = RoundedCornerShape(AppRadius.medium),
                                    colors = OutlinedTextFieldDefaults.colors(
                                        focusedBorderColor = AppColors.brandPrimary,
                                        unfocusedBorderColor = AppColors.borderDefault
                                    )
                                )

                                Spacer(Modifier.height(8.dp))

                                // Quick suggestion chips
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                                ) {
                                    listOf("Login screen bug", "OAuth PKCE crash", "Sprint blockers").forEach { chip ->
                                        AssistChip(
                                            onClick = {
                                                copilotPrompt = chip
                                                startStreamingAsk(chip)
                                            },
                                            label = { Text(chip, fontSize = 11.sp) }
                                        )
                                    }
                                }

                                Spacer(Modifier.height(10.dp))

                                if (isStreaming) {
                                    Button(
                                        onClick = {
                                            streamingJob?.cancel()
                                            isStreaming = false
                                        },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .testTag("btn_copilot_stop"),
                                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusError),
                                        shape = RoundedCornerShape(AppRadius.medium)
                                    ) {
                                        Icon(Icons.Default.Stop, null, Modifier.size(18.dp))
                                        Spacer(Modifier.width(8.dp))
                                        Text("Stop Generating", fontWeight = FontWeight.Bold)
                                    }
                                } else {
                                    Button(
                                        onClick = {
                                            startStreamingAsk(copilotPrompt)
                                        },
                                        enabled = !isCopilotLoading && copilotPrompt.isNotBlank(),
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .testTag("btn_copilot_ask"),
                                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF6366F1)),
                                        shape = RoundedCornerShape(AppRadius.medium)
                                    ) {
                                        if (isCopilotLoading) {
                                            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                                            Spacer(Modifier.width(8.dp))
                                            Text("Connecting to stream...")
                                        } else {
                                            Icon(Icons.Default.AutoAwesome, null, Modifier.size(18.dp))
                                            Spacer(Modifier.width(8.dp))
                                            Text("Ask AI (RAG)", fontWeight = FontWeight.Bold)
                                        }
                                    }
                                }

                                if (copilotSummary != null) {
                                    Spacer(Modifier.height(AppSpacing.md))
                                    Card(
                                        modifier = Modifier.fillMaxWidth(),
                                        colors = CardDefaults.cardColors(containerColor = AppColors.backgroundSecondary),
                                        shape = RoundedCornerShape(AppRadius.medium)
                                    ) {
                                        Column(Modifier.padding(14.dp)) {
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceBetween,
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                Row(verticalAlignment = Alignment.CenterVertically) {
                                                    Text("Knowledge Answer", style = AppTypography.headline, color = AppColors.brandPrimary)
                                                    if (isStreaming) {
                                                        Spacer(Modifier.width(8.dp))
                                                        Surface(
                                                            shape = RoundedCornerShape(4.dp),
                                                            color = Color(0xFF6366F1).copy(alpha = 0.15f)
                                                        ) {
                                                            Text(
                                                                "Streaming...",
                                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                                                style = AppTypography.caption2,
                                                                fontWeight = FontWeight.Bold,
                                                                color = Color(0xFF6366F1)
                                                            )
                                                        }
                                                    }
                                                }
                                                if (isStreaming) {
                                                    OutlinedButton(
                                                        onClick = {
                                                            streamingJob?.cancel()
                                                            isStreaming = false
                                                        },
                                                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 2.dp),
                                                        modifier = Modifier.height(28.dp)
                                                    ) {
                                                        Icon(Icons.Default.Stop, null, modifier = Modifier.size(14.dp), tint = AppColors.statusError)
                                                        Spacer(Modifier.width(4.dp))
                                                        Text("Stop", fontSize = 11.sp, color = AppColors.statusError)
                                                    }
                                                }
                                            }
                                            Spacer(Modifier.height(6.dp))
                                            Text(
                                                text = (copilotSummary ?: "") + if (isStreaming && cursorVisible) " ▎" else "",
                                                style = AppTypography.callout,
                                                color = AppColors.textPrimary
                                            )
                                        }
                                    }
                                }

                                if (copilotCitations.isNotEmpty()) {
                                    Spacer(Modifier.height(AppSpacing.md))
                                    Text("Sources & Grounded Citations (${copilotCitations.size})", style = AppTypography.headline, color = AppColors.textPrimary)
                                    Spacer(Modifier.height(6.dp))
                                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                        copilotCitations.forEach { citation ->
                                            Card(
                                                modifier = Modifier
                                                    .fillMaxWidth()
                                                    .clickable {
                                                        if (citation.deepLink.isNotBlank()) {
                                                            onNavigateDeeplink(citation.deepLink)
                                                            onDismiss()
                                                        }
                                                    },
                                                colors = CardDefaults.cardColors(containerColor = AppColors.backgroundSecondary),
                                                shape = RoundedCornerShape(AppRadius.medium)
                                            ) {
                                                Row(
                                                    modifier = Modifier.padding(10.dp),
                                                    verticalAlignment = Alignment.Top
                                                ) {
                                                    Box(
                                                        modifier = Modifier
                                                            .size(24.dp)
                                                            .clip(CircleShape)
                                                            .background(Color(0xFF6366F1).copy(alpha = 0.2f)),
                                                        contentAlignment = Alignment.Center
                                                    ) {
                                                        Text(
                                                            "[${citation.citationNumber}]",
                                                            fontSize = 11.sp,
                                                            fontWeight = FontWeight.Bold,
                                                            color = Color(0xFF6366F1)
                                                        )
                                                    }
                                                    Spacer(Modifier.width(10.dp))
                                                    Column(modifier = Modifier.weight(1f)) {
                                                        Row(
                                                            modifier = Modifier.fillMaxWidth(),
                                                            horizontalArrangement = Arrangement.SpaceBetween,
                                                            verticalAlignment = Alignment.CenterVertically
                                                        ) {
                                                            Text(
                                                                citation.title,
                                                                style = AppTypography.body,
                                                                fontWeight = FontWeight.SemiBold,
                                                                color = AppColors.textPrimary,
                                                                maxLines = 1,
                                                                overflow = TextOverflow.Ellipsis,
                                                                modifier = Modifier.weight(1f)
                                                            )
                                                            if (citation.similarityScore != null) {
                                                                Text(
                                                                    "${(citation.similarityScore * 100).toInt()}% match",
                                                                    fontSize = 10.sp,
                                                                    fontWeight = FontWeight.Bold,
                                                                    color = Color(0xFF10B981)
                                                                )
                                                            }
                                                        }
                                                        if (citation.snippet.isNotBlank()) {
                                                            Spacer(Modifier.height(2.dp))
                                                            Text(
                                                                citation.snippet,
                                                                style = AppTypography.caption1,
                                                                color = AppColors.textSecondary,
                                                                maxLines = 2,
                                                                overflow = TextOverflow.Ellipsis
                                                            )
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                if (copilotFollowUps.isNotEmpty()) {
                                    Spacer(Modifier.height(AppSpacing.md))
                                    Text("Suggested Follow-Ups", style = AppTypography.caption1, fontWeight = FontWeight.Bold, color = AppColors.textSecondary)
                                    Spacer(Modifier.height(6.dp))
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                                    ) {
                                        copilotFollowUps.forEach { fu ->
                                            AssistChip(
                                                onClick = {
                                                    copilotPrompt = fu
                                                },
                                                leadingIcon = {
                                                    Icon(Icons.Default.AutoAwesome, null, Modifier.size(12.dp), tint = Color(0xFF6366F1))
                                                },
                                                label = { Text(fu, fontSize = 11.sp) }
                                            )
                                        }
                                    }
                                }
                            }

                            Spacer(Modifier.height(AppSpacing.md))

                            if (copilotMode == "breakdown") {
                                // Task Breakdown Mode
                                Text(
                                    "Decompose high-level feature specs into executable subtasks with hours and priority tags.",
                                    style = AppTypography.caption1,
                                    color = AppColors.textSecondary
                                )
                                Spacer(Modifier.height(8.dp))

                                OutlinedTextField(
                                    value = copilotPrompt,
                                    onValueChange = { copilotPrompt = it },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .testTag("copilot_prompt_input"),
                                    placeholder = {
                                        Text("e.g. Implement Single Sign-On with Google, Microsoft, and SAML 2.0 with audit logging")
                                    },
                                    minLines = 2,
                                    maxLines = 4,
                                    shape = RoundedCornerShape(AppRadius.medium),
                                    colors = OutlinedTextFieldDefaults.colors(
                                        focusedBorderColor = AppColors.brandPrimary,
                                        unfocusedBorderColor = AppColors.borderDefault
                                    )
                                )

                                Spacer(Modifier.height(10.dp))

                                if (isStreaming) {
                                    Button(
                                        onClick = {
                                            streamingJob?.cancel()
                                            isStreaming = false
                                        },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .testTag("btn_copilot_stop_breakdown"),
                                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusError),
                                        shape = RoundedCornerShape(AppRadius.medium)
                                    ) {
                                        Icon(Icons.Default.Stop, null, Modifier.size(18.dp))
                                        Spacer(Modifier.width(8.dp))
                                        Text("Stop Generating", fontWeight = FontWeight.Bold)
                                    }
                                } else {
                                    Button(
                                        onClick = {
                                            startStreamingBreakdown(copilotPrompt)
                                        },
                                        enabled = !isCopilotLoading && copilotPrompt.isNotBlank(),
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .testTag("btn_copilot_generate"),
                                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF6366F1)),
                                        shape = RoundedCornerShape(AppRadius.medium)
                                    ) {
                                        if (isCopilotLoading) {
                                            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                                            Spacer(Modifier.width(8.dp))
                                            Text("Connecting to stream...")
                                        } else {
                                            Icon(Icons.Default.AutoAwesome, null, Modifier.size(18.dp))
                                            Spacer(Modifier.width(8.dp))
                                            Text("Generate Task Breakdown", fontWeight = FontWeight.Bold)
                                        }
                                    }
                                }

                                if (copilotSummary != null) {
                                    Spacer(Modifier.height(AppSpacing.md))
                                    Card(
                                        modifier = Modifier.fillMaxWidth(),
                                        colors = CardDefaults.cardColors(containerColor = AppColors.backgroundSecondary),
                                        shape = RoundedCornerShape(AppRadius.medium)
                                    ) {
                                        Column(Modifier.padding(12.dp)) {
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceBetween,
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                Text("Summary", style = AppTypography.footnote, fontWeight = FontWeight.Bold, color = AppColors.brandPrimary)
                                                if (isStreaming) {
                                                    Surface(
                                                        shape = RoundedCornerShape(4.dp),
                                                        color = Color(0xFF6366F1).copy(alpha = 0.15f)
                                                    ) {
                                                        Text(
                                                            "Streaming...",
                                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                                            style = AppTypography.caption2,
                                                            fontWeight = FontWeight.Bold,
                                                            color = Color(0xFF6366F1)
                                                        )
                                                    }
                                                }
                                            }
                                            Spacer(Modifier.height(4.dp))
                                            Text(
                                                text = (copilotSummary ?: "") + if (isStreaming && cursorVisible) " ▎" else "",
                                                style = AppTypography.callout,
                                                color = AppColors.textPrimary
                                            )
                                        }
                                    }
                                }

                                if (copilotTasks.isNotEmpty()) {
                                    Spacer(Modifier.height(AppSpacing.md))
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text("Suggested Subtasks (${copilotTasks.size})", style = AppTypography.headline, color = AppColors.textPrimary)
                                        Button(
                                            onClick = {
                                                isAddingTasks = true
                                                coroutineScope.launch {
                                                    try {
                                                        for (t in copilotTasks) {
                                                            api.request(
                                                                "/api/tasks",
                                                                method = "POST",
                                                                body = json(
                                                                    "title" to t.title,
                                                                    "description" to (t.description ?: ""),
                                                                    "priority" to t.priority,
                                                                    "status" to "todo"
                                                                )
                                                            )
                                                        }
                                                        tasksAddedSuccess = true
                                                        onTaskCreated?.invoke()
                                                        Toast.makeText(context, "Added ${copilotTasks.size} subtasks to backlog", Toast.LENGTH_SHORT).show()
                                                    } catch (e: Exception) {
                                                        errorMessage = e.message ?: "Failed to add subtasks"
                                                    } finally {
                                                        isAddingTasks = false
                                                    }
                                                }
                                            },
                                            enabled = !isAddingTasks && !tasksAddedSuccess,
                                            colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusSuccess),
                                            shape = RoundedCornerShape(AppRadius.small),
                                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                                        ) {
                                            if (tasksAddedSuccess) {
                                                Icon(Icons.Default.Check, null, Modifier.size(16.dp))
                                                Spacer(Modifier.width(4.dp))
                                                Text("Added to Backlog", fontSize = 12.sp)
                                            } else if (isAddingTasks) {
                                                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(14.dp), strokeWidth = 2.dp)
                                                Spacer(Modifier.width(4.dp))
                                                Text("Adding...", fontSize = 12.sp)
                                            } else {
                                                Icon(Icons.Default.Add, null, Modifier.size(16.dp))
                                                Spacer(Modifier.width(4.dp))
                                                Text("Add All to Backlog", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                            }
                                        }
                                    }

                                    Spacer(Modifier.height(8.dp))
                                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                        copilotTasks.forEach { task ->
                                            Card(
                                                modifier = Modifier.fillMaxWidth(),
                                                colors = CardDefaults.cardColors(containerColor = AppColors.backgroundSecondary),
                                                shape = RoundedCornerShape(AppRadius.small)
                                            ) {
                                                Row(
                                                    modifier = Modifier
                                                        .fillMaxWidth()
                                                        .padding(10.dp),
                                                    verticalAlignment = Alignment.CenterVertically
                                                ) {
                                                    Icon(Icons.Default.CheckCircle, null, tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                                                    Spacer(Modifier.width(10.dp))
                                                    Column(modifier = Modifier.weight(1f)) {
                                                        Text(task.title, style = AppTypography.headline, color = AppColors.textPrimary)
                                                        if (!task.description.isNullOrBlank()) {
                                                            Text(task.description, style = AppTypography.caption1, color = AppColors.textSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis)
                                                        }
                                                    }
                                                    Spacer(Modifier.width(8.dp))
                                                    // Priority & Hours chips
                                                    Column(horizontalAlignment = Alignment.End) {
                                                        Surface(
                                                            shape = RoundedCornerShape(4.dp),
                                                            color = when (task.priority.lowercase()) {
                                                                "high", "critical" -> AppColors.statusError.copy(alpha = 0.2f)
                                                                "low" -> AppColors.statusSuccess.copy(alpha = 0.2f)
                                                                else -> Color(0xFF6366F1).copy(alpha = 0.2f)
                                                            }
                                                        ) {
                                                            Text(
                                                                task.priority.uppercase(),
                                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                                                style = AppTypography.caption2,
                                                                fontWeight = FontWeight.Bold,
                                                                color = when (task.priority.lowercase()) {
                                                                    "high", "critical" -> AppColors.statusError
                                                                    "low" -> AppColors.statusSuccess
                                                                    else -> Color(0xFF6366F1)
                                                                }
                                                            )
                                                        }
                                                        Spacer(Modifier.height(2.dp))
                                                        Text("${task.estimateHours}h", style = AppTypography.caption2, color = AppColors.textTertiary)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                // Daily Standup Mode
                                Text(
                                    "Aggregates your assigned tasks, scheduled meetings, and updates into a structured Yesterday / Today / Blockers daily report.",
                                    style = AppTypography.caption1,
                                    color = AppColors.textSecondary
                                )
                                Spacer(Modifier.height(12.dp))

                                if (isStreaming) {
                                    Button(
                                        onClick = {
                                            streamingJob?.cancel()
                                            isStreaming = false
                                        },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .testTag("btn_copilot_stop_standup"),
                                        colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusError),
                                        shape = RoundedCornerShape(AppRadius.medium)
                                    ) {
                                        Icon(Icons.Default.Stop, null, Modifier.size(18.dp))
                                        Spacer(Modifier.width(8.dp))
                                        Text("Stop Generating", fontWeight = FontWeight.Bold)
                                    }
                                } else {
                                    Button(
                                        onClick = {
                                            startStreamingStandup()
                                        },
                                        enabled = !isCopilotLoading,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .testTag("btn_generate_standup"),
                                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF6366F1)),
                                        shape = RoundedCornerShape(AppRadius.medium)
                                    ) {
                                        if (isCopilotLoading) {
                                            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                                            Spacer(Modifier.width(8.dp))
                                            Text("Connecting to stream...")
                                        } else {
                                            Icon(Icons.Default.Today, null, Modifier.size(18.dp))
                                            Spacer(Modifier.width(8.dp))
                                            Text("Generate Daily Standup Report", fontWeight = FontWeight.Bold)
                                        }
                                    }
                                }

                                if (copilotSummary != null) {
                                    Spacer(Modifier.height(AppSpacing.md))
                                    Card(
                                        modifier = Modifier.fillMaxWidth(),
                                        colors = CardDefaults.cardColors(containerColor = AppColors.backgroundSecondary),
                                        shape = RoundedCornerShape(AppRadius.medium)
                                    ) {
                                        Column(Modifier.padding(14.dp)) {
                                            Row(
                                                modifier = Modifier.fillMaxWidth(),
                                                horizontalArrangement = Arrangement.SpaceBetween,
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                Row(verticalAlignment = Alignment.CenterVertically) {
                                                    Text("Daily Standup Report", style = AppTypography.headline, color = AppColors.brandPrimary)
                                                    if (isStreaming) {
                                                        Spacer(Modifier.width(8.dp))
                                                        Surface(
                                                            shape = RoundedCornerShape(4.dp),
                                                            color = Color(0xFF6366F1).copy(alpha = 0.15f)
                                                        ) {
                                                            Text(
                                                                "Streaming...",
                                                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                                                style = AppTypography.caption2,
                                                                fontWeight = FontWeight.Bold,
                                                                color = Color(0xFF6366F1)
                                                            )
                                                        }
                                                    }
                                                }
                                                IconButton(
                                                    onClick = {
                                                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                                        val clip = ClipData.newPlainText("Standup Report", copilotSummary ?: "")
                                                        clipboard.setPrimaryClip(clip)
                                                        Toast.makeText(context, "Copied to clipboard!", Toast.LENGTH_SHORT).show()
                                                    }
                                                ) {
                                                    Icon(Icons.Default.ContentCopy, contentDescription = "Copy", tint = AppColors.brandPrimary)
                                                }
                                            }
                                            Spacer(Modifier.height(8.dp))
                                            Text(
                                                text = (copilotSummary ?: "") + if (isStreaming && cursorVisible) " ▎" else "",
                                                style = AppTypography.callout,
                                                color = AppColors.textPrimary,
                                                lineHeight = 22.sp
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // REGULAR SEARCH RESULTS VIEW
                        if (isSearching) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(180.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator(color = AppColors.brandPrimary)
                            }
                        } else if (searchResults.isEmpty()) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(160.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Icon(
                                        imageVector = Icons.Default.SearchOff,
                                        contentDescription = null,
                                        tint = AppColors.textTertiary,
                                        modifier = Modifier.size(36.dp)
                                    )
                                    Spacer(Modifier.height(8.dp))
                                    Text(
                                        if (searchQuery.isBlank()) "Type query to search across the organization" else "No matching items found",
                                        style = AppTypography.footnote,
                                        color = AppColors.textSecondary
                                    )
                                }
                            }
                        } else {
                            LazyColumn(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .heightIn(max = 420.dp),
                                verticalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                items(searchResults, key = { it.id }) { item ->
                                    val icon = when (item.entityType.lowercase()) {
                                        "task" -> Icons.Default.CheckCircle
                                        "message" -> Icons.Default.Chat
                                        "meeting" -> Icons.Default.VideoCall
                                        "member" -> Icons.Default.Person
                                        else -> Icons.Default.Folder
                                    }
                                    val iconTint = when (item.entityType.lowercase()) {
                                        "task" -> AppColors.brandPrimary
                                        "message" -> Color(0xFF14B8A6) // Teal
                                        "meeting" -> Color(0xFFA855F7) // Purple
                                        "member" -> Color(0xFF0284C7)  // Blue
                                        else -> AppColors.brandPrimary
                                    }

                                    Card(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable {
                                                onNavigateDeeplink(item.deepLink)
                                            }
                                            .testTag("search_result_${item.id}"),
                                        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
                                        shape = RoundedCornerShape(AppRadius.medium)
                                    ) {
                                        Row(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .padding(horizontal = 8.dp, vertical = 10.dp),
                                            verticalAlignment = Alignment.CenterVertically
                                        ) {
                                            Box(
                                                modifier = Modifier
                                                    .size(34.dp)
                                                    .clip(RoundedCornerShape(8.dp))
                                                    .background(iconTint.copy(alpha = 0.15f)),
                                                contentAlignment = Alignment.Center
                                            ) {
                                                Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(18.dp))
                                            }

                                            Spacer(Modifier.width(12.dp))

                                            Column(modifier = Modifier.weight(1f)) {
                                                Text(
                                                    item.title,
                                                    style = AppTypography.headline,
                                                    color = AppColors.textPrimary,
                                                    maxLines = 1,
                                                    overflow = TextOverflow.Ellipsis
                                                )
                                                if (item.subtitle.isNotBlank()) {
                                                    Text(
                                                        item.subtitle,
                                                        style = AppTypography.caption1,
                                                        color = AppColors.textSecondary,
                                                        maxLines = 1,
                                                        overflow = TextOverflow.Ellipsis
                                                    )
                                                }
                                                if (!item.highlightSnippet.isNullOrBlank()) {
                                                    Text(
                                                        "\"${item.highlightSnippet}\"",
                                                        style = AppTypography.caption2,
                                                        fontStyle = FontStyle.Italic,
                                                        color = Color(0xFFA5B4FC),
                                                        maxLines = 1,
                                                        overflow = TextOverflow.Ellipsis
                                                    )
                                                }
                                            }

                                            if (item.similarityScore != null) {
                                                Spacer(Modifier.width(6.dp))
                                                Surface(
                                                    shape = RoundedCornerShape(4.dp),
                                                    color = Color(0xFF6366F1).copy(alpha = 0.18f)
                                                ) {
                                                    Text(
                                                        "✨ ${(item.similarityScore * 100).toInt()}%",
                                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                                        style = AppTypography.caption2,
                                                        color = Color(0xFF818CF8),
                                                        fontWeight = FontWeight.Bold
                                                    )
                                                }
                                            } else if (item.matchType == "exact") {
                                                Spacer(Modifier.width(6.dp))
                                                Surface(
                                                    shape = RoundedCornerShape(4.dp),
                                                    color = AppColors.statusSuccess.copy(alpha = 0.18f)
                                                ) {
                                                    Text(
                                                        "Exact",
                                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                                        style = AppTypography.caption2,
                                                        color = AppColors.statusSuccess,
                                                        fontWeight = FontWeight.SemiBold
                                                    )
                                                }
                                            }

                                            if (!item.badge.isNullOrBlank()) {
                                                Spacer(Modifier.width(8.dp))
                                                Surface(
                                                    shape = RoundedCornerShape(4.dp),
                                                    color = iconTint.copy(alpha = 0.15f)
                                                ) {
                                                    Text(
                                                        item.badge,
                                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                                        style = AppTypography.caption2,
                                                        color = iconTint,
                                                        fontWeight = FontWeight.SemiBold
                                                    )
                                                }
                                            }

                                            Spacer(Modifier.width(6.dp))

                                            Icon(
                                                Icons.AutoMirrored.Filled.ArrowForward,
                                                contentDescription = "Navigate",
                                                tint = AppColors.textTertiary,
                                                modifier = Modifier.size(16.dp)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (errorMessage != null) {
                        Spacer(Modifier.height(8.dp))
                        Text(
                            text = errorMessage ?: "",
                            style = AppTypography.caption1,
                            color = AppColors.statusError
                        )
                    }
                }
            }
        }
    }
}
