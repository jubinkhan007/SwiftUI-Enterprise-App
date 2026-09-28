package com.acme.taskflow.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*
import com.google.gson.JsonObject
import java.time.Instant
import kotlin.math.roundToInt

@Composable
fun ProjectScreen(vm: AppViewModel, api: ApiClient, projectId: String, mode: String, onTask: (String) -> Unit) {
    Box(Modifier.fillMaxSize().background(AppColors.backgroundPrimary)) {
        when (mode) {
            "Backlog" -> BacklogScreen(vm, api, projectId, onTask)
            "Analytics" -> AnalyticsScreen(vm, api, projectId)
            "Releases" -> ReleasesScreen(vm, api, projectId, onTask)
        }
    }
}

@Composable
private fun BacklogScreen(vm: AppViewModel, api: ApiClient, projectId: String, onTask: (String) -> Unit) {
    val sprints = rememberRemote(api, "/api/projects/$projectId/sprints", vm.revision)
    var sprint by rememberSaveable(projectId) { mutableStateOf("") }
    val issues = rememberRemote(api, if (sprint.isBlank()) "/api/projects/$projectId/backlog" else "/api/sprints/$sprint/issues", vm.revision)
    val action = rememberAction()
    var create by remember { mutableStateOf(false) }
    var moving by remember { mutableStateOf<JsonObject?>(null) }
    var showTimeReport by remember { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier.fillMaxSize().testTag("backlog_list"),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    if (sprint.isBlank()) "Product Backlog" else "Sprint Planning",
                    Modifier.weight(1f),
                    style = AppTypography.largeTitle
                )
                IconButton(
                    onClick = { showTimeReport = true },
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                        .testTag("btn_project_time_report")
                ) {
                    Icon(Icons.Default.Schedule, "Time report", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                }
                Spacer(Modifier.width(8.dp))
                IconButton(
                    onClick = { create = true },
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                        .testTag("btn_create_sprint")
                ) {
                    Icon(Icons.Default.Add, "Create sprint", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                }
            }
            Spacer(Modifier.height(8.dp))
            RemoteStatus(sprints)
            Box(Modifier.testTag("sprint_selector")) {
                ChoiceMenu(
                    "Sprint",
                    sprint,
                    listOf(Choice("", "Backlog")) + sprints.data.rows().map { Choice(it.id, "${it.text("name")} (${label(it.text("status"))})") }
                ) { sprint = it }
            }

            sprints.data.rows().find { it.id == sprint }?.let { item ->
                val currentRows = issues.data.rows()
                val totalPoints = currentRows.sumOf { it.number("story_points")?.toDouble() ?: 0.0 }
                val capacity = item.number("capacity")?.toDouble() ?: 0.0
                val isOver = capacity > 0 && totalPoints > capacity

                Spacer(Modifier.height(8.dp))
                IosCard(Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                "${dateLabel(item.text("start_date"))} → ${dateLabel(item.text("end_date"))}",
                                style = AppTypography.caption1,
                                color = AppColors.brandPrimary
                            )
                            IosPill(label(item.text("status")))
                        }

                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("Story Points Capacity", style = AppTypography.caption1, color = AppColors.textSecondary)
                            Text(
                                if (capacity > 0) "${totalPoints.toInt()} / ${capacity.toInt()} pts" else "${totalPoints.toInt()} pts",
                                modifier = Modifier.testTag("txt_sprint_points"),
                                style = AppTypography.caption1,
                                color = if (isOver) AppColors.statusError else AppColors.textPrimary
                            )
                        }

                        if (capacity > 0) {
                            val ratio = (totalPoints / capacity).toFloat().coerceIn(0f, 1f)
                            LinearProgressIndicator(
                                progress = { ratio },
                                modifier = Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)),
                                color = if (isOver) AppColors.statusError else AppColors.brandPrimary,
                                trackColor = AppColors.surfaceElevated
                            )
                        }

                        Row(
                            Modifier.fillMaxWidth().padding(top = 4.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            if (item.text("status") == "planned") {
                                Button(
                                    onClick = {
                                        action.run {
                                            api.request("/api/sprints/$sprint", "PATCH", json("status" to "active"))
                                            vm.changed()
                                        }
                                    },
                                    modifier = Modifier.weight(1f).testTag("btn_start_sprint"),
                                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.brandPrimary)
                                ) {
                                    Icon(Icons.Default.PlayArrow, null, Modifier.size(16.dp))
                                    Spacer(Modifier.width(4.dp))
                                    Text("Start Sprint", style = AppTypography.caption1)
                                }
                            } else if (item.text("status") == "active") {
                                Button(
                                    onClick = {
                                        action.run {
                                            api.request("/api/sprints/$sprint", "PATCH", json("status" to "completed"))
                                            vm.changed()
                                        }
                                    },
                                    modifier = Modifier.weight(1f).testTag("btn_complete_sprint"),
                                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusSuccess)
                                ) {
                                    Icon(Icons.Default.Check, null, Modifier.size(16.dp))
                                    Spacer(Modifier.width(4.dp))
                                    Text("Complete Sprint", style = AppTypography.caption1)
                                }
                            }

                            Box(Modifier.weight(1f)) {
                                ChoiceMenu("Status", item.text("status"), choices("planned", "active", "completed", "closed")) { status ->
                                    action.run {
                                        api.request("/api/sprints/$sprint", "PATCH", json("status" to status))
                                        vm.changed()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            RemoteStatus(issues)
            ActionStatus(action)
        }

        items(issues.data.rows(), key = { it.id }) { task ->
            IosCard(
                modifier = Modifier.fillMaxWidth(),
                onClick = { onTask(task.id) }
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(task.text("title"), style = AppTypography.headline)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(task.text("issue_key"), style = AppTypography.caption1, color = AppColors.brandPrimary)
                            IosPill(label(task.text("status")))
                            Text("${task.text("story_points", "0")} pts", style = AppTypography.caption2, color = AppColors.textTertiary)
                        }
                    }
                    IconButton(
                        onClick = { moving = task },
                        modifier = Modifier.testTag("btn_move_task_${task.id}")
                    ) {
                        Icon(
                            if (sprint.isBlank()) Icons.Default.MoveUp else Icons.Default.MoveDown,
                            "Move task",
                            tint = AppColors.brandPrimary
                        )
                    }
                }
            }
        }
    }

    if (create) {
        EditorDialog(
            "Create sprint",
            listOf(
                FormField("name", "Name", required = true),
                FormField("start_date", "Start", Instant.now().toString(), required = true, date = true),
                FormField("end_date", "End", Instant.now().plusSeconds(1209600).toString(), required = true, date = true),
                FormField("capacity", "Capacity", numeric = true)
            ),
            { create = false }
        ) {
            require(Instant.parse(it.text("end_date")).isAfter(Instant.parse(it.text("start_date")))) { "End must be after start." }
            api.request("/api/projects/$projectId/sprints", "POST", it)
            vm.changed()
        }
    }

    moving?.let { task ->
        val sprintOptions = listOf(Choice("", "Backlog (Unassigned)")) + sprints.data.rows()
            .filter { it.text("status") in listOf("planned", "active") }
            .map { Choice(it.id, it.text("name")) }

        EditorDialog(
            "Move task",
            listOf(
                FormField(
                    "sprint_id",
                    "Target Sprint",
                    required = false,
                    options = sprintOptions
                )
            ),
            { moving = null }
        ) {
            if (it.text("sprint_id").isBlank()) {
                it.remove("sprint_id")
                it.add("sprint_id", com.google.gson.JsonNull.INSTANCE)
                it.addProperty("backlog_position", 1000)
            } else {
                it.addProperty("sprint_position", 1000)
            }
            it.addProperty("expected_version", task.number("version"))
            api.request("/api/tasks/${task.id}", "PATCH", it, version = task.number("version"))
            vm.changed()
        }
    }

    if (showTimeReport) {
        ProjectTimeReportDialog(projectId, api, vm, onDismiss = { showTimeReport = false })
    }
}

@Composable
private fun AnalyticsScreen(vm: AppViewModel, api: ApiClient, projectId: String) {
    var days by rememberSaveable { mutableStateOf("30") }
    val range = remember(days) {
        mapOf(
            "start_date" to Instant.now().minusSeconds(days.toLong() * 86400).epochSecond.toString(),
            "end_date" to Instant.now().epochSecond.toString()
        )
    }
    val report = rememberRemote(api, "/api/projects/$projectId/analytics/report", vm.revision, query = range)

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Text("Analytics", style = AppTypography.largeTitle)
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("7" to "7 Days", "30" to "30 Days", "90" to "90 Days").forEach { (v, label) ->
                    IosFilterChip(
                        title = label,
                        isSelected = days == v,
                        onClick = { days = v }
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            RemoteStatus(report)
        }

        if (!report.data.isJsonNull) {
            items(listOf("lead_time", "cycle_time", "velocity", "throughput")) { metric ->
                val value = report.data.obj().child(metric)
                IosCard(Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(label(metric), style = AppTypography.headline)
                            Text("${value.number("sample_size")} samples", style = AppTypography.caption1, color = AppColors.textSecondary)
                        }
                        Text(
                            value.text("value", "-"),
                            style = AppTypography.title1,
                            color = AppColors.brandPrimary
                        )
                    }
                }
            }

            item {
                IosCard(Modifier.fillMaxWidth()) {
                    Text("Burndown Chart", style = AppTypography.headline)
                    Spacer(Modifier.height(12.dp))
                    val points = report.data.obj().list("burndown")
                    if (points.isEmpty()) {
                        Text("No data for this period.", style = AppTypography.caption1, color = AppColors.textSecondary)
                    } else {
                        val color = AppColors.brandPrimary
                        val values = points.map { it.text("remaining_points", "0").toFloatOrNull() ?: 0f }
                        Canvas(
                            Modifier
                                .fillMaxWidth()
                                .height(160.dp)
                                .padding(8.dp)
                        ) {
                            val max = values.maxOrNull()?.coerceAtLeast(1f) ?: 1f
                            val path = Path()
                            values.forEachIndexed { index, value ->
                                val x = index.toFloat() / (values.size - 1).coerceAtLeast(1) * size.width
                                val y = size.height - value / max * size.height
                                if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
                                drawCircle(color, 4.dp.toPx(), Offset(x, y))
                            }
                            drawPath(path, color, style = Stroke(2.5.dp.toPx()))
                        }
                    }
                }
            }

            item {
                val timeReport = rememberRemote(api, "/api/projects/$projectId/time-logs/report", vm.revision)
                val timeData = timeReport.data.obj()
                val totalHours = timeData.double("total_hours", timeData.double("totalHours"))
                val byUser = timeData.list("by_user").ifEmpty { timeData.list("byUser") }
                val byTask = timeData.list("by_task").ifEmpty { timeData.list("byTask") }

                IosCard(Modifier.fillMaxWidth().testTag("card_project_time_report")) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Schedule, null, tint = AppColors.brandPrimary, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("Time & Work Logs Report", style = AppTypography.headline, modifier = Modifier.weight(1f))
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(AppRadius.pill))
                                    .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                                    .padding(horizontal = 8.dp, vertical = 2.dp)
                            ) {
                                Text(
                                    String.format(java.util.Locale.US, "%.1f hrs total", totalHours),
                                    style = AppTypography.caption1.copy(fontWeight = FontWeight.Bold),
                                    color = AppColors.brandPrimary
                                )
                            }
                        }

                        RemoteStatus(timeReport)

                        if (byUser.isNotEmpty()) {
                            Text("By Contributor", style = AppTypography.caption1.copy(fontWeight = FontWeight.SemiBold), color = AppColors.textSecondary)
                            byUser.forEach { u ->
                                val userHours = u.double("total_hours", u.double("totalHours"))
                                val userName = u.text("user_display_name", u.text("userDisplayName", "Team Member"))
                                val ratio = if (totalHours > 0) (userHours / totalHours).toFloat().coerceIn(0f, 1f) else 0f
                                val pct = (ratio * 100).roundToInt()

                                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween,
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        Text(userName, style = AppTypography.caption1)
                                        Text(
                                            String.format(java.util.Locale.US, "%.1fh (%d%%)", userHours, pct),
                                            style = AppTypography.caption2.copy(fontWeight = FontWeight.SemiBold),
                                            color = AppColors.brandPrimary
                                        )
                                    }
                                    LinearProgressIndicator(
                                        progress = { ratio },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(4.dp)
                                            .clip(RoundedCornerShape(2.dp)),
                                        color = AppColors.brandPrimary,
                                        trackColor = AppColors.borderSubtle
                                    )
                                }
                            }
                        }

                        if (byTask.isNotEmpty()) {
                            Spacer(Modifier.height(4.dp))
                            Text("By Task", style = AppTypography.caption1.copy(fontWeight = FontWeight.SemiBold), color = AppColors.textSecondary)
                            byTask.take(4).forEach { t ->
                                val taskHours = t.double("total_hours", t.double("totalHours"))
                                val taskTitle = t.text("task_title", t.text("taskTitle", "Task"))
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        taskTitle,
                                        style = AppTypography.caption2,
                                        color = AppColors.textPrimary,
                                        modifier = Modifier.weight(1f)
                                    )
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        String.format(java.util.Locale.US, "%.1f h", taskHours),
                                        style = AppTypography.caption2.copy(fontWeight = FontWeight.Bold),
                                        color = AppColors.textSecondary
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

fun buildAndroidReleaseNotesMarkdown(release: JsonObject, progress: JsonObject?, issues: List<JsonObject>): String {
    val lines = mutableListOf<String>()
    val name = release.text("name").ifBlank { "Release" }
    lines.add("# Release Notes — $name")

    val releaseDate = release.text("release_date")
    if (releaseDate.isNotBlank()) {
        lines.add("")
        lines.add("_Planned: ${dateLabel(releaseDate)}_")
    }

    val releasedAt = release.text("released_at")
    if (release.text("status") == "released" && releasedAt.isNotBlank()) {
        lines.add("")
        lines.add("_Released: ${dateLabel(releasedAt)}_")
    }

    if (progress != null) {
        val doneIssues = progress.number("done_issues")
        val totalIssues = progress.number("total_issues")
        val donePoints = progress.number("done_points")
        val totalPoints = progress.number("total_points")
        val bugCount = progress.number("bug_count")
        val criticalBugCount = progress.number("critical_bug_count")

        lines.add("")
        lines.add("## Summary")
        lines.add("- Issues: $doneIssues/$totalIssues done")
        lines.add("- Points: $donePoints/$totalPoints done")
        lines.add("- Bugs: $bugCount (critical: $criticalBugCount)")
    }

    val done = issues.filter { it.text("status") == "done" || it.text("completed_at").isNotBlank() }
    val remaining = issues.filter { it.text("status") != "done" && it.text("completed_at").isBlank() }

    fun bullet(task: JsonObject): String {
        val key = task.text("issue_key").let { if (it.isNotBlank()) "$it — " else "" }
        return "- $key${task.text("title")}"
    }

    if (done.isNotEmpty()) {
        lines.add("")
        lines.add("## Completed")
        for (t in done) {
            lines.add(bullet(t))
        }
    }

    if (remaining.isNotEmpty()) {
        lines.add("")
        lines.add("## In Progress / Remaining")
        for (t in remaining) {
            lines.add(bullet(t))
        }
    }

    return lines.joinToString("\n")
}

@Composable
private fun ReleasesScreen(vm: AppViewModel, api: ApiClient, projectId: String, onTask: (String) -> Unit) {
    val remote = rememberRemote(api, "/api/projects/$projectId/releases", vm.revision)
    val action = rememberAction()
    var selected by rememberSaveable(projectId) { mutableStateOf("") }
    var create by remember { mutableStateOf(false) }
    var finalize by remember { mutableStateOf(false) }
    var finalizeLock by remember { mutableStateOf(true) }
    var showNotesDialog by remember { mutableStateOf(false) }
    var generatedNotes by remember { mutableStateOf("") }
    var copiedToast by remember { mutableStateOf(false) }
    val clipboardManager = LocalClipboardManager.current

    LazyColumn(
        modifier = Modifier.fillMaxSize().testTag("releases_list"),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(Modifier.weight(1f)) {
                    Text("Releases", style = AppTypography.largeTitle)
                    Text(
                        "Manage versions, scope progress & release notes",
                        style = AppTypography.caption1,
                        color = AppColors.textSecondary
                    )
                }
                IconButton(
                    onClick = { create = true },
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                        .testTag("btn_create_release")
                ) {
                    Icon(Icons.Default.Add, "Create release", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                }
            }
            RemoteStatus(remote)
        }

        val rows = remote.data.rows()
        if (!remote.loading && remote.error == null && rows.isEmpty()) {
            item {
                IosCard(Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(Icons.Default.Inventory2, null, tint = AppColors.brandPrimary, modifier = Modifier.size(36.dp))
                        Spacer(Modifier.height(8.dp))
                        Text("No releases found", style = AppTypography.headline)
                        Text(
                            "Create your first release to track progress and generate notes.",
                            style = AppTypography.caption1,
                            color = AppColors.textSecondary
                        )
                    }
                }
            }
        }

        items(rows, key = { it.id }) { release ->
            val isSelected = selected == release.id
            val status = release.text("status").ifBlank { "unreleased" }
            val isReleased = status == "released"
            val isLocked = release.flag("is_locked") || release.flag("isLocked")

            IosCard(
                modifier = Modifier.fillMaxWidth().testTag("release_card_${release.id}"),
                onClick = { selected = if (isSelected) "" else release.id }
            ) {
                Column(Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(release.text("name"), style = AppTypography.headline)
                                if (isLocked) {
                                    Icon(Icons.Default.Lock, "Locked", tint = AppColors.statusWarning, modifier = Modifier.size(14.dp))
                                }
                            }
                            val plannedDate = release.text("release_date")
                            val releasedAt = release.text("released_at")
                            val dateInfo = when {
                                isReleased && releasedAt.isNotBlank() -> "Shipped ${dateLabel(releasedAt)}"
                                plannedDate.isNotBlank() -> "Planned: ${dateLabel(plannedDate)}"
                                else -> "No planned date"
                            }
                            Text(dateInfo, style = AppTypography.caption1, color = AppColors.textSecondary)
                        }

                        IosPill(
                            label(status),
                            selected = isReleased
                        )
                    }

                    if (release.text("description").isNotBlank()) {
                        Spacer(Modifier.height(6.dp))
                        Text(
                            release.text("description"),
                            style = AppTypography.caption1,
                            color = AppColors.textSecondary,
                            maxLines = 2
                        )
                    }
                }
            }
        }

        if (selected.isNotBlank()) {
            item {
                val progress = rememberRemote(api, "/api/releases/$selected/progress", vm.revision)
                val issues = rememberRemote(api, "/api/releases/$selected/issues", vm.revision)
                RemoteStatus(progress)
                RemoteStatus(issues)

                val selectedRelease = rows.find { it.id == selected }
                val isSelectedReleased = selectedRelease?.text("status") == "released"

                IosCard(Modifier.fillMaxWidth().testTag("release_detail_card")) {
                    val p = progress.data.obj()
                    val totalIssues = p.number("total_issues")
                    val doneIssues = p.number("done_issues")
                    val remainingIssues = p.number("remaining_issues")
                    val totalPoints = p.number("total_points")
                    val donePoints = p.number("done_points")
                    val bugCount = p.number("bug_count")
                    val criticalBugCount = p.number("critical_bug_count")

                    val ratio = if (totalIssues > 0) doneIssues.toFloat() / totalIssues.toFloat() else 0f

                    Text("Release Progress", style = AppTypography.headline)
                    Spacer(Modifier.height(6.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("$doneIssues / $totalIssues issues complete", style = AppTypography.subheadline, fontWeight = FontWeight.SemiBold)
                        Text("$donePoints / $totalPoints pts (${(ratio * 100).roundToInt()}%)", style = AppTypography.caption1, color = AppColors.brandPrimary, fontWeight = FontWeight.Bold)
                    }

                    Spacer(Modifier.height(6.dp))
                    LinearProgressIndicator(
                        progress = { ratio },
                        modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)).testTag("release_progress_bar"),
                        color = AppColors.brandPrimary,
                        trackColor = AppColors.surfaceElevated
                    )

                    Spacer(Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text("Remaining: $remainingIssues", style = AppTypography.caption2, color = AppColors.textSecondary)
                        if (bugCount > 0) {
                            Text("Bugs: $bugCount", style = AppTypography.caption2, color = AppColors.statusWarning)
                        }
                        if (criticalBugCount > 0) {
                            Text("Critical: $criticalBugCount", style = AppTypography.caption2, color = AppColors.statusError, fontWeight = FontWeight.Bold)
                        }
                    }

                    val issueList = issues.data.rows()

                    Spacer(Modifier.height(12.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        IosButton(
                            title = "Generate Release Notes",
                            onClick = {
                                val rel = selectedRelease ?: json("id" to selected, "name" to "Release", "status" to "unreleased")
                                generatedNotes = buildAndroidReleaseNotesMarkdown(rel, p, issueList)
                                showNotesDialog = true
                            },
                            modifier = Modifier.weight(1f).height(44.dp).testTag("btn_generate_notes")
                        )

                        if (!isSelectedReleased) {
                            IosButton(
                                title = "Ship Version",
                                onClick = { finalize = true },
                                modifier = Modifier.weight(1f).height(44.dp).testTag("btn_finalize_release")
                            )
                        }
                    }

                    Spacer(Modifier.height(14.dp))
                    HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                    Spacer(Modifier.height(12.dp))

                    Text("Linked Issues (${issueList.size})", style = AppTypography.subheadline, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(6.dp))

                    if (issueList.isEmpty()) {
                        Text("No issues linked to this release yet.", style = AppTypography.caption1, color = AppColors.textSecondary)
                    } else {
                        issueList.forEach { task ->
                            val key = task.text("issue_key").let { if (it.isNotBlank()) "[$it] " else "" }
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(6.dp))
                                    .clickable { onTask(task.id) }
                                    .padding(vertical = 4.dp, horizontal = 2.dp)
                                    .testTag("task_row_${task.id}"),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "$key${task.text("title")}",
                                    style = AppTypography.body,
                                    modifier = Modifier.weight(1f),
                                    maxLines = 1
                                )
                                Spacer(Modifier.width(8.dp))
                                IosPill(
                                    label(task.text("status")),
                                    selected = task.text("status") == "done"
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    if (create) {
        EditorDialog(
            "Create release",
            listOf(
                FormField("name", "Name", required = true),
                FormField("description", "Description", multiline = true),
                FormField("release_date", "Release date", date = true)
            ),
            { create = false }
        ) {
            api.request("/api/projects/$projectId/releases", "POST", it)
            vm.changed()
        }
    }

    if (showNotesDialog) {
        AlertDialog(
            onDismissRequest = { showNotesDialog = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Description, null, tint = AppColors.brandPrimary, modifier = Modifier.size(22.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Release Notes (Markdown)", style = AppTypography.headline)
                }
            },
            text = {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 350.dp)
                        .verticalScroll(rememberScrollState())
                        .background(AppColors.surfaceElevated, RoundedCornerShape(AppRadius.medium))
                        .padding(12.dp)
                ) {
                    Text(
                        text = generatedNotes,
                        style = AppTypography.caption1.copy(fontSize = 12.sp, lineHeight = 16.sp),
                        color = AppColors.textPrimary
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        clipboardManager.setText(AnnotatedString(generatedNotes))
                        copiedToast = true
                    },
                    modifier = Modifier.testTag("btn_copy_notes")
                ) {
                    Icon(Icons.Default.ContentCopy, null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(if (copiedToast) "Copied!" else "Copy to Clipboard", color = AppColors.brandPrimary)
                }
            },
            dismissButton = {
                TextButton(onClick = { showNotesDialog = false }) {
                    Text("Close", color = AppColors.textSecondary)
                }
            },
            modifier = Modifier.testTag("dialog_release_notes")
        )
    }

    if (finalize) {
        AlertDialog(
            onDismissRequest = { finalize = false },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.RocketLaunch, null, tint = AppColors.statusSuccess, modifier = Modifier.size(22.dp))
                    Spacer(Modifier.width(8.dp))
                    Text("Finalize Release?", style = AppTypography.headline)
                }
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        "Shipping this version marks it as released and stamps the completion date.",
                        style = AppTypography.body,
                        color = AppColors.textSecondary
                    )
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.clickable { finalizeLock = !finalizeLock }
                    ) {
                        Checkbox(
                            checked = finalizeLock,
                            onCheckedChange = { finalizeLock = it },
                            modifier = Modifier.testTag("checkbox_lock_issues")
                        )
                        Spacer(Modifier.width(6.dp))
                        Text("Lock release against modifications", style = AppTypography.caption1, color = AppColors.textPrimary)
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        action.run {
                            api.request("/api/releases/$selected/release", "POST", json("lock" to finalizeLock))
                            finalize = false
                            vm.changed()
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = AppColors.statusSuccess),
                    modifier = Modifier.testTag("btn_confirm_finalize")
                ) {
                    Text("Confirm & Ship")
                }
            },
            dismissButton = {
                TextButton(onClick = { finalize = false }) {
                    Text("Cancel", color = AppColors.textSecondary)
                }
            },
            modifier = Modifier.testTag("dialog_finalize_release")
        )
    }
}


@Composable
fun ProjectTimeReportDialog(
    projectId: String,
    api: ApiClient,
    vm: AppViewModel,
    onDismiss: () -> Unit
) {
    val report = rememberRemote(api, "/api/projects/$projectId/time-logs/report", vm.revision)
    val data = report.data.obj()
    val totalHours = data.double("total_hours", data.double("totalHours"))
    val byUser = data.list("by_user").ifEmpty { data.list("byUser") }
    val byTask = data.list("by_task").ifEmpty { data.list("byTask") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Schedule, null, tint = AppColors.brandPrimary, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(8.dp))
                Text("Project Time Report", style = AppTypography.headline)
            }
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                RemoteStatus(report)

                // Total hours summary banner
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppRadius.medium))
                        .background(AppColors.brandPrimary.copy(alpha = 0.08f))
                        .border(BorderStroke(1.dp, AppColors.brandPrimary.copy(alpha = 0.2f)), RoundedCornerShape(AppRadius.medium))
                        .padding(16.dp)
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("Total Logged Time", style = AppTypography.caption1, color = AppColors.textSecondary)
                        Text(
                            String.format(java.util.Locale.US, "%.1f Hours", totalHours),
                            style = AppTypography.largeTitle.copy(color = AppColors.brandPrimary, fontWeight = FontWeight.Bold)
                        )
                    }
                }

                // By User breakdown
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Time by Contributor", style = AppTypography.headline.copy(fontSize = 14.sp))
                    if (byUser.isEmpty()) {
                        Text("No contributor time logs recorded.", style = AppTypography.caption1, color = AppColors.textSecondary)
                    } else {
                        byUser.forEach { u ->
                            val userHours = u.double("total_hours", u.double("totalHours"))
                            val userName = u.text("user_display_name", u.text("userDisplayName", "Team Member"))
                            val ratio = if (totalHours > 0) (userHours / totalHours).toFloat().coerceIn(0f, 1f) else 0f
                            val pct = (ratio * 100).roundToInt()

                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(userName, style = AppTypography.body.copy(fontWeight = FontWeight.Medium))
                                    Text(
                                        String.format(java.util.Locale.US, "%.1f h (%d%%)", userHours, pct),
                                        style = AppTypography.caption1.copy(fontWeight = FontWeight.SemiBold),
                                        color = AppColors.brandPrimary
                                    )
                                }
                                LinearProgressIndicator(
                                    progress = { ratio },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(6.dp)
                                        .clip(RoundedCornerShape(3.dp)),
                                    color = AppColors.brandPrimary,
                                    trackColor = AppColors.borderSubtle
                                )
                            }
                        }
                    }
                }

                // By Task breakdown
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Top Tasks by Time Spent", style = AppTypography.headline.copy(fontSize = 14.sp))
                    if (byTask.isEmpty()) {
                        Text("No task time logs recorded.", style = AppTypography.caption1, color = AppColors.textSecondary)
                    } else {
                        byTask.take(5).forEach { t ->
                            val taskHours = t.double("total_hours", t.double("totalHours"))
                            val taskTitle = t.text("task_title", t.text("taskTitle", "Task"))
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(AppRadius.small))
                                    .background(AppColors.surfaceElevated)
                                    .padding(horizontal = 10.dp, vertical = 8.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    taskTitle,
                                    style = AppTypography.caption1.copy(fontWeight = FontWeight.Medium),
                                    modifier = Modifier.weight(1f)
                                )
                                Spacer(Modifier.width(8.dp))
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(AppRadius.pill))
                                        .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                                        .padding(horizontal = 8.dp, vertical = 2.dp)
                                ) {
                                    Text(
                                        String.format(java.util.Locale.US, "%.1f h", taskHours),
                                        style = AppTypography.caption2.copy(fontWeight = FontWeight.Bold),
                                        color = AppColors.brandPrimary
                                    )
                                }
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Close", color = AppColors.brandPrimary)
            }
        }
    )
}
