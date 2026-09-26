package com.acme.taskflow.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.gestures.scrollBy
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
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.zIndex
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import kotlin.math.roundToInt

private val priorities = choices("low", "medium", "high", "critical")
private val statuses = choices("todo", "in_progress", "in_review", "done", "cancelled")
private val types = choices("task", "bug", "story", "epic", "subtask")

data class BoardColumnData(
    val id: String,
    val title: String,
    val wipLimit: Int? = null,
    val headerColor: Color? = null
)

fun calculateNewPosition(destTasksExcludingMoved: List<JsonObject>, insertIndex: Int): Double {
    if (destTasksExcludingMoved.isEmpty()) {
        return 65536.0
    }
    val boundedIndex = insertIndex.coerceIn(0, destTasksExcludingMoved.size)
    return when {
        boundedIndex == 0 -> {
            val firstPos = destTasksExcludingMoved[0].number("position")?.toDouble() ?: 65536.0
            firstPos / 2.0
        }
        boundedIndex >= destTasksExcludingMoved.size -> {
            val lastPos = destTasksExcludingMoved.last().number("position")?.toDouble() ?: 65536.0
            lastPos + 65536.0
        }
        else -> {
            val prevPos = destTasksExcludingMoved[boundedIndex - 1].number("position")?.toDouble() ?: 65536.0
            val nextPos = destTasksExcludingMoved[boundedIndex].number("position")?.toDouble() ?: (prevPos + 65536.0)
            (prevPos + nextPos) / 2.0
        }
    }
}

@Composable
fun TasksScreen(
    vm: AppViewModel,
    api: ApiClient,
    lists: List<Choice>,
    listId: String,
    mine: Boolean,
    projectId: String = "",
    onBackToWorkspace: (() -> Unit)? = null,
    onDetailActive: ((Boolean) -> Unit)? = null
) {
    var search by rememberSaveable(listId, mine) { mutableStateOf("") }
    var priority by rememberSaveable { mutableStateOf("") }
    var status by rememberSaveable { mutableStateOf("") }
    var type by rememberSaveable { mutableStateOf("") }
    var mode by rememberSaveable { mutableStateOf("List") }
    var selected by rememberSaveable(listId, mine) { mutableStateOf<String?>(null) }
    var selectedEpicId by remember { mutableStateOf<String?>(null) }
    var create by remember { mutableStateOf(false) }
    var showSavedViews by remember { mutableStateOf(false) }
    var showSyncCenter by remember { mutableStateOf(false) }

    LaunchedEffect(selected) {
        onDetailActive?.invoke(selected != null)
    }

    val remote = rememberRemote(
        api,
        if (mine) "/api/tasks/assigned" else "/api/tasks",
        vm.revision,
        query = buildMap {
            if (listId.isNotBlank()) put("list_id", listId)
            if (projectId.isNotBlank()) put("project_id", projectId)
        },
        paged = true
    )
    val members = rememberRemote(api, "/api/organizations/${api.orgId}/members")
    val memberChoices = members.data.rows().map { Choice(it.text("user_id"), it.text("display_name")) }

    val coroutineScope = rememberCoroutineScope()
    val localStatusOverrides = remember { mutableStateMapOf<String, String>() }
    val localPriorityOverrides = remember { mutableStateMapOf<String, String>() }
    val localAssigneeOverrides = remember { mutableStateMapOf<String, String?>() }
    val localPositionOverrides = remember { mutableStateMapOf<String, Double>() }

    LaunchedEffect(remote.data) {
        val rows = remote.data.rows()
        for (row in rows) {
            val id = row.id
            if (localStatusOverrides[id] == row.text("status")) {
                localStatusOverrides.remove(id)
            }
            if (localPriorityOverrides[id] == row.text("priority")) {
                localPriorityOverrides.remove(id)
            }
            val serverAssignee = row.text("assignee_id").ifEmpty { null }
            if (localAssigneeOverrides[id] == serverAssignee) {
                localAssigneeOverrides.remove(id)
            }
            if (localPositionOverrides[id] == row.number("position")?.toDouble()) {
                localPositionOverrides.remove(id)
            }
        }
    }

    val baseTasks = remote.data.rows().map { task ->
        var modified: JsonObject? = null
        val stOverride = localStatusOverrides[task.id]
        if (stOverride != null && stOverride != task.text("status")) {
            modified = (modified ?: task.deepCopy()).also { it.addProperty("status", stOverride) }
        }
        val prOverride = localPriorityOverrides[task.id]
        if (prOverride != null && prOverride != task.text("priority")) {
            modified = (modified ?: task.deepCopy()).also { it.addProperty("priority", prOverride) }
        }
        if (localAssigneeOverrides.containsKey(task.id)) {
            val asOverride = localAssigneeOverrides[task.id]
            if (asOverride != task.text("assignee_id").ifEmpty { null }) {
                modified = (modified ?: task.deepCopy()).also {
                    if (asOverride == null) it.remove("assignee_id") else it.addProperty("assignee_id", asOverride)
                }
            }
        }
        val posOverride = localPositionOverrides[task.id]
        if (posOverride != null && posOverride != task.number("position")?.toDouble()) {
            modified = (modified ?: task.deepCopy()).also { it.addProperty("position", posOverride) }
        }
        modified ?: task
    }

    val tasks = baseTasks.filter {
        (search.isBlank() || "${it.text("title")} ${it.text("issue_key")}".contains(search, true)) &&
                (priority.isBlank() || it.text("priority") == priority) &&
                (status.isBlank() || it.text("status") == status) &&
                (type.isBlank() || it.text("task_type") == type)
    }

    var isMoving by remember { mutableStateOf(false) }
    val onMoveTask: (String, String, String, Double) -> Unit = { taskId, groupType, targetValue, targetPosition ->
        val taskItem = tasks.firstOrNull { it.id == taskId }
        val ver = taskItem?.number("version")
        localPositionOverrides[taskId] = targetPosition

        when (groupType) {
            "status" -> {
                localStatusOverrides[taskId] = targetValue
                coroutineScope.launch {
                    isMoving = true
                    val movePayload = json(
                        "targetStatus" to targetValue,
                        "moves" to listOf(
                            json("taskId" to taskId, "newPosition" to targetPosition)
                        )
                    )
                    val moveResult = runCatching {
                        api.request("/api/tasks/move-multiple", "POST", movePayload)
                    }
                    if (moveResult.isFailure) {
                        val patchResult = runCatching {
                            api.request(
                                "/api/tasks/$taskId",
                                "PATCH",
                                json("status" to targetValue, "position" to targetPosition),
                                version = ver
                            )
                        }
                        if (patchResult.isFailure) {
                            localStatusOverrides.remove(taskId)
                            localPositionOverrides.remove(taskId)
                        }
                    }
                    isMoving = false
                    vm.changed()
                }
            }
            "priority" -> {
                localPriorityOverrides[taskId] = targetValue
                coroutineScope.launch {
                    isMoving = true
                    val patchResult = runCatching {
                        api.request(
                            "/api/tasks/$taskId",
                            "PATCH",
                            json("priority" to targetValue, "position" to targetPosition),
                            version = ver
                        )
                    }
                    if (patchResult.isFailure) {
                        localPriorityOverrides.remove(taskId)
                        localPositionOverrides.remove(taskId)
                    }
                    isMoving = false
                    vm.changed()
                }
            }
            "assignee" -> {
                val targetAssigneeId = if (targetValue == "unassigned") null else targetValue
                localAssigneeOverrides[taskId] = targetAssigneeId
                coroutineScope.launch {
                    isMoving = true
                    val patchPayload = JsonObject().apply {
                        if (targetAssigneeId != null) addProperty("assignee_id", targetAssigneeId)
                        else add("assignee_id", JsonNull.INSTANCE)
                        addProperty("position", targetPosition)
                    }
                    val patchResult = runCatching {
                        api.request(
                            "/api/tasks/$taskId",
                            "PATCH",
                            patchPayload,
                            version = ver
                        )
                    }
                    if (patchResult.isFailure) {
                        localAssigneeOverrides.remove(taskId)
                        localPositionOverrides.remove(taskId)
                    }
                    isMoving = false
                    vm.changed()
                }
            }
        }
    }

    if (selected != null) {
        key(selected) {
            TaskDetailScreen(vm, api, selected!!, lists, memberChoices) { selected = null }
        }
        return
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(AppColors.backgroundPrimary)
    ) {
        // Search & Filter header matching iOS DashboardView.swift searchAndFilterArea
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfacePrimary)
                .padding(top = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                IosTextField(
                    label = "Search tasks...",
                    value = search,
                    onValueChange = { search = it },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    trailingIcon = {
                        if (search.isNotEmpty()) {
                            IconButton(onClick = { search = "" }, modifier = Modifier.size(20.dp)) {
                                Icon(Icons.Default.Close, null, tint = AppColors.textTertiary)
                            }
                        }
                    }
                )
                IconButton(
                    onClick = { showSavedViews = true },
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(AppRadius.medium))
                        .background(AppColors.surfaceElevated)
                ) {
                    Icon(Icons.Default.BookmarkBorder, "Saved views", tint = AppColors.brandPrimary, modifier = Modifier.size(22.dp))
                }
                IconButton(
                    onClick = { showSyncCenter = true },
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(AppRadius.medium))
                        .background(AppColors.surfaceElevated)
                ) {
                    Icon(Icons.Default.Sync, "Sync center", tint = AppColors.brandPrimary, modifier = Modifier.size(22.dp))
                }
                IconButton(
                    onClick = { create = true },
                    modifier = Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(AppRadius.medium))
                        .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                ) {
                    Icon(Icons.Default.Add, "Create task", tint = AppColors.brandPrimary, modifier = Modifier.size(24.dp))
                }
            }

            // View modes (segmented/pills)
            LazyRow(
                modifier = Modifier.fillMaxWidth().testTag("mode_chips"),
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(listOf("List", "Board", "Backlog", "Calendar", "Timeline", "Epics", "Analytics", "Releases")) { item ->
                    IosFilterChip(
                        title = item,
                        isSelected = mode == item,
                        onClick = { mode = item },
                        modifier = Modifier.testTag("chip_$item")
                    )
                }
            }

            // Status filter chips
            Row(
                Modifier
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 2.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IosFilterChip("All", status.isBlank(), onClick = { status = "" })
                statuses.forEach { item ->
                    IosFilterChip(
                        title = item.label,
                        isSelected = status == item.value,
                        onClick = { status = if (status == item.value) "" else item.value }
                    )
                }
                VerticalDivider(Modifier.height(20.dp), color = AppColors.borderSubtle)
                priorities.forEach { item ->
                    IosFilterChip(
                        title = item.label,
                        isSelected = priority == item.value,
                        onClick = { priority = if (priority == item.value) "" else item.value }
                    )
                }
            }
            HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
        }

        if (mode in listOf("Backlog", "Analytics", "Releases")) {
            if (projectId.isBlank()) {
                Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
                    Text(
                        "Select a project from the sidebar to view ${mode.lowercase()}.",
                        style = AppTypography.body,
                        color = AppColors.textSecondary
                    )
                }
            } else {
                ProjectScreen(vm, api, projectId, mode, onTask = { selected = it })
            }
            return@Column
        }

        RemoteStatus(remote)

        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "${tasks.size} tasks",
                style = AppTypography.caption1,
                color = AppColors.textSecondary
            )
        }

        if (!remote.loading && remote.error == null && tasks.isEmpty()) {
            Box(Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
                Text(
                    "No tasks found. Try adjusting your search or filters.",
                    style = AppTypography.body,
                    color = AppColors.textSecondary
                )
            }
        }

        when (mode) {
            "Board" -> KanbanBoard(
                tasks = tasks,
                statuses = statuses,
                memberChoices = memberChoices,
                isMoving = isMoving,
                onSelectTask = { selected = it },
                onMoveTask = onMoveTask
            )
            "Calendar" -> TaskCalendar(tasks, onSelect = { selected = it })
            "Timeline" -> TimelineGanttView(tasks = tasks, onSelectTask = { selected = it })
            "Epics" -> {
                val epics = baseTasks.filter { it.text("task_type").lowercase() == "epic" || it.text("type").lowercase() == "epic" }
                if (epics.isEmpty()) {
                    Box(Modifier.fillMaxSize().padding(32.dp), contentAlignment = Alignment.Center) {
                        Text("No epics found.", style = AppTypography.body, color = AppColors.textSecondary)
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(epics, key = { it.id }) { epic ->
                            IosCard(onClick = { selectedEpicId = epic.id }) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(Modifier.weight(1f)) {
                                        val key = epic.text("issue_key").ifBlank { "Epic" }
                                        Text(key, style = AppTypography.caption1, color = AppColors.brandPrimary)
                                        Text(epic.text("title"), style = AppTypography.headline, color = AppColors.textPrimary)
                                    }
                                    IosPill(label(epic.text("status").ifBlank { "todo" }))
                                }
                                Spacer(Modifier.height(8.dp))
                                val donePoints = epic.number("epic_completed_points").toInt()
                                val totalPoints = epic.number("epic_total_points").toInt()
                                val doneIssues = epic.number("epic_children_done_count").toInt()
                                val totalIssues = epic.number("epic_children_count").toInt()
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Text("Points: $donePoints / $totalPoints", style = AppTypography.caption2, color = AppColors.textSecondary)
                                    Text("Issues: $doneIssues / $totalIssues", style = AppTypography.caption2, color = AppColors.textSecondary)
                                }
                                Spacer(Modifier.height(4.dp))
                                LinearProgressIndicator(
                                    progress = { if (totalPoints > 0) (donePoints.toFloat() / totalPoints).coerceIn(0f, 1f) else 0f },
                                    modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)),
                                    color = AppColors.brandPrimary,
                                    trackColor = AppColors.borderSubtle
                                )
                            }
                        }
                    }
                }
            }
            else -> LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(vertical = 4.dp)
            ) {
                items(tasks, key = { it.id }) { task ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { selected = task.id }
                            .padding(horizontal = 16.dp, vertical = 12.dp)
                    ) {
                        TaskRowContent(task, memberChoices)
                    }
                    HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle, modifier = Modifier.padding(start = 56.dp))
                }
            }
        }
    }

    if (create) {
        EditorDialog("New task", taskFields(null, lists, memberChoices, listId), { create = false }) {
            it.addProperty("id", java.util.UUID.randomUUID().toString())
            api.request("/api/tasks", "POST", it)
            vm.changed()
        }
    }

    if (showSavedViews) {
        SavedViewsModal(
            api = api,
            vm = vm,
            scope = if (listId.isNotBlank()) "list" else "project",
            scopeId = if (listId.isNotBlank()) listId else (projectId.ifBlank { api.orgId }),
            currentMode = mode,
            currentStatus = status,
            currentPriority = priority,
            currentSearch = search,
            onApplyView = { newMode, newStatus, newPriority, newSearch ->
                mode = newMode
                status = newStatus
                priority = newPriority
                search = newSearch
            },
            onDismiss = { showSavedViews = false }
        )
    }

    if (showSyncCenter) {
        SyncCenterModal(
            vm = vm,
            api = api,
            onDismiss = { showSyncCenter = false }
        )
    }

    if (selectedEpicId != null) {
        EpicDetailDashboardModal(
            epicId = selectedEpicId!!,
            api = api,
            vm = vm,
            onSelectTask = { taskId ->
                selectedEpicId = null
                selected = taskId
            },
            onDismiss = { selectedEpicId = null }
        )
    }
}

@Composable
fun KanbanBoard(
    tasks: List<JsonObject>,
    statuses: List<Choice>,
    memberChoices: List<Choice>,
    isMoving: Boolean = false,
    onSelectTask: (String) -> Unit,
    onMoveTask: (taskId: String, groupType: String, targetValue: String, targetPosition: Double) -> Unit,
    modifier: Modifier = Modifier
) {
    var groupBy by rememberSaveable { mutableStateOf("Status") }
    var boardCoordinates by remember { mutableStateOf<LayoutCoordinates?>(null) }
    val columnBounds = remember { mutableStateMapOf<String, Rect>() }
    val cardBounds = remember { mutableStateMapOf<String, Rect>() }
    val lazyListState = rememberLazyListState()

    var draggingTaskId by remember { mutableStateOf<String?>(null) }
    var draggingTask by remember { mutableStateOf<JsonObject?>(null) }
    var dragTouchInBoard by remember { mutableStateOf(Offset.Zero) }
    var dragCardTopLeft by remember { mutableStateOf(Offset.Zero) }
    var dragCardSize by remember { mutableStateOf(IntSize.Zero) }
    var hoveredColumnKey by remember { mutableStateOf<String?>(null) }
    val density = LocalDensity.current

    fun taskGroupKey(task: JsonObject): String {
        return when (groupBy) {
            "Status" -> task.text("status").ifEmpty { "todo" }
            "Priority" -> task.text("priority").ifEmpty { "medium" }
            "Assignee" -> task.text("assignee_id").ifEmpty { "unassigned" }
            else -> task.text("status").ifEmpty { "todo" }
        }
    }

    val columns: List<BoardColumnData> = when (groupBy) {
        "Status" -> statuses.map { choice ->
            val wip = when (choice.value) {
                "in_progress" -> 3
                "in_review" -> 2
                else -> null
            }
            BoardColumnData(id = choice.value, title = choice.label, wipLimit = wip)
        }
        "Priority" -> listOf(
            BoardColumnData("critical", "Critical", wipLimit = 2, headerColor = AppColors.statusError),
            BoardColumnData("high", "High", wipLimit = 4, headerColor = AppColors.statusWarning),
            BoardColumnData("medium", "Medium", wipLimit = null, headerColor = AppColors.brandPrimary),
            BoardColumnData("low", "Low", wipLimit = null, headerColor = AppColors.textSecondary)
        )
        "Assignee" -> {
            val list = mutableListOf(BoardColumnData("unassigned", "Unassigned", wipLimit = null))
            memberChoices.forEach { member ->
                list.add(BoardColumnData(member.value, member.label, wipLimit = 4))
            }
            list
        }
        else -> emptyList()
    }

    // Auto-scroll when dragging near horizontal edges
    LaunchedEffect(dragTouchInBoard, draggingTaskId) {
        if (draggingTaskId != null && boardCoordinates != null) {
            val width = boardCoordinates!!.size.width.toFloat()
            if (dragTouchInBoard.x > width - 120 && lazyListState.canScrollForward) {
                lazyListState.scrollBy(24f)
            } else if (dragTouchInBoard.x < 120 && lazyListState.canScrollBackward) {
                lazyListState.scrollBy(-24f)
            }
        }
    }

    Column(modifier = modifier.fillMaxSize()) {
        // Grouping Toolbar matching iOS BoardView.swift:39-64
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(AppColors.surfaceElevated)
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "Group By:",
                style = AppTypography.subheadline,
                color = AppColors.textSecondary
            )
            Spacer(Modifier.width(10.dp))

            var showGroupByDropdown by remember { mutableStateOf(false) }

            Box {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(AppRadius.small))
                        .background(AppColors.surfacePrimary)
                        .border(BorderStroke(0.5.dp, AppColors.borderSubtle), RoundedCornerShape(AppRadius.small))
                        .clickable { showGroupByDropdown = true }
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(
                        groupBy,
                        style = AppTypography.subheadline.copy(fontWeight = FontWeight.Medium),
                        color = AppColors.textPrimary
                    )
                    Icon(
                        Icons.Default.ArrowDropDown,
                        contentDescription = "Select Group By",
                        tint = AppColors.textSecondary,
                        modifier = Modifier.size(18.dp)
                    )
                }

                DropdownMenu(
                    expanded = showGroupByDropdown,
                    onDismissRequest = { showGroupByDropdown = false }
                ) {
                    listOf("Status", "Priority", "Assignee").forEach { option ->
                        DropdownMenuItem(
                            text = {
                                Text(
                                    option,
                                    color = if (groupBy == option) AppColors.brandPrimary else AppColors.textPrimary,
                                    fontWeight = if (groupBy == option) FontWeight.Bold else FontWeight.Normal
                                )
                            },
                            onClick = {
                                groupBy = option
                                showGroupByDropdown = false
                            },
                            leadingIcon = {
                                if (groupBy == option) {
                                    Icon(
                                        Icons.Default.Check,
                                        contentDescription = null,
                                        tint = AppColors.brandPrimary,
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            }
                        )
                    }
                }
            }

            Spacer(Modifier.weight(1f))

            if (isMoving) {
                CircularProgressIndicator(
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.dp,
                    color = AppColors.brandPrimary
                )
            }
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .onGloballyPositioned { boardCoordinates = it }
        ) {
            key(groupBy) {
                val rowState = rememberLazyListState()
                LazyRow(
                    state = rowState,
                    contentPadding = PaddingValues(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    modifier = Modifier.fillMaxSize()
                ) {
                    items(columns, key = { it.id }) { column ->
                    val isTargeted = draggingTaskId != null && hoveredColumnKey == column.id
                    val columnTasks = tasks.filter { taskGroupKey(it) == column.id }
                        .sortedBy { it.number("position")?.toDouble() ?: 65536.0 }
                    val isOverWip = column.wipLimit != null && columnTasks.size > column.wipLimit

                    Column(
                        modifier = Modifier
                            .width(280.dp)
                            .fillMaxHeight()
                            .clip(RoundedCornerShape(AppRadius.large))
                            .background(
                                if (isTargeted) AppColors.brandPrimary.copy(alpha = 0.06f)
                                else AppColors.backgroundSecondary
                            )
                            .border(
                                border = if (isOverWip) BorderStroke(2.dp, AppColors.statusError.copy(alpha = 0.8f))
                                else if (isTargeted) BorderStroke(2.dp, AppColors.brandPrimary.copy(alpha = 0.8f))
                                else BorderStroke(0.5.dp, AppColors.borderSubtle),
                                shape = RoundedCornerShape(AppRadius.large)
                            )
                            .onGloballyPositioned { colCoords ->
                                val root = boardCoordinates
                                if (root != null && root.isAttached && colCoords.isAttached) {
                                    val topLeft = root.localPositionOf(colCoords, Offset.Zero)
                                    columnBounds[column.id] = Rect(
                                        topLeft,
                                        Size(colCoords.size.width.toFloat(), colCoords.size.height.toFloat())
                                    )
                                }
                            }
                            .padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        // Header matching iOS BoardColumnView.swift:38-67
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 4.dp, vertical = 2.dp)
                        ) {
                            Text(
                                column.title,
                                style = AppTypography.headline,
                                color = if (isOverWip) AppColors.statusError
                                else if (isTargeted) AppColors.brandPrimary
                                else column.headerColor ?: AppColors.textPrimary,
                                modifier = Modifier.weight(1f, fill = false)
                            )

                            if (column.wipLimit != null) {
                                Spacer(Modifier.width(6.dp))
                                Text(
                                    "WIP: ${column.wipLimit}",
                                    style = AppTypography.caption2.copy(fontWeight = FontWeight.Medium),
                                    color = if (isOverWip) Color.White else AppColors.textSecondary,
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(4.dp))
                                        .background(if (isOverWip) AppColors.statusError else AppColors.surfaceElevated)
                                        .padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }

                            Spacer(Modifier.weight(1f))

                            Text(
                                "${columnTasks.size}",
                                style = AppTypography.caption1.copy(fontWeight = FontWeight.Bold),
                                color = if (isOverWip) Color.White else AppColors.textSecondary,
                                modifier = Modifier
                                    .clip(CircleShape)
                                    .background(if (isOverWip) AppColors.statusError else AppColors.surfaceElevated)
                                    .padding(horizontal = 8.dp, vertical = 3.dp)
                            )
                        }

                        // Cards in Column
                        LazyColumn(
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .weight(1f, fill = false)
                        ) {
                            items(columnTasks, key = { it.id }) { task ->
                                val isBeingDragged = task.id == draggingTaskId
                                var cardCoordinates by remember { mutableStateOf<LayoutCoordinates?>(null) }
                                var showMenu by remember { mutableStateOf(false) }

                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .onGloballyPositioned { cardCoords ->
                                            cardCoordinates = cardCoords
                                            val root = boardCoordinates
                                            if (root != null && root.isAttached && cardCoords.isAttached) {
                                                val topLeft = root.localPositionOf(cardCoords, Offset.Zero)
                                                cardBounds[task.id] = Rect(
                                                    topLeft,
                                                    Size(cardCoords.size.width.toFloat(), cardCoords.size.height.toFloat())
                                                )
                                            }
                                        }
                                        .alpha(if (isBeingDragged) 0.25f else 1f)
                                        .pointerInput(task.id, groupBy) {
                                            detectDragGesturesAfterLongPress(
                                                onDragStart = { localTouchOffset ->
                                                    val root = boardCoordinates
                                                    val coords = cardCoordinates
                                                    if (root != null && coords != null && root.isAttached && coords.isAttached) {
                                                        val posInBoard = root.localPositionOf(coords, Offset.Zero)
                                                        dragCardTopLeft = posInBoard
                                                        dragTouchInBoard = posInBoard + localTouchOffset
                                                        dragCardSize = coords.size
                                                        draggingTaskId = task.id
                                                        draggingTask = task
                                                        hoveredColumnKey = column.id
                                                    }
                                                },
                                                onDrag = { change, dragAmount ->
                                                    change.consume()
                                                    dragCardTopLeft += dragAmount
                                                    dragTouchInBoard += dragAmount
                                                    val hovered = columnBounds.entries.firstOrNull { (_, rect) ->
                                                        dragTouchInBoard.x >= rect.left && dragTouchInBoard.x <= rect.right
                                                    }?.key
                                                    hoveredColumnKey = hovered
                                                },
                                                onDragEnd = {
                                                    val targetColId = hoveredColumnKey
                                                    val currentTask = draggingTask
                                                    val id = draggingTaskId
                                                    if (targetColId != null && currentTask != null && id != null) {
                                                        val curColId = taskGroupKey(currentTask)
                                                        val destItems = tasks.filter { taskGroupKey(it) == targetColId && it.id != id }
                                                            .sortedBy { it.number("position")?.toDouble() ?: 65536.0 }

                                                        // Find drop insertion index based on touch Y position relative to cards in target column
                                                        var targetIndex = destItems.size
                                                        for ((idx, destItem) in destItems.withIndex()) {
                                                            val bounds = cardBounds[destItem.id]
                                                            if (bounds != null && dragTouchInBoard.y < bounds.center.y) {
                                                                targetIndex = idx
                                                                break
                                                            }
                                                        }

                                                        val newPos = calculateNewPosition(destItems, targetIndex)
                                                        val groupType = when (groupBy) {
                                                            "Status" -> "status"
                                                            "Priority" -> "priority"
                                                            "Assignee" -> "assignee"
                                                            else -> "status"
                                                        }
                                                        if (targetColId != curColId || targetIndex != destItems.indexOfFirst { it.id == id }) {
                                                            onMoveTask(id, groupType, targetColId, newPos)
                                                        }
                                                    }
                                                    draggingTaskId = null
                                                    draggingTask = null
                                                    hoveredColumnKey = null
                                                },
                                                onDragCancel = {
                                                    draggingTaskId = null
                                                    draggingTask = null
                                                    hoveredColumnKey = null
                                                }
                                            )
                                        }
                                ) {
                                    IosCard(
                                        modifier = Modifier.fillMaxWidth(),
                                        onClick = {
                                            if (draggingTaskId == null) {
                                                onSelectTask(task.id)
                                            }
                                        }
                                    ) {
                                        KanbanCardContent(
                                            task = task,
                                            memberChoices = memberChoices,
                                            onShowMoveMenu = { showMenu = true }
                                        )
                                    }

                                    DropdownMenu(
                                        expanded = showMenu,
                                        onDismissRequest = { showMenu = false }
                                    ) {
                                        Text(
                                            "Move to...",
                                            style = AppTypography.caption1,
                                            color = AppColors.textSecondary,
                                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                                        )
                                        columns.forEach { targetCol ->
                                            DropdownMenuItem(
                                                text = {
                                                    Text(
                                                        targetCol.title,
                                                        color = if (targetCol.id == column.id) AppColors.brandPrimary else AppColors.textPrimary,
                                                        fontWeight = if (targetCol.id == column.id) FontWeight.Bold else FontWeight.Normal
                                                    )
                                                },
                                                onClick = {
                                                    showMenu = false
                                                    if (targetCol.id != column.id) {
                                                        val destItems = tasks.filter { taskGroupKey(it) == targetCol.id && it.id != task.id }
                                                            .sortedBy { it.number("position")?.toDouble() ?: 65536.0 }
                                                        val newPos = calculateNewPosition(destItems, destItems.size)
                                                        val groupType = when (groupBy) {
                                                            "Status" -> "status"
                                                            "Priority" -> "priority"
                                                            "Assignee" -> "assignee"
                                                            else -> "status"
                                                        }
                                                        onMoveTask(task.id, groupType, targetCol.id, newPos)
                                                    }
                                                },
                                                leadingIcon = {
                                                    if (targetCol.id == column.id) {
                                                        Icon(
                                                            Icons.Default.Check,
                                                            contentDescription = null,
                                                            tint = AppColors.brandPrimary,
                                                            modifier = Modifier.size(16.dp)
                                                        )
                                                    }
                                                }
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

            // Floating Card during Drag
            if (draggingTaskId != null && draggingTask != null && dragCardSize != IntSize.Zero) {
                val cardWidthDp = with(density) { dragCardSize.width.toDp() }
                Box(
                    modifier = Modifier
                        .offset { IntOffset(dragCardTopLeft.x.roundToInt(), dragCardTopLeft.y.roundToInt()) }
                        .width(cardWidthDp)
                        .zIndex(100f)
                        .graphicsLayer {
                            scaleX = 1.05f
                            scaleY = 1.05f
                            rotationZ = -1.5f
                            alpha = 0.95f
                        }
                        .shadow(16.dp, RoundedCornerShape(AppRadius.medium))
                ) {
                    IosCard(
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        KanbanCardContent(
                            task = draggingTask!!,
                            memberChoices = memberChoices,
                            onShowMoveMenu = {}
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun KanbanCardContent(
    task: JsonObject,
    memberChoices: List<Choice>,
    onShowMoveMenu: () -> Unit
) {
    val priority = task.text("priority")
    val priorityColor = when (priority) {
        "critical" -> AppColors.statusError
        "high" -> AppColors.statusWarning
        else -> AppColors.brandPrimary
    }
    val assigneeId = task.text("assignee_id")
    val assigneeName = memberChoices.firstOrNull { it.value == assigneeId }?.label.orEmpty()

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Default.DragIndicator,
                contentDescription = "Drag to move",
                tint = AppColors.textTertiary,
                modifier = Modifier.size(16.dp)
            )
            Spacer(Modifier.width(4.dp))
            Text(
                task.text("title"),
                style = AppTypography.headline,
                color = AppColors.textPrimary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f)
            )
            Icon(
                taskTypeIcon(task.text("task_type")),
                contentDescription = null,
                tint = taskTypeColor(task.text("task_type")),
                modifier = Modifier.size(16.dp)
            )
            IconButton(
                onClick = onShowMoveMenu,
                modifier = Modifier.size(24.dp)
            ) {
                Icon(
                    Icons.Default.MoreVert,
                    contentDescription = "Task options",
                    tint = AppColors.textTertiary,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
        if (task.text("description").isNotBlank()) {
            Text(
                task.text("description"),
                style = AppTypography.caption1,
                color = AppColors.textSecondary,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                label(priority),
                style = AppTypography.caption2.copy(fontWeight = FontWeight.Medium),
                color = priorityColor
            )
            if (assigneeName.isNotBlank()) {
                val initials = assigneeName.split(" ").mapNotNull { it.firstOrNull()?.uppercase() }.take(2).joinToString("")
                Box(
                    modifier = Modifier
                        .size(18.dp)
                        .clip(CircleShape)
                        .background(AppColors.brandPrimary.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(initials, style = AppTypography.caption2, color = AppColors.brandPrimary)
                }
            }
            Spacer(Modifier.weight(1f))
            if (task.text("due_date").isNotBlank()) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(
                        Icons.Default.CalendarToday,
                        contentDescription = null,
                        tint = AppColors.textTertiary,
                        modifier = Modifier.size(12.dp)
                    )
                    Text(
                        dateLabel(task.text("due_date")),
                        style = AppTypography.caption2,
                        color = AppColors.textSecondary
                    )
                }
            }
        }
    }
}

@Composable
private fun TaskRowContent(task: JsonObject, members: List<Choice>) {
    val priority = task.text("priority")
    val priorityColor = when (priority) {
        "critical" -> AppColors.statusError
        "high" -> AppColors.statusWarning
        else -> AppColors.brandPrimary
    }
    Row(verticalAlignment = Alignment.Top) {
        Icon(
            imageVector = Icons.Default.RadioButtonUnchecked,
            contentDescription = null,
            tint = AppColors.borderDefault,
            modifier = Modifier.size(20.dp).padding(top = 2.dp)
        )
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    taskTypeIcon(task.text("task_type")),
                    null,
                    tint = taskTypeColor(task.text("task_type")),
                    modifier = Modifier.size(16.dp)
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    task.text("title"),
                    style = AppTypography.headline,
                    color = AppColors.textPrimary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
            if (task.text("description").isNotBlank()) {
                Text(
                    task.text("description"),
                    style = AppTypography.subheadline,
                    color = AppColors.textSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(top = 4.dp)
            ) {
                IosPill(label(task.text("status")))
                Text(
                    label(priority),
                    style = AppTypography.caption1.copy(fontWeight = FontWeight.Medium),
                    color = priorityColor
                )
                Spacer(Modifier.weight(1f))
                Text(
                    dateLabel(task.text("due_date")).ifBlank { "No due date" },
                    style = AppTypography.caption2,
                    color = AppColors.textTertiary
                )
            }
        }
    }
}

@Composable
private fun taskTypeIcon(type: String) = when (type) {
    "bug" -> Icons.Default.BugReport
    "story" -> Icons.Default.Bookmark
    "epic" -> Icons.Default.Star
    "subtask" -> Icons.Default.SubdirectoryArrowRight
    else -> Icons.Default.CheckCircle
}

@Composable
private fun taskTypeColor(type: String) = when (type) {
    "bug" -> AppColors.statusError
    "story" -> AppColors.statusSuccess
    "epic" -> Color(0xFFAF52DE)
    "subtask" -> AppColors.textSecondary
    else -> Color(0xFF007AFF)
}

@Composable
private fun TaskCalendar(tasks: List<JsonObject>, onSelect: (String) -> Unit) {
    var monthText by rememberSaveable { mutableStateOf(YearMonth.now().toString()) }
    var selectedText by rememberSaveable { mutableStateOf(LocalDate.now().toString()) }
    val month = YearMonth.parse(monthText)
    val selected = LocalDate.parse(selectedText)
    fun due(task: JsonObject): LocalDate? = runCatching {
        Instant.parse(task.text("due_date")).atZone(ZoneId.systemDefault()).toLocalDate()
    }.getOrNull()

    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { monthText = month.minusMonths(1).toString() }) {
                    Icon(Icons.Default.ChevronLeft, "Previous month", tint = AppColors.brandPrimary)
                }
                Text(
                    month.toString(),
                    modifier = Modifier.weight(1f),
                    style = AppTypography.headline,
                    color = AppColors.textPrimary
                )
                IconButton(onClick = { monthText = month.plusMonths(1).toString() }) {
                    Icon(Icons.Default.ChevronRight, "Next month", tint = AppColors.brandPrimary)
                }
            }
            Row {
                listOf("M", "T", "W", "T", "F", "S", "S").forEach {
                    Text(
                        it,
                        Modifier.weight(1f).padding(8.dp),
                        style = AppTypography.caption1,
                        color = AppColors.textTertiary,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                }
            }
            val start = month.atDay(1).dayOfWeek.value - 1
            repeat((start + month.lengthOfMonth() + 6) / 7) { week ->
                Row {
                    repeat(7) { day ->
                        val number = week * 7 + day - start + 1
                        Box(Modifier.weight(1f).height(48.dp), contentAlignment = Alignment.Center) {
                            if (number in 1..month.lengthOfMonth()) {
                                val date = month.atDay(number)
                                val isSelected = date == selected
                                Box(
                                    modifier = Modifier
                                        .size(36.dp)
                                        .clip(CircleShape)
                                        .background(if (isSelected) AppColors.brandPrimary else Color.Transparent)
                                        .clickable { selectedText = date.toString() },
                                    contentAlignment = Alignment.Center
                                ) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text(
                                            number.toString(),
                                            style = AppTypography.body,
                                            color = if (isSelected) Color.White else AppColors.textPrimary
                                        )
                                        if (tasks.any { due(it) == date }) {
                                            Box(
                                                Modifier
                                                    .size(4.dp)
                                                    .clip(CircleShape)
                                                    .background(if (isSelected) Color.White else AppColors.brandPrimary)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle, modifier = Modifier.padding(top = 8.dp))
        }
        items(tasks.filter { due(it) == selected }, key = { it.id }) { task ->
            IosCard(modifier = Modifier.fillMaxWidth(), onClick = { onSelect(task.id) }) {
                TaskRowContent(task, emptyList())
            }
        }
    }
}

private fun parseDateLocalDate(raw: String): LocalDate? = runCatching {
    if (raw.isBlank()) null
    else if (raw.length >= 10) LocalDate.parse(raw.substring(0, 10))
    else null
}.getOrNull()

// MARK: - Interactive Roadmap / Timeline Gantt View (matching TimelineView.swift)
@Composable
fun TimelineGanttView(
    tasks: List<JsonObject>,
    onSelectTask: (String) -> Unit
) {
    val verticalScrollState = rememberLazyListState()
    val horizontalScrollState = rememberScrollState()

    val now = remember { LocalDate.now() }
    val sortedTasks = remember(tasks) {
        tasks.sortedBy { it.text("start_date", it.text("due_date", "9999")) }
    }

    val baseDate = remember(tasks) {
        val parsedDates = tasks.mapNotNull { parseDateLocalDate(it.text("start_date")) ?: parseDateLocalDate(it.text("due_date")) }
        if (parsedDates.isNotEmpty()) {
            val minDate = parsedDates.minOrNull() ?: now.minusDays(3)
            if (minDate.isBefore(now.minusDays(14))) minDate else now.minusDays(3)
        } else {
            now.minusDays(3)
        }
    }

    val totalDays = 21
    val days = remember(baseDate) {
        (0 until totalDays).map { baseDate.plusDays(it.toLong()) }
    }

    val dayWidth = 68.dp
    val rowHeight = 48.dp

    Row(
        Modifier
            .fillMaxSize()
            .background(AppColors.backgroundPrimary)
    ) {
        // Sticky Left Column: Task Labels
        Column(
            Modifier
                .width(140.dp)
                .fillMaxHeight()
                .background(AppColors.surfacePrimary)
        ) {
            Box(
                modifier = Modifier
                    .height(56.dp)
                    .fillMaxWidth()
                    .background(AppColors.surfaceElevated)
                    .padding(horizontal = 12.dp),
                contentAlignment = Alignment.CenterStart
            ) {
                Text(
                    text = "Tasks",
                    style = AppTypography.headline,
                    color = AppColors.textPrimary
                )
            }
            HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

            LazyColumn(
                modifier = Modifier.weight(1f),
                state = verticalScrollState
            ) {
                items(sortedTasks, key = { it.id }) { task ->
                    Box(
                        modifier = Modifier
                            .height(rowHeight)
                            .fillMaxWidth()
                            .clickable { onSelectTask(task.id) }
                            .padding(horizontal = 10.dp),
                        contentAlignment = Alignment.CenterStart
                    ) {
                        Column(verticalArrangement = Arrangement.Center) {
                            val key = task.text("issue_key").ifBlank { task.text("key") }
                            if (key.isNotBlank()) {
                                Text(
                                    text = key,
                                    style = AppTypography.caption2,
                                    color = AppColors.brandPrimary,
                                    maxLines = 1
                                )
                            }
                            Text(
                                text = task.text("title"),
                                style = AppTypography.caption1,
                                color = AppColors.textPrimary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                    HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                }
            }
        }

        VerticalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

        // Right Area: Scrollable Calendar Header + Grid + Duration Bars
        Column(
            Modifier
                .weight(1f)
                .fillMaxHeight()
                .horizontalScroll(horizontalScrollState)
        ) {
            Row(
                Modifier
                    .height(56.dp)
                    .background(AppColors.surfaceElevated)
            ) {
                days.forEach { day ->
                    val isToday = day == now
                    Column(
                        modifier = Modifier
                            .width(dayWidth)
                            .fillMaxHeight()
                            .border(0.5.dp, AppColors.borderSubtle.copy(alpha = 0.3f)),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Text(
                            text = day.month.name.take(3),
                            style = AppTypography.caption2,
                            color = if (isToday) AppColors.brandPrimary else AppColors.textSecondary
                        )
                        Text(
                            text = "${day.dayOfMonth}",
                            style = AppTypography.headline,
                            fontWeight = if (isToday) FontWeight.Bold else FontWeight.SemiBold,
                            color = if (isToday) AppColors.brandPrimary else AppColors.textPrimary
                        )
                        Text(
                            text = day.dayOfWeek.name.take(3),
                            style = AppTypography.caption2,
                            color = if (isToday) AppColors.brandPrimary else AppColors.textTertiary
                        )
                    }
                }
            }

            HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)

            LazyColumn(
                modifier = Modifier.weight(1f),
                state = verticalScrollState
            ) {
                items(sortedTasks, key = { it.id }) { task ->
                    Box(
                        modifier = Modifier
                            .height(rowHeight)
                            .width(dayWidth * days.size)
                    ) {
                        Row(Modifier.fillMaxSize()) {
                            days.forEach { day ->
                                val isToday = day == now
                                Box(
                                    Modifier
                                        .width(dayWidth)
                                        .fillMaxHeight()
                                        .background(if (isToday) AppColors.brandPrimary.copy(alpha = 0.06f) else Color.Transparent)
                                        .border(0.5.dp, AppColors.borderSubtle.copy(alpha = 0.15f))
                                )
                            }
                        }

                        val taskStart = parseDateLocalDate(task.text("start_date"))
                        val taskDue = parseDateLocalDate(task.text("due_date"))

                        val effectiveStart = taskStart ?: taskDue ?: baseDate
                        val effectiveDue = taskDue ?: taskStart ?: effectiveStart

                        val startOffsetDays = ChronoUnit.DAYS.between(baseDate, effectiveStart).toInt()
                        val durationDays = ChronoUnit.DAYS.between(effectiveStart, effectiveDue).toInt() + 1

                        val barOffset = (startOffsetDays.coerceAtLeast(0) * 68).dp + 4.dp
                        val barWidth = (durationDays.coerceAtLeast(1) * 68).dp - 8.dp

                        val statusColor = when (task.text("status").lowercase()) {
                            "done", "closed" -> AppColors.statusSuccess
                            "in_progress", "in-progress" -> AppColors.brandPrimary
                            "blocked", "cancelled" -> AppColors.statusError
                            else -> AppColors.textSecondary
                        }

                        Box(
                            modifier = Modifier
                                .padding(vertical = 10.dp)
                                .offset(x = barOffset)
                                .width(barWidth)
                                .fillMaxHeight()
                                .clip(RoundedCornerShape(AppRadius.small))
                                .background(statusColor.copy(alpha = 0.18f))
                                .border(1.dp, statusColor, RoundedCornerShape(AppRadius.small))
                                .clickable { onSelectTask(task.id) }
                                .padding(horizontal = 8.dp),
                            contentAlignment = Alignment.CenterStart
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                Box(
                                    Modifier
                                        .size(6.dp)
                                        .clip(CircleShape)
                                        .background(statusColor)
                                )
                                Text(
                                    text = task.text("title"),
                                    style = AppTypography.caption1,
                                    color = statusColor,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                        }
                    }
                    HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle.copy(alpha = 0.5f))
                }
            }
        }
    }
}

// MARK: - Epic Detail Dashboard Modal (matching EpicDetailDashboardView.swift)
@Composable
fun EpicDetailDashboardModal(
    epicId: String,
    api: ApiClient,
    vm: AppViewModel,
    onSelectTask: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val epicRemote = rememberRemote(api, "/api/tasks/$epicId", vm.revision)
    val subtasksRemote = rememberRemote(api, "/api/tasks/$epicId/subtasks", vm.revision)
    val epic = epicRemote.data.obj()
    val childTasks = subtasksRemote.data.rows()

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxHeight(0.85f)
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
                    Column(Modifier.weight(1f)) {
                        val key = epic.text("issue_key")
                        Text(
                            text = if (key.isNotBlank()) "Epic Dashboard • $key" else "Epic Dashboard",
                            style = AppTypography.caption1,
                            color = AppColors.brandPrimary
                        )
                        Text(
                            text = epic.text("title"),
                            style = AppTypography.headline,
                            color = AppColors.textPrimary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textSecondary)
                    }
                }

                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle, modifier = Modifier.padding(vertical = 8.dp))

                if (epicRemote.loading && epic.id.isBlank()) {
                    Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = AppColors.brandPrimary)
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        // Section: Progress Rollup
                        item {
                            Card(
                                shape = RoundedCornerShape(AppRadius.medium),
                                colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(
                                    modifier = Modifier.padding(14.dp),
                                    verticalArrangement = Arrangement.spacedBy(12.dp)
                                ) {
                                    Text(
                                        text = "Progress",
                                        style = AppTypography.headline,
                                        color = AppColors.textPrimary
                                    )

                                    // Points Rollup
                                    val donePoints = epic.number("epic_completed_points").toInt().let {
                                        if (it > 0) it
                                        else childTasks.filter { c -> c.text("status").lowercase() in listOf("done", "closed") }.sumOf { c -> c.number("story_points").toInt() }
                                    }
                                    val totalPoints = epic.number("epic_total_points").toInt().let {
                                        if (it > 0) it
                                        else childTasks.sumOf { c -> c.number("story_points").toInt() }
                                    }
                                    val pointsProgress = if (totalPoints > 0) (donePoints.toFloat() / totalPoints).coerceIn(0f, 1f) else 0f

                                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Text("Points", style = AppTypography.subheadline, color = AppColors.textPrimary)
                                            Text(if (totalPoints > 0) "$donePoints / $totalPoints" else "—", style = AppTypography.caption1, color = AppColors.textSecondary)
                                        }
                                        LinearProgressIndicator(
                                            progress = { pointsProgress },
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .height(8.dp)
                                                .clip(RoundedCornerShape(4.dp)),
                                            color = AppColors.brandPrimary,
                                            trackColor = AppColors.borderSubtle
                                        )
                                    }

                                    // Issues Rollup
                                    val doneIssues = epic.number("epic_children_done_count").toInt().let {
                                        if (it > 0) it
                                        else childTasks.count { c -> c.text("status").lowercase() in listOf("done", "closed") }
                                    }
                                    val totalIssues = epic.number("epic_children_count").toInt().let {
                                        if (it > 0) it
                                        else childTasks.size
                                    }
                                    val issuesProgress = if (totalIssues > 0) (doneIssues.toFloat() / totalIssues).coerceIn(0f, 1f) else 0f

                                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                        Row(
                                            modifier = Modifier.fillMaxWidth(),
                                            horizontalArrangement = Arrangement.SpaceBetween
                                        ) {
                                            Text("Issues", style = AppTypography.subheadline, color = AppColors.textPrimary)
                                            Text(if (totalIssues > 0) "$doneIssues / $totalIssues" else "—", style = AppTypography.caption1, color = AppColors.textSecondary)
                                        }
                                        LinearProgressIndicator(
                                            progress = { issuesProgress },
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .height(8.dp)
                                                .clip(RoundedCornerShape(4.dp)),
                                            color = AppColors.statusSuccess,
                                            trackColor = AppColors.borderSubtle
                                        )
                                    }
                                }
                            }
                        }

                        // Section: Child Issues
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "Child Issues",
                                    style = AppTypography.headline,
                                    color = AppColors.textPrimary
                                )
                                Text(
                                    text = "${childTasks.size} issues",
                                    style = AppTypography.caption1,
                                    color = AppColors.textSecondary
                                )
                            }
                        }

                        if (childTasks.isEmpty()) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(24.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        text = "No child issues yet.",
                                        style = AppTypography.body,
                                        color = AppColors.textSecondary
                                    )
                                }
                            }
                        } else {
                            items(childTasks, key = { it.id }) { child ->
                                Card(
                                    shape = RoundedCornerShape(AppRadius.medium),
                                    colors = CardDefaults.cardColors(containerColor = AppColors.surfaceElevated),
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { onSelectTask(child.id) }
                                ) {
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(12.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Column(Modifier.weight(1f)) {
                                            val key = child.text("issue_key")
                                            if (key.isNotBlank()) {
                                                Text(
                                                    text = key,
                                                    style = AppTypography.caption2,
                                                    color = AppColors.brandPrimary
                                                )
                                            }
                                            Text(
                                                text = child.text("title"),
                                                style = AppTypography.subheadline,
                                                color = AppColors.textPrimary,
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis
                                            )
                                            Text(
                                                text = label(child.text("status").ifBlank { "todo" }),
                                                style = AppTypography.caption2,
                                                color = AppColors.textSecondary
                                            )
                                        }

                                        val sp = child.number("story_points").toInt()
                                        if (sp > 0) {
                                            Surface(
                                                shape = RoundedCornerShape(AppRadius.small),
                                                color = AppColors.brandPrimary.copy(alpha = 0.12f),
                                                modifier = Modifier.padding(start = 8.dp)
                                            ) {
                                                Text(
                                                    text = "$sp pts",
                                                    style = AppTypography.caption2,
                                                    color = AppColors.brandPrimary,
                                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                                )
                                            }
                                        }
                                        Icon(
                                            Icons.Default.ChevronRight,
                                            contentDescription = null,
                                            tint = AppColors.textTertiary,
                                            modifier = Modifier.size(18.dp).padding(start = 4.dp)
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

private fun taskFields(task: JsonObject?, lists: List<Choice>, members: List<Choice>, listId: String = ""): List<FormField> = listOf(
    FormField("title", "Title", task?.text("title").orEmpty(), required = true),
    FormField("description", "Description", task?.text("description").orEmpty(), multiline = true, emitEmpty = true),
    FormField("list_id", "List", task?.text("list_id") ?: listId.ifBlank { lists.firstOrNull()?.value.orEmpty() }, required = true, options = lists),
    FormField("priority", "Priority", task?.text("priority") ?: "medium", options = priorities),
    FormField("task_type", "Type", task?.text("task_type") ?: "task", options = types),
    FormField("assignee_id", "Assignee", task?.text("assignee_id").orEmpty(), options = listOf(Choice("", "Unassigned")) + members),
    FormField("story_points", "Story points", task?.text("story_points").orEmpty(), numeric = true),
    FormField("start_date", "Start", task?.text("start_date").orEmpty(), date = true),
    FormField("due_date", "Due", task?.text("due_date").orEmpty(), date = true)
)

// MARK: - Task Details Screen (Exact 1:1 match to screenshot.png)
@Composable
private fun TaskDetailScreen(
    vm: AppViewModel,
    api: ApiClient,
    taskId: String,
    lists: List<Choice>,
    members: List<Choice>,
    onBack: () -> Unit
) {
    BackHandler(onBack = onBack)
    val remote = rememberRemote(api, "/api/tasks/$taskId", vm.revision)
    val task = remote.data.obj()

    var editTitle by remember(task.text("title")) { mutableStateOf(task.text("title")) }
    var editDescription by remember(task.text("description")) { mutableStateOf(task.text("description")) }
    var editStatus by remember(task.text("status")) { mutableStateOf(task.text("status").ifBlank { "todo" }) }
    var editPriority by remember(task.text("priority")) { mutableStateOf(task.text("priority").ifBlank { "medium" }) }

    var tab by rememberSaveable { mutableStateOf("Activity") }
    var comment by rememberSaveable(taskId) { mutableStateOf("") }
    var previewComment by rememberSaveable(taskId) { mutableStateOf(false) }
    var editor by remember { mutableStateOf<String?>(null) }
    var delete by remember { mutableStateOf(false) }
    var alertError by remember { mutableStateOf<String?>(null) }
    var showEpicDashboard by remember { mutableStateOf(false) }
    var selectedParentEpicId by remember { mutableStateOf<String?>(null) }
    val isEpicTask = task.text("task_type").lowercase() == "epic" || task.text("type").lowercase() == "epic"

    val action = rememberAction()

    // Watch for action errors and trigger iOS alert dialog
    LaunchedEffect(action.error) {
        if (action.error != null) {
            alertError = action.error
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .background(AppColors.backgroundPrimary)
    ) {
        // Navigation bar matching screenshot.png: `< Tasks` on left, `Save` on right
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .padding(horizontal = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier
                    .clickable(onClick = onBack)
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
                    text = "Tasks",
                    style = AppTypography.body,
                    color = AppColors.brandPrimary
                )
            }

            Spacer(Modifier.weight(1f))

            if (isEpicTask) {
                TextButton(onClick = { showEpicDashboard = true }) {
                    Text(
                        text = "Epic Dashboard",
                        style = AppTypography.headline,
                        color = AppColors.brandPrimary
                    )
                }
            }

            TextButton(
                enabled = task.id.isNotEmpty() && !action.busy,
                onClick = {
                    action.run {
                        val payload = json(
                            "title" to editTitle.trim(),
                            "description" to editDescription.trim(),
                            "status" to editStatus,
                            "priority" to editPriority,
                            "expected_version" to task.number("version")
                        )
                        api.request("/api/tasks/$taskId", "PATCH", payload, version = task.number("version"))
                        vm.changed()
                    }
                }
            ) {
                Text(
                    text = "Save",
                    style = AppTypography.headline,
                    color = if (!action.busy && task.id.isNotEmpty()) AppColors.brandPrimary else AppColors.textTertiary
                )
            }
        }

        RemoteStatus(remote)

        if (task.id.isNotBlank()) {
            val projectId = task.text("project_id")
            val workflow = if (projectId.isNotEmpty()) rememberRemote(api, "/api/projects/$projectId/workflow", vm.revision) else null

            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Large title "Task Details" (exact match to screenshot.png)
                item {
                    Text(
                        text = "Task Details",
                        style = AppTypography.largeTitle,
                        color = AppColors.textPrimary
                    )
                }

                // Inset rounded box for Title (exact match to screenshot.png)
                item {
                    IosTextField(
                        label = "Title",
                        value = editTitle,
                        onValueChange = { editTitle = it },
                        singleLine = true
                    )
                }

                // Side-by-side dropdown selectors for Status & Priority (exact match to screenshot.png)
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(24.dp)
                    ) {
                        IosDropdownSelector(
                            label = "Status",
                            value = editStatus,
                            options = statuses,
                            onSelect = { editStatus = it },
                            modifier = Modifier.weight(1f)
                        )
                        IosDropdownSelector(
                            label = "Priority",
                            value = editPriority,
                            options = priorities,
                            onSelect = { editPriority = it },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }

                // Parent Epic pill if linked to an epic
                val parentEpicId = task.text("epic_id").ifBlank { task.text("parent_id") }
                if (!isEpicTask && parentEpicId.isNotBlank() && task.text("task_type") != "subtask") {
                    item {
                        Row(
                            modifier = Modifier
                                .clip(RoundedCornerShape(AppRadius.medium))
                                .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                                .clickable { selectedParentEpicId = parentEpicId }
                                .padding(horizontal = 12.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            Icon(Icons.Default.Dashboard, contentDescription = null, tint = AppColors.brandPrimary, modifier = Modifier.size(16.dp))
                            Text("View Parent Epic", style = AppTypography.caption1, color = AppColors.brandPrimary, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }

                // Hairline divider (exact match to screenshot.png)
                item {
                    HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                }

                // Section "Description" (exact match to screenshot.png)
                item {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = "Description",
                            style = AppTypography.headline,
                            color = AppColors.textPrimary
                        )
                        IosTextField(
                            label = "Description",
                            value = editDescription,
                            onValueChange = { editDescription = it },
                            singleLine = false,
                            minLines = 4,
                            placeholder = "Enter task description..."
                        )
                    }
                }

                // Sections / Tabs (Activity, Checklist, Subtasks, Dependencies, Time logs)
                item {
                    Row(
                        Modifier.horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        listOf("Activity", "Checklist", "Subtasks", "Dependencies", "Time logs").forEach { name ->
                            IosFilterChip(
                                title = name,
                                isSelected = tab == name,
                                onClick = { tab = name }
                            )
                        }
                    }
                }

                item {
                    val endpoint = when (tab) {
                        "Checklist" -> "checklist"
                        "Subtasks" -> "subtasks"
                        "Dependencies" -> "relations"
                        "Time logs" -> "time-logs"
                        else -> "activity"
                    }
                    val section = rememberRemote(api, "/api/tasks/$taskId/$endpoint", vm.revision)
                    val items = section.data.rows()

                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(tab, Modifier.weight(1f), style = AppTypography.headline)
                            IconButton(onClick = { editor = tab }) {
                                Icon(Icons.Default.Add, "Add to $tab", tint = AppColors.brandPrimary)
                            }
                        }

                        // Checklist completion progress bar
                        if (tab == "Checklist" && items.isNotEmpty()) {
                            val completed = items.count { it.flag("is_completed") }
                            val total = items.size
                            val progress = if (total > 0) completed.toFloat() / total else 0f
                            val percent = (progress * 100).roundToInt()
                            IosCard(modifier = Modifier.fillMaxWidth()) {
                                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(
                                            Icons.Default.CheckCircle,
                                            null,
                                            tint = if (completed == total) AppColors.statusSuccess else AppColors.brandPrimary,
                                            modifier = Modifier.size(16.dp)
                                        )
                                        Spacer(Modifier.width(6.dp))
                                        Text(
                                            text = "$completed of $total completed ($percent%)",
                                            style = AppTypography.caption1.copy(fontWeight = FontWeight.SemiBold),
                                            color = AppColors.textPrimary
                                        )
                                    }
                                    LinearProgressIndicator(
                                        progress = { progress },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(6.dp)
                                            .clip(RoundedCornerShape(3.dp)),
                                        color = if (completed == total) AppColors.statusSuccess else AppColors.brandPrimary,
                                        trackColor = AppColors.borderSubtle
                                    )
                                }
                            }
                        }

                        // Subtasks completion progress bar
                        if (tab == "Subtasks" && items.isNotEmpty()) {
                            val completed = items.count { it.text("status") in listOf("done", "cancelled", "completed") }
                            val total = items.size
                            val progress = if (total > 0) completed.toFloat() / total else 0f
                            val percent = (progress * 100).roundToInt()
                            IosCard(modifier = Modifier.fillMaxWidth()) {
                                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(
                                            Icons.Default.CheckCircle,
                                            null,
                                            tint = if (completed == total) AppColors.statusSuccess else AppColors.brandPrimary,
                                            modifier = Modifier.size(16.dp)
                                        )
                                        Spacer(Modifier.width(6.dp))
                                        Text(
                                            text = "$completed of $total subtasks completed ($percent%)",
                                            style = AppTypography.caption1.copy(fontWeight = FontWeight.SemiBold),
                                            color = AppColors.textPrimary
                                        )
                                    }
                                    LinearProgressIndicator(
                                        progress = { progress },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(6.dp)
                                            .clip(RoundedCornerShape(3.dp)),
                                        color = if (completed == total) AppColors.statusSuccess else AppColors.brandPrimary,
                                        trackColor = AppColors.borderSubtle
                                    )
                                }
                            }
                        }

                        RemoteStatus(section)

                        if (items.isEmpty()) {
                            val emptyMsg = when (tab) {
                                "Checklist" -> "No checklist items yet."
                                "Subtasks" -> "No subtasks yet."
                                "Dependencies" -> "No dependencies yet. Link tasks that block or relate to this one."
                                "Time logs" -> "No time logged yet."
                                else -> "No activity yet."
                            }
                            Text(emptyMsg, style = AppTypography.body, color = AppColors.textSecondary)
                        } else {
                            items.forEach { item ->
                                when (tab) {
                                    "Checklist" -> {
                                        val isDone = item.flag("is_completed")
                                        IosCard(modifier = Modifier.fillMaxWidth()) {
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Checkbox(
                                                    checked = isDone,
                                                    enabled = !action.busy,
                                                    onCheckedChange = { checked ->
                                                        action.run {
                                                            api.request("/api/tasks/$taskId/checklist/${item.id}", "PATCH", json("is_completed" to checked))
                                                            vm.changed()
                                                        }
                                                    }
                                                )
                                                Text(
                                                    text = item.text("title"),
                                                    modifier = Modifier.weight(1f),
                                                    style = if (isDone) AppTypography.body.copy(textDecoration = TextDecoration.LineThrough, color = AppColors.textTertiary) else AppTypography.body
                                                )
                                                IconButton(onClick = {
                                                    action.run {
                                                        api.request("/api/tasks/$taskId/checklist/${item.id}", "DELETE")
                                                        vm.changed()
                                                    }
                                                }) {
                                                    Icon(Icons.Default.Delete, "Delete", tint = AppColors.statusError, modifier = Modifier.size(18.dp))
                                                }
                                            }
                                        }
                                    }
                                    "Subtasks" -> {
                                        val isDone = item.text("status") in listOf("done", "cancelled", "completed")
                                        IosCard(modifier = Modifier.fillMaxWidth()) {
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Checkbox(
                                                    checked = isDone,
                                                    enabled = !action.busy,
                                                    onCheckedChange = { checked ->
                                                        action.run {
                                                            val newStatus = if (checked) "done" else "todo"
                                                            api.request("/api/tasks/${item.id}", "PATCH", json("status" to newStatus))
                                                            vm.changed()
                                                        }
                                                    }
                                                )
                                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                                        val issueKey = item.text("issue_key")
                                                        if (issueKey.isNotBlank()) {
                                                            Text(issueKey, style = AppTypography.caption2, color = AppColors.brandPrimary)
                                                        }
                                                        Text(
                                                            text = item.text("title"),
                                                            style = if (isDone) AppTypography.body.copy(textDecoration = TextDecoration.LineThrough, color = AppColors.textTertiary) else AppTypography.body
                                                        )
                                                    }
                                                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                                                        val pr = item.text("priority")
                                                        if (pr.isNotBlank()) {
                                                            IosPill(label(pr))
                                                        }
                                                        val assigneeName = members.firstOrNull { it.value == item.text("assignee_id") }?.label
                                                        if (assigneeName != null) {
                                                            Text(assigneeName, style = AppTypography.caption2, color = AppColors.textSecondary)
                                                        }
                                                    }
                                                }
                                                IconButton(onClick = {
                                                    action.run {
                                                        api.request("/api/tasks/${item.id}", "DELETE")
                                                        vm.changed()
                                                    }
                                                }) {
                                                    Icon(Icons.Default.Delete, "Delete", tint = AppColors.statusError, modifier = Modifier.size(18.dp))
                                                }
                                            }
                                        }
                                    }
                                    "Dependencies" -> {
                                        val rawType = item.text("relation_type", item.text("relationType", item.text("type")))
                                        val (typeLabel, typeColor, typeIcon) = when (rawType.lowercase()) {
                                            "blocked_by", "blockedby" -> Triple("Blocked by", AppColors.statusError, Icons.Default.Lock)
                                            "blocks" -> Triple("Blocks", AppColors.brandPrimary, Icons.AutoMirrored.Filled.ArrowForward)
                                            "duplicate_of", "duplicateof" -> Triple("Duplicate of", AppColors.textSecondary, Icons.Default.ContentCopy)
                                            else -> Triple("Relates to", Color(0xFF007AFF), Icons.Default.Link)
                                        }
                                        val relatedTitle = item.text("related_task_title", item.text("relatedTaskId", item.text("related_task_id", "Task")))
                                        IosCard(modifier = Modifier.fillMaxWidth()) {
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Box(
                                                    modifier = Modifier
                                                        .clip(RoundedCornerShape(AppRadius.small))
                                                        .background(typeColor.copy(alpha = 0.12f))
                                                        .padding(horizontal = 8.dp, vertical = 4.dp)
                                                ) {
                                                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                                        Icon(typeIcon, null, tint = typeColor, modifier = Modifier.size(14.dp))
                                                        Text(typeLabel, style = AppTypography.caption2.copy(fontWeight = FontWeight.Bold), color = typeColor)
                                                    }
                                                }
                                                Spacer(Modifier.width(10.dp))
                                                Text(relatedTitle, Modifier.weight(1f), style = AppTypography.body)
                                                IconButton(onClick = {
                                                    action.run {
                                                        api.request("/api/tasks/$taskId/relations/${item.id}", "DELETE")
                                                        vm.changed()
                                                    }
                                                }) {
                                                    Icon(Icons.Default.Delete, "Delete", tint = AppColors.statusError, modifier = Modifier.size(18.dp))
                                                }
                                            }
                                        }
                                    }
                                    "Time logs" -> IosCard(modifier = Modifier.fillMaxWidth()) {
                                        Text("${item.text("hours_logged")} hours • ${item.text("user_display_name")}", style = AppTypography.headline)
                                        Text("${item.text("description")}\n${dateLabel(item.text("logged_at"))}", style = AppTypography.caption1, color = AppColors.textSecondary)
                                    }
                                    else -> {
                                        val actType = item.text("type")
                                        val isComment = actType == "comment"
                                        val userName = item.text("user_name", item.text("user_display_name", "User ${item.text("user_id").take(4)}"))
                                        val (iconVector, iconTint) = when (actType) {
                                            "comment" -> Icons.Default.ChatBubble to AppColors.brandPrimary
                                            "status_changed", "status" -> Icons.Default.Autorenew to Color(0xFF007AFF)
                                            "assignee_changed", "assignee" -> Icons.Default.Person to Color(0xFF34C759)
                                            "priority_changed", "priority" -> Icons.Default.Flag to Color(0xFFFF9500)
                                            "moved", "reordered" -> Icons.Default.SwapHoriz to AppColors.brandPrimary
                                            else -> Icons.Default.Sync to AppColors.textTertiary
                                        }
                                        IosCard(modifier = Modifier.fillMaxWidth()) {
                                            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
                                                Box(
                                                    modifier = Modifier
                                                        .size(32.dp)
                                                        .clip(CircleShape)
                                                        .background(iconTint.copy(alpha = 0.12f)),
                                                    contentAlignment = Alignment.Center
                                                ) {
                                                    Icon(iconVector, null, tint = iconTint, modifier = Modifier.size(16.dp))
                                                }
                                                Spacer(Modifier.width(10.dp))
                                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                                        Text(userName, style = AppTypography.subheadline.copy(fontWeight = FontWeight.SemiBold), color = AppColors.textPrimary)
                                                        Spacer(Modifier.weight(1f))
                                                        Text(dateLabel(item.text("created_at")), style = AppTypography.caption2, color = AppColors.textTertiary)
                                                    }
                                                    if (isComment) {
                                                        Text(item.text("content"), style = AppTypography.body, color = AppColors.textPrimary)
                                                    } else {
                                                        Text(item.text("content", label(actType)), style = AppTypography.body.copy(color = AppColors.textSecondary))
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
        }

        // Bottom comment area with @ mention autocomplete (Activity tab only, matching iOS)
        if (tab == "Activity") {
            val mentionQuery = remember(comment) {
                val lastAt = comment.lastIndexOf('@')
                if (lastAt >= 0) {
                    val isWordBefore = lastAt > 0 && comment[lastAt - 1].isLetterOrDigit()
                    if (!isWordBefore) {
                        val afterAt = comment.substring(lastAt + 1)
                        if (!afterAt.contains(' ') && !afterAt.contains('\n')) afterAt else null
                    } else null
                } else null
            }
            val mentionCandidates = remember(mentionQuery, members) {
                if (mentionQuery != null) {
                    members.filter {
                        it.label.contains(mentionQuery, ignoreCase = true)
                    }.take(5)
                } else emptyList()
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(AppColors.surfacePrimary)
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
            if (mentionCandidates.isNotEmpty()) {
                IosInsetGroupedCard(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(
                            "Mention member",
                            style = AppTypography.caption2,
                            color = AppColors.textTertiary,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                        )
                        mentionCandidates.forEach { member ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(AppRadius.small))
                                    .clickable {
                                        val lastAt = comment.lastIndexOf('@')
                                        if (lastAt >= 0) {
                                            val prefix = comment.substring(0, lastAt)
                                            comment = "$prefix@${member.label} "
                                        }
                                    }
                                    .padding(horizontal = 8.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                AppAvatar(member.label)
                                Spacer(Modifier.width(8.dp))
                                Text(member.label, style = AppTypography.subheadline, color = AppColors.textPrimary)
                            }
                        }
                    }
                }
            }

            Text(
                text = if (previewComment) "Edit" else "Preview",
                style = AppTypography.caption1,
                color = AppColors.brandPrimary,
                modifier = Modifier.clickable { previewComment = !previewComment }
            )

            if (previewComment) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppRadius.medium))
                        .background(AppColors.surfaceElevated)
                        .border(BorderStroke(1.dp, AppColors.borderDefault), RoundedCornerShape(AppRadius.medium))
                        .padding(14.dp)
                ) {
                    Text(
                        text = comment.ifBlank { "Nothing to preview" },
                        style = AppTypography.body,
                        color = AppColors.textPrimary
                    )
                }
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppRadius.medium))
                        .background(AppColors.surfaceElevated)
                        .border(BorderStroke(1.dp, AppColors.borderDefault), RoundedCornerShape(AppRadius.medium))
                        .padding(horizontal = 14.dp, vertical = 12.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.Bottom
                    ) {
                        Box(Modifier.weight(1f)) {
                            if (comment.isEmpty()) {
                                Text(
                                    text = "Add a comment... (Markdown supported)",
                                    style = AppTypography.body,
                                    color = AppColors.textTertiary
                                )
                            }
                            BasicTextField(
                                value = comment,
                                onValueChange = { comment = it },
                                textStyle = AppTypography.body.copy(color = AppColors.textPrimary),
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                        IconButton(
                            onClick = {
                                action.run {
                                    api.request("/api/tasks/$taskId/comments", "POST", json("content" to comment.trim()))
                                    comment = ""
                                    vm.changed()
                                }
                            },
                            enabled = comment.isNotBlank() && !action.busy,
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.Send,
                                contentDescription = "Send",
                                tint = if (comment.isNotBlank() && !action.busy) AppColors.brandPrimary else AppColors.textTertiary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

    // Modal Error Dialog (exact match to screenshot.png)
    if (alertError != null) {
        IosAlertDialog(
            title = "Error",
            message = alertError!!,
            onDismiss = {
                alertError = null
                action.error = null
            }
        )
    }

    editor?.let { title ->
        val fields = when (title) {
            "Edit task" -> taskFields(task, lists, members)
            "Checklist" -> listOf(FormField("title", "Title", required = true))
            "Subtasks" -> listOf(
                FormField("title", "Title", required = true),
                FormField("description", "Description"),
                FormField("priority", "Priority", "medium")
            )
            "Dependencies" -> listOf(
                FormField("type", "Relation Type (blocked_by, blocks, relates_to)", "blocked_by"),
                FormField("related_task_id", "Related Task ID", required = true)
            )
            "Time logs" -> listOf(
                FormField("hours_logged", "Hours", required = true),
                FormField("description", "Description"),
                FormField("logged_at", "Date", Instant.now().toString(), required = true, date = true)
            )
            else -> listOf(FormField("content", "Comment", required = true, multiline = true))
        }
        EditorDialog(title, fields, { editor = null }) { payload ->
            when (title) {
                "Edit task" -> {
                    payload.addProperty("expected_version", task.number("version"))
                    api.request("/api/tasks/$taskId", "PATCH", payload, version = task.number("version"))
                }
                "Subtasks" -> {
                    payload.addProperty("parent_id", taskId)
                    payload.addProperty("parent_task_id", taskId)
                    payload.addProperty("task_type", "subtask")
                    payload.addProperty("list_id", task.text("list_id"))
                    payload.addProperty("project_id", task.text("project_id"))
                    api.request("/api/tasks", "POST", payload)
                }
                "Dependencies" -> {
                    val rawType = payload.text("type").ifBlank { "blocked_by" }
                    val relType = when (rawType.lowercase()) {
                        "blocked_by", "blockedby", "blocked by" -> "blockedBy"
                        "blocks" -> "blocks"
                        "duplicate_of", "duplicateof" -> "duplicateOf"
                        else -> "relatesTo"
                    }
                    val relatedId = payload.text("related_task_id")
                    val relPayload = json(
                        "relationType" to relType,
                        "type" to relType,
                        "relatedTaskId" to relatedId,
                        "related_task_id" to relatedId
                    )
                    api.request("/api/tasks/$taskId/relations", "POST", relPayload)
                }
                "Time logs" -> {
                    val hours = payload.text("hours_logged").toDoubleOrNull()
                    require(hours != null && hours > 0 && hours <= 24) { "Enter hours between 0 and 24." }
                    payload.addProperty("hours_logged", hours)
                    api.request("/api/tasks/$taskId/time-logs", "POST", payload)
                }
                "Checklist" -> api.request("/api/tasks/$taskId/checklist", "POST", payload)
                else -> api.request("/api/tasks/$taskId/comments", "POST", payload)
            }
            vm.changed()
        }
    }

    if (delete) {
        ConfirmDialog("Delete task?", task.text("title"), { delete = false }) {
            api.request("/api/tasks/$taskId", "DELETE")
            vm.changed()
            onBack()
        }
    }

    if (showEpicDashboard) {
        EpicDetailDashboardModal(
            epicId = taskId,
            api = api,
            vm = vm,
            onSelectTask = { _ -> showEpicDashboard = false },
            onDismiss = { showEpicDashboard = false }
        )
    }

    if (selectedParentEpicId != null) {
        EpicDetailDashboardModal(
            epicId = selectedParentEpicId!!,
            api = api,
            vm = vm,
            onSelectTask = { _ -> selectedParentEpicId = null },
            onDismiss = { selectedParentEpicId = null }
        )
    }
}

// MARK: - Saved Views Modal (matching ViewConfig.swift & DashboardView.swift)
@Composable
fun SavedViewsModal(
    api: ApiClient,
    vm: AppViewModel,
    scope: String,
    scopeId: String,
    currentMode: String,
    currentStatus: String,
    currentPriority: String,
    currentSearch: String,
    onApplyView: (mode: String, status: String, priority: String, search: String) -> Unit,
    onDismiss: () -> Unit
) {
    val coroutineScope = rememberCoroutineScope()
    val viewsRemote = rememberRemote(
        api,
        "/api/views",
        vm.revision,
        query = mapOf("scope" to scope, "scopeId" to scopeId)
    )
    var showSaveDialog by remember { mutableStateOf(false) }
    var viewName by remember { mutableStateOf("") }
    var isDefault by remember { mutableStateOf(false) }
    var isPublic by remember { mutableStateOf(false) }

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
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Saved Views",
                        style = AppTypography.title2,
                        color = AppColors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    IconButton(onClick = { showSaveDialog = true }) {
                        Icon(Icons.Default.Add, "Save current view", tint = AppColors.brandPrimary)
                    }
                    IconButton(onClick = onDismiss, modifier = Modifier.size(28.dp)) {
                        Icon(Icons.Default.Close, "Close", tint = AppColors.textTertiary)
                    }
                }

                RemoteStatus(viewsRemote)

                val views = viewsRemote.data.rows()
                if (views.isEmpty()) {
                    Text(
                        text = "No saved views yet for this $scope. Save current filters to quickly access them later.",
                        style = AppTypography.caption1,
                        color = AppColors.textSecondary
                    )
                } else {
                    LazyColumn(
                        modifier = Modifier.fillMaxWidth().heightIn(max = 280.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(views) { viewItem ->
                            val isDefaultView = viewItem.flag("is_default")
                            IosCard(modifier = Modifier.fillMaxWidth()) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable {
                                            val vType = viewItem.text("type").replaceFirstChar { it.uppercase() }
                                            var targetStatus = ""
                                            var targetPriority = ""
                                            var targetSearch = ""
                                            val filtersStr = viewItem.text("filters_json").ifBlank { viewItem.text("filtersJson") }
                                            if (filtersStr.isNotBlank()) {
                                                runCatching {
                                                    val parsed = com.google.gson.JsonParser.parseString(filtersStr).obj()
                                                    targetStatus = parsed.text("status")
                                                    targetPriority = parsed.text("priority")
                                                    targetSearch = parsed.text("search")
                                                }
                                            }
                                            onApplyView(vType.ifBlank { "List" }, targetStatus, targetPriority, targetSearch)
                                            onDismiss()
                                        },
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(Modifier.weight(1f)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(
                                                text = viewItem.text("name"),
                                                style = AppTypography.headline,
                                                color = AppColors.textPrimary
                                            )
                                            if (isDefaultView) {
                                                Spacer(Modifier.width(6.dp))
                                                Icon(
                                                    Icons.Default.Star,
                                                    "Default",
                                                    tint = Color(0xFFFFCC00),
                                                    modifier = Modifier.size(16.dp)
                                                )
                                            }
                                        }
                                        Text(
                                            text = viewItem.text("type").uppercase(),
                                            style = AppTypography.caption2,
                                            color = AppColors.textTertiary
                                        )
                                    }
                                    IconButton(
                                        onClick = {
                                            coroutineScope.launch {
                                                runCatching {
                                                    api.request("/api/views/${viewItem.id}", "DELETE")
                                                    vm.changed()
                                                }
                                            }
                                        }
                                    ) {
                                        Icon(Icons.Default.Delete, "Delete view", tint = AppColors.statusError, modifier = Modifier.size(18.dp))
                                    }
                                }
                            }
                        }
                    }
                }

                IosButton(
                    title = "Save Current View",
                    onClick = { showSaveDialog = true },
                    variant = IosButtonVariant.Secondary,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }

    if (showSaveDialog) {
        AlertDialog(
            onDismissRequest = { showSaveDialog = false },
            title = { Text("Save Current View", style = AppTypography.title2) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    IosTextField(
                        label = "View Name",
                        value = viewName,
                        onValueChange = { viewName = it },
                        singleLine = true,
                        testTag = "input_save_view_name"
                    )
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = isDefault, onCheckedChange = { isDefault = it })
                        Text("Set as default view", style = AppTypography.body)
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = isPublic, onCheckedChange = { isPublic = it })
                        Text("Public to team", style = AppTypography.body)
                    }
                }
            },
            confirmButton = {
                TextButton(
                    enabled = viewName.isNotBlank(),
                    modifier = Modifier.testTag("btn_save_view_confirm"),
                    onClick = {
                        coroutineScope.launch {
                            val filtersObj = json(
                                "status" to currentStatus,
                                "priority" to currentPriority,
                                "search" to currentSearch
                            )
                            val payload = json(
                                "name" to viewName.trim(),
                                "type" to currentMode.lowercase(),
                                "filtersJson" to filtersObj.toString(),
                                "appliesTo" to scope,
                                "scopeId" to scopeId,
                                "isDefault" to isDefault,
                                "isPublic" to isPublic
                            )
                            runCatching {
                                api.request("/api/views", "POST", payload)
                                vm.changed()
                            }
                            showSaveDialog = false
                        }
                    }
                ) {
                    Text("Save", style = AppTypography.headline, color = AppColors.brandPrimary)
                }
            },
            dismissButton = {
                TextButton(onClick = { showSaveDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

// MARK: - Sync Center Modal (matching SyncCenterSheet.swift)
@Composable
fun SyncCenterModal(
    vm: AppViewModel,
    api: ApiClient,
    isLive: Boolean = true,
    onDismiss: () -> Unit
) {
    var lastSyncedText by remember { mutableStateOf("Just now") }
    val pendingOps by vm.syncEngine.pendingOperations.collectAsState()
    val attentionOps by vm.syncEngine.attentionOperations.collectAsState()
    val isSyncing by vm.syncEngine.isSyncing.collectAsState()
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
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Sync Center",
                        style = AppTypography.title2,
                        color = AppColors.textPrimary,
                        modifier = Modifier.weight(1f)
                    )
                    TextButton(
                        onClick = {
                            vm.syncEngine.syncNow {
                                lastSyncedText = "Just now"
                                vm.changed()
                            }
                        },
                        enabled = !isSyncing,
                        modifier = Modifier.testTag("btn_sync_now")
                    ) {
                        if (isSyncing) {
                            CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        } else {
                            Text("Sync Now", style = AppTypography.headline, color = AppColors.brandPrimary)
                        }
                    }
                }

                // Status Section matching SyncCenterSheet.swift
                IosInsetGroupedCard {
                    Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(10.dp)
                                    .clip(CircleShape)
                                    .background(
                                        when {
                                            isSyncing -> Color(0xFF007AFF)
                                            attentionOps.isNotEmpty() -> Color(0xFFFF3B30)
                                            isLive -> Color(0xFF34C759)
                                            else -> Color(0xFFFF9500)
                                        }
                                    )
                            )
                            Spacer(Modifier.width(8.dp))
                            Text(
                                text = when {
                                    isSyncing -> "Syncing (${pendingOps.size})"
                                    attentionOps.isNotEmpty() -> "Attention Needed"
                                    isLive -> "Online"
                                    else -> "Offline"
                                },
                                style = AppTypography.headline,
                                color = AppColors.textPrimary,
                                modifier = Modifier.weight(1f)
                            )
                            Text(
                                text = "Last: $lastSyncedText",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                        }
                        HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                        Text(
                            text = "Pending operations: ${pendingOps.size}",
                            style = AppTypography.caption1,
                            color = AppColors.textSecondary,
                            modifier = Modifier.testTag("txt_pending_count")
                        )
                        Text(
                            text = "Needs attention: ${attentionOps.size}",
                            style = AppTypography.caption1,
                            color = if (attentionOps.isNotEmpty()) AppColors.statusError else AppColors.textSecondary,
                            modifier = Modifier.testTag("txt_attention_count")
                        )
                    }
                }

                // Needs Attention Section (Conflicts & Sync Errors)
                if (attentionOps.isNotEmpty()) {
                    Text(
                        text = "Needs Attention",
                        style = AppTypography.headline,
                        color = AppColors.statusError
                    )
                    IosInsetGroupedCard {
                        Column(
                            Modifier.padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            attentionOps.forEach { op ->
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .testTag("attention_row_${op.id}"),
                                    verticalArrangement = Arrangement.spacedBy(6.dp)
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Text(
                                            text = "${op.operation.uppercase()} ${op.entityType.uppercase()}",
                                            style = AppTypography.headline,
                                            color = AppColors.textPrimary,
                                            modifier = Modifier.weight(1f)
                                        )
                                        Text(
                                            text = op.entityId.take(8),
                                            style = AppTypography.caption2,
                                            color = AppColors.textTertiary
                                        )
                                    }
                                    if (!op.lastError.isNullOrBlank()) {
                                        Text(
                                            text = op.lastError.orEmpty(),
                                            style = AppTypography.caption1,
                                            color = AppColors.statusError
                                        )
                                    }
                                    // Conflict Resolution Actions matching iOS SyncCenterSheet.swift
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                                    ) {
                                        if (op.remoteSnapshotJson != null) {
                                            OutlinedButton(
                                                onClick = { vm.syncEngine.resolveConflictUseTheirs(op) },
                                                modifier = Modifier.weight(1f).testTag("btn_use_theirs_${op.id}")
                                            ) {
                                                Text("Use Theirs", style = AppTypography.caption1)
                                            }
                                            Button(
                                                onClick = { vm.syncEngine.resolveConflictKeepMine(op) },
                                                colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary),
                                                modifier = Modifier.weight(1f).testTag("btn_keep_mine_${op.id}")
                                            ) {
                                                Text("Keep Mine", style = AppTypography.caption1, color = Color.White)
                                            }
                                        } else {
                                            OutlinedButton(
                                                onClick = { vm.syncEngine.retry(op) },
                                                modifier = Modifier.weight(1f).testTag("btn_retry_${op.id}")
                                            ) {
                                                Text("Retry", style = AppTypography.caption1)
                                            }
                                            Button(
                                                onClick = { vm.syncEngine.discard(op) },
                                                colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusError),
                                                modifier = Modifier.weight(1f).testTag("btn_discard_${op.id}")
                                            ) {
                                                Text("Discard", style = AppTypography.caption1, color = Color.White)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Pending Section
                if (pendingOps.isNotEmpty()) {
                    Text(
                        text = "Pending Operations",
                        style = AppTypography.headline,
                        color = AppColors.textPrimary
                    )
                    IosInsetGroupedCard {
                        Column(
                            Modifier.padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            pendingOps.forEach { op ->
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .testTag("pending_row_${op.id}"),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "${op.operation.uppercase()} ${op.entityType.uppercase()}",
                                        style = AppTypography.body,
                                        color = AppColors.textPrimary,
                                        modifier = Modifier.weight(1f)
                                    )
                                    Text(
                                        text = op.entityId.take(8),
                                        style = AppTypography.caption1,
                                        color = AppColors.textSecondary
                                    )
                                }
                            }
                        }
                    }
                }

                IosButton(
                    title = "Close",
                    onClick = onDismiss,
                    modifier = Modifier.fillMaxWidth().testTag("btn_close_sync_center")
                )
            }
        }
    }
}
