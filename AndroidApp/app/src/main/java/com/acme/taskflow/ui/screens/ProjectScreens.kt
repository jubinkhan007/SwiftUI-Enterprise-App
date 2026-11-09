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
import androidx.compose.foundation.horizontalScroll
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
            "Settings" -> ProjectSettingsScreen(vm, api, projectId)
            "Integrations" -> IntegrationsScreen(vm, api)
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
                val completedRows = currentRows.filter { it.text("status") == "done" }
                val completedPoints = completedRows.sumOf { it.number("story_points")?.toDouble() ?: 0.0 }
                val capacity = item.number("capacity")?.toDouble() ?: 0.0
                val isOver = capacity > 0 && totalPoints > capacity
                var rolloverTarget by rememberSaveable(sprint) { mutableStateOf("next_sprint") }

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
                            Text(
                                "${completedPoints.toInt()} pts done (${completedRows.size}/${currentRows.size})",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
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

                        if (item.text("status") == "active") {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("Open tasks:", style = AppTypography.caption2, color = AppColors.textTertiary)
                                IosFilterChip(
                                    title = "Rollover Next",
                                    isSelected = rolloverTarget == "next_sprint",
                                    onClick = { rolloverTarget = "next_sprint" }
                                )
                                IosFilterChip(
                                    title = "To Backlog",
                                    isSelected = rolloverTarget == "backlog",
                                    onClick = { rolloverTarget = "backlog" }
                                )
                            }
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
                                            api.request(
                                                "/api/sprints/$sprint",
                                                "PATCH",
                                                json(
                                                    "status" to "completed",
                                                    "rolloverUncompletedTo" to rolloverTarget
                                                )
                                            )
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

private fun formatAnalyticsDuration(seconds: Double): String {
    if (seconds <= 0.0 || seconds.isNaN()) return "0h"
    val days = seconds / 86400.0
    if (days >= 1.0) return String.format(java.util.Locale.US, "%.1fd", days)
    val hours = seconds / 3600.0
    if (hours >= 1.0) return String.format(java.util.Locale.US, "%.1fh", hours)
    val mins = (seconds / 60.0).roundToInt().coerceAtLeast(1)
    return "${mins}m"
}

@Composable
private fun AnalyticsScreen(vm: AppViewModel, api: ApiClient, projectId: String) {
    var days by rememberSaveable { mutableStateOf("30") }
    var recomputeNonce by rememberSaveable { mutableStateOf(0) }
    val range = remember(days, recomputeNonce) {
        buildMap {
            put("start_date", Instant.now().minusSeconds(days.toLong() * 86400).epochSecond.toString())
            put("end_date", Instant.now().epochSecond.toString())
            if (recomputeNonce > 0) put("recompute", "true")
        }
    }
    val report = rememberRemote(api, "/api/projects/$projectId/analytics/report", vm.revision + recomputeNonce, query = range)

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Analytics", style = AppTypography.largeTitle)
                IosFilterChip(
                    title = "Recompute",
                    isSelected = false,
                    onClick = { recomputeNonce += 1 }
                )
            }
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
            val reportObj = report.data.obj()
            val kpiSpecs = listOf(
                Triple("leadTime", "lead_time", "Lead Time"),
                Triple("cycleTime", "cycle_time", "Cycle Time"),
                Triple("velocity", "velocity", "Velocity"),
                Triple("throughput", "throughput", "Throughput")
            )
            items(kpiSpecs) { (camelKey, snakeKey, title) ->
                val metricObj = reportObj.child(camelKey).let {
                    if (it.entrySet().isEmpty()) reportObj.child(snakeKey) else it
                }
                val sampleSize = metricObj.number("sampleSize", metricObj.number("sample_size", 0))
                val rawVal = metricObj.double("value", 0.0)
                val isDuration = camelKey == "leadTime" || camelKey == "cycleTime"
                val displayValue = when (camelKey) {
                    "leadTime", "cycleTime" -> formatAnalyticsDuration(rawVal)
                    "velocity" -> String.format(java.util.Locale.US, "%.1f pts", rawVal)
                    else -> "${metricObj.number("value", 0)} tasks"
                }

                IosCard(Modifier.fillMaxWidth()) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(title, style = AppTypography.headline)
                            Text("$sampleSize completed tasks", style = AppTypography.caption1, color = AppColors.textSecondary)
                            if (isDuration) {
                                val p50 = formatAnalyticsDuration(metricObj.double("p50", 0.0))
                                val p90 = formatAnalyticsDuration(metricObj.double("p90", 0.0))
                                Text(
                                    "P50: $p50  ·  P90: $p90",
                                    style = AppTypography.caption2.copy(fontWeight = FontWeight.SemiBold),
                                    color = AppColors.textSecondary
                                )
                            }
                        }
                        Text(
                            displayValue,
                            style = AppTypography.title1,
                            color = AppColors.brandPrimary
                        )
                    }
                }
            }

            item {
                IosCard(Modifier.fillMaxWidth()) {
                    Text("Burndown & Cumulative Flow", style = AppTypography.headline)
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "Remaining story points vs. completed points across ${days}d window",
                        style = AppTypography.caption2,
                        color = AppColors.textSecondary
                    )
                    Spacer(Modifier.height(12.dp))
                    val points = reportObj.list("burndown")
                    if (points.isEmpty()) {
                        Text("No data for this period.", style = AppTypography.caption1, color = AppColors.textSecondary)
                    } else {
                        val color = AppColors.brandPrimary
                        val doneColor = AppColors.statusSuccess
                        val values = points.map {
                            it.double("remainingPoints", it.double("remaining_points", 0.0)).toFloat()
                        }
                        val doneValues = points.map {
                            it.double("completedPoints", it.double("completed_points", 0.0)).toFloat()
                        }
                        Canvas(
                            Modifier
                                .fillMaxWidth()
                                .height(160.dp)
                                .padding(8.dp)
                        ) {
                            val max = (values + doneValues).maxOrNull()?.coerceAtLeast(1f) ?: 1f
                            val path = Path()
                            val donePath = Path()
                            values.forEachIndexed { index, value ->
                                val x = index.toFloat() / (values.size - 1).coerceAtLeast(1) * size.width
                                val y = size.height - value / max * size.height
                                if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
                                drawCircle(color, 3.5.dp.toPx(), Offset(x, y))
                            }
                            doneValues.forEachIndexed { index, value ->
                                val x = index.toFloat() / (doneValues.size - 1).coerceAtLeast(1) * size.width
                                val y = size.height - value / max * size.height
                                if (index == 0) donePath.moveTo(x, y) else donePath.lineTo(x, y)
                            }
                            drawPath(path, color, style = Stroke(2.5.dp.toPx()))
                            drawPath(donePath, doneColor, style = Stroke(2.dp.toPx()))
                        }
                    }
                }
            }

            item {
                val weekly = reportObj.list("weeklyThroughput").ifEmpty { reportObj.list("weekly_throughput") }
                IosCard(Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text("Weekly Throughput", style = AppTypography.headline)
                        if (weekly.isEmpty()) {
                            Text("No weekly throughput recorded for this period.", style = AppTypography.caption1, color = AppColors.textSecondary)
                        } else {
                            val maxTasks = weekly.maxOfOrNull { it.number("completedTasks", it.number("completed_tasks", 0)) }?.coerceAtLeast(1) ?: 1
                            weekly.forEach { w ->
                                val weekStart = w.text("weekStart", w.text("week_start", "")).take(10)
                                val tasksCount = w.number("completedTasks", w.number("completed_tasks", 0))
                                val ptsCount = w.double("completedPoints", w.double("completed_points", 0.0))
                                val ratio = (tasksCount.toFloat() / maxTasks.toFloat()).coerceIn(0f, 1f)
                                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Text("Week of $weekStart", style = AppTypography.caption1)
                                        Text(
                                            String.format(java.util.Locale.US, "%d tasks · %.1f pts", tasksCount, ptsCount),
                                            style = AppTypography.caption2.copy(fontWeight = FontWeight.SemiBold),
                                            color = AppColors.brandPrimary
                                        )
                                    }
                                    LinearProgressIndicator(
                                        progress = { ratio },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(5.dp)
                                            .clip(RoundedCornerShape(3.dp)),
                                        color = AppColors.brandPrimary,
                                        trackColor = AppColors.borderSubtle
                                    )
                                }
                            }
                        }
                    }
                }
            }

            item {
                val sprints = reportObj.list("sprintVelocity").ifEmpty { reportObj.list("sprint_velocity") }
                IosCard(Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text("Sprint Velocity", style = AppTypography.headline)
                        if (sprints.isEmpty()) {
                            Text("No sprints overlap this date range.", style = AppTypography.caption1, color = AppColors.textSecondary)
                        } else {
                            val maxPts = sprints.maxOfOrNull { it.double("completedPoints", it.double("completed_points", 0.0)) }?.coerceAtLeast(1.0) ?: 1.0
                            sprints.forEach { s ->
                                val sName = s.text("sprintName", s.text("sprint_name", "Sprint"))
                                val pts = s.double("completedPoints", s.double("completed_points", 0.0))
                                val tasks = s.number("completedTasks", s.number("completed_tasks", 0))
                                val ratio = (pts / maxPts).toFloat().coerceIn(0f, 1f)
                                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.SpaceBetween
                                    ) {
                                        Text(sName, style = AppTypography.caption1.copy(fontWeight = FontWeight.SemiBold))
                                        Text(
                                            String.format(java.util.Locale.US, "%.1f pts (%d tasks)", pts, tasks),
                                            style = AppTypography.caption2.copy(fontWeight = FontWeight.Bold),
                                            color = AppColors.statusSuccess
                                        )
                                    }
                                    LinearProgressIndicator(
                                        progress = { ratio },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(5.dp)
                                            .clip(RoundedCornerShape(3.dp)),
                                        color = AppColors.statusSuccess,
                                        trackColor = AppColors.borderSubtle
                                    )
                                }
                            }
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

@Composable
private fun ProjectSettingsScreen(vm: AppViewModel, api: ApiClient, projectId: String) {
    val remote = rememberRemote(api, "/api/projects/$projectId/workflow", vm.revision)
    val action = rememberAction()
    var tab by rememberSaveable { mutableStateOf("Statuses") }
    var showCreateStatus by remember { mutableStateOf(false) }
    var showCreateRule by remember { mutableStateOf(false) }

    val bundle = remote.data.obj()
    val workflowVersion = bundle.number("workflowVersion")
    val statuses = bundle.list("statuses").sortedBy { it.double("position") }
    val rules = bundle.list("rules")

    val defaultColor = AppColors.brandPrimary
    val parseHexColor: (String) -> Color = { hex ->
        try {
            Color(android.graphics.Color.parseColor(hex))
        } catch (_: Exception) {
            defaultColor
        }
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp).testTag("list_project_settings"),
        contentPadding = PaddingValues(top = 16.dp, bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Project Settings", style = AppTypography.headline)
                        if (workflowVersion > 0) {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(AppRadius.pill))
                                    .background(AppColors.brandPrimary.copy(alpha = 0.15f))
                                    .padding(horizontal = 8.dp, vertical = 2.dp)
                            ) {
                                Text(
                                    "v$workflowVersion",
                                    style = AppTypography.caption2.copy(fontWeight = FontWeight.Bold),
                                    color = AppColors.brandPrimary
                                )
                            }
                        }
                    }
                    Text(
                        "Manage workflow statuses and automation rules",
                        style = AppTypography.caption1,
                        color = AppColors.textSecondary
                    )
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (tab == "Statuses") {
                        IconButton(
                            onClick = { showCreateStatus = true },
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                                .testTag("btn_create_status")
                        ) {
                            Icon(Icons.Default.Add, "Add status", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                        }
                    } else {
                        IconButton(
                            onClick = { showCreateRule = true },
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                                .testTag("btn_create_rule")
                        ) {
                            Icon(Icons.Default.Add, "Add rule", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            // Segmented tabs: Statuses vs Automations
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                IosFilterChip(
                    title = "Workflow Statuses (${statuses.size})",
                    isSelected = tab == "Statuses",
                    onClick = { tab = "Statuses" },
                    modifier = Modifier.testTag("tab_statuses")
                )
                IosFilterChip(
                    title = "Automations (${rules.size})",
                    isSelected = tab == "Automations",
                    onClick = { tab = "Automations" },
                    modifier = Modifier.testTag("tab_automations")
                )
            }

            Spacer(Modifier.height(8.dp))
            RemoteStatus(remote)
            ActionStatus(action)
        }

        if (tab == "Statuses") {
            if (!remote.loading && remote.error == null && statuses.isEmpty()) {
                item {
                    IosCard(Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier.fillMaxWidth().padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(Icons.Default.Layers, null, tint = AppColors.brandPrimary, modifier = Modifier.size(36.dp))
                            Spacer(Modifier.height(8.dp))
                            Text("No statuses configured", style = AppTypography.headline)
                            Text(
                                "Add custom statuses to track issue progression.",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                        }
                    }
                }
            }

            items(statuses, key = { it.id }) { status ->
                val statusColor = parseHexColor(status.text("color", "#4F46E5"))
                val isLocked = status.flag("isLocked") || status.flag("is_locked")
                val isDefault = status.flag("isDefault") || status.flag("is_default")
                val isFinal = status.flag("isFinal") || status.flag("is_final")
                val category = status.text("category", "backlog")

                IosCard(
                    modifier = Modifier.fillMaxWidth().testTag("status_card_${status.id}")
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.weight(1f)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(14.dp)
                                    .clip(CircleShape)
                                    .background(statusColor)
                            )
                            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        status.text("name"),
                                        style = AppTypography.headline.copy(fontSize = 15.sp),
                                        color = AppColors.textPrimary
                                    )
                                    IosPill(category)
                                    if (isDefault) IosPill("Default")
                                    if (isFinal) IosPill("Final")
                                }
                                if (status.text("legacyStatus").isNotBlank()) {
                                    Text(
                                        "Legacy: ${status.text("legacyStatus")}",
                                        style = AppTypography.caption2,
                                        color = AppColors.textTertiary
                                    )
                                }
                            }
                        }

                        if (isLocked) {
                            Text(
                                "System",
                                style = AppTypography.caption2.copy(fontWeight = FontWeight.Bold),
                                color = AppColors.textTertiary,
                                modifier = Modifier.padding(end = 8.dp)
                            )
                        } else {
                            IconButton(
                                onClick = {
                                    action.run {
                                        api.request("/api/statuses/${status.id}", "DELETE")
                                        vm.changed()
                                    }
                                },
                                modifier = Modifier.testTag("btn_delete_status_${status.id}")
                            ) {
                                Icon(Icons.Default.Delete, "Delete status", tint = AppColors.statusError, modifier = Modifier.size(18.dp))
                            }
                        }
                    }
                }
            }
        } else {
            // Automations Tab
            if (!remote.loading && remote.error == null && rules.isEmpty()) {
                item {
                    IosCard(Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier.fillMaxWidth().padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(Icons.Default.Bolt, null, tint = AppColors.brandPrimary, modifier = Modifier.size(36.dp))
                            Spacer(Modifier.height(8.dp))
                            Text("No automation rules configured", style = AppTypography.headline)
                            Text(
                                "Set up event-triggered rules to automate task transitions.",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                        }
                    }
                }
            }

            items(rules, key = { it.id }) { rule ->
                val isEnabled = rule.flag("isEnabled") || rule.flag("is_enabled")
                val triggerType = rule.text("triggerType", rule.text("trigger_type", "task.status_changed"))
                val actionsJson = rule.text("actionsJson", rule.text("actions_json", ""))

                IosCard(
                    modifier = Modifier.fillMaxWidth().testTag("rule_card_${rule.id}")
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(
                            modifier = Modifier.weight(1f),
                            verticalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Text(
                                rule.text("name"),
                                style = AppTypography.headline.copy(fontSize = 15.sp),
                                color = AppColors.textPrimary
                            )
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                IosPill(triggerType)
                                if (actionsJson.isNotBlank()) {
                                    Text(
                                        actionsJson.take(30),
                                        style = AppTypography.caption2,
                                        color = AppColors.textSecondary
                                    )
                                }
                            }
                        }

                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Switch(
                                checked = isEnabled,
                                onCheckedChange = { checked ->
                                    action.run {
                                        api.request("/api/automation-rules/${rule.id}", "PATCH", json("isEnabled" to checked))
                                        vm.changed()
                                    }
                                },
                                modifier = Modifier.testTag("btn_toggle_rule_${rule.id}")
                            )

                            IconButton(
                                onClick = {
                                    action.run {
                                        api.request("/api/automation-rules/${rule.id}", "DELETE")
                                        vm.changed()
                                    }
                                },
                                modifier = Modifier.testTag("btn_delete_rule_${rule.id}")
                            ) {
                                Icon(Icons.Default.Delete, "Delete rule", tint = AppColors.statusError, modifier = Modifier.size(18.dp))
                            }
                        }
                    }
                }
            }
        }
    }

    if (showCreateStatus) {
        CreateStatusDialog(
            onDismiss = { showCreateStatus = false },
            onSubmit = { payload ->
                action.run {
                    api.request("/api/projects/$projectId/statuses", "POST", payload)
                    vm.changed()
                    showCreateStatus = false
                }
            }
        )
    }

    if (showCreateRule) {
        CreateRuleDialog(
            statuses = statuses,
            onDismiss = { showCreateRule = false },
            onSubmit = { payload ->
                action.run {
                    api.request("/api/projects/$projectId/automation-rules", "POST", payload)
                    vm.changed()
                    showCreateRule = false
                }
            }
        )
    }
}

@Composable
private fun CreateStatusDialog(
    onDismiss: () -> Unit,
    onSubmit: (JsonObject) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var color by remember { mutableStateOf("#4F46E5") }
    var category by remember { mutableStateOf("backlog") }
    var isDefault by remember { mutableStateOf(false) }
    var isFinal by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Layers, null, tint = AppColors.brandPrimary, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(8.dp))
                Text("New Workflow Status", style = AppTypography.headline)
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Status Name *") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("input_status_name")
                )

                OutlinedTextField(
                    value = color,
                    onValueChange = { color = it },
                    label = { Text("Color Hex (#RRGGBB)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("input_status_color")
                )

                Text("Category", style = AppTypography.caption1, color = AppColors.textSecondary)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    listOf("backlog", "active", "completed", "cancelled").forEach { cat ->
                        IosFilterChip(
                            title = cat.replaceFirstChar { it.uppercase() },
                            isSelected = category == cat,
                            onClick = { category = cat },
                            modifier = Modifier.testTag("chip_cat_$cat")
                        )
                    }
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Default entry status", style = AppTypography.body)
                    Switch(checked = isDefault, onCheckedChange = { isDefault = it }, modifier = Modifier.testTag("switch_is_default"))
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Final resolution state", style = AppTypography.body)
                    Switch(checked = isFinal, onCheckedChange = { isFinal = it }, modifier = Modifier.testTag("switch_is_final"))
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (name.isNotBlank()) {
                        onSubmit(
                            json(
                                "name" to name.trim(),
                                "color" to color.trim(),
                                "category" to category,
                                "isDefault" to isDefault,
                                "isFinal" to isFinal
                            )
                        )
                    }
                },
                enabled = name.isNotBlank(),
                modifier = Modifier.testTag("btn_save_status")
            ) {
                Text("Create", color = AppColors.brandPrimary)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = AppColors.textSecondary)
            }
        },
        modifier = Modifier.testTag("dialog_create_status")
    )
}

@Composable
private fun CreateRuleDialog(
    statuses: List<JsonObject>,
    onDismiss: () -> Unit,
    onSubmit: (JsonObject) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var trigger by remember { mutableStateOf("task.status_changed") }
    var triggerToStatusId by remember { mutableStateOf("") }
    var conditionPreset by remember { mutableStateOf("any") }
    var actionType by remember { mutableStateOf("setPriority") }
    var actionPriority by remember { mutableStateOf("medium") }
    var actionStatusId by remember { mutableStateOf(statuses.firstOrNull()?.id ?: "") }
    var actionUserId by remember { mutableStateOf("") }
    var actionLabel by remember { mutableStateOf("") }

    val triggers = listOf(
        "task.status_changed" to "Status Changed",
        "task.created" to "Task Created",
        "task.updated" to "Task Updated",
        "task.priority_changed" to "Priority Changed",
        "task.type_changed" to "Type Changed",
        "sprint.completed" to "Sprint Completed"
    )

    val actions = listOf(
        "setPriority" to "Set Priority",
        "setStatusId" to "Set Status",
        "assignUserId" to "Assign User",
        "addLabel" to "Add Label",
        "removeLabel" to "Remove Label",
        "moveUncompletedToNextSprint" to "Move Uncompleted"
    )

    val triggerConfigJson = if (trigger == "task.status_changed" && triggerToStatusId.isNotBlank()) {
        json("toStatusId" to triggerToStatusId).toString()
    } else null

    val conditionsJson = if (trigger == "sprint.completed") null else when (conditionPreset) {
        "only_bugs" -> "[{\"field\":\"taskType\",\"op\":\"equals\",\"value\":\"bug\"}]"
        "only_critical" -> "[{\"field\":\"priority\",\"op\":\"equals\",\"value\":\"critical\"}]"
        else -> null
    }

    val actionsJson = when (actionType) {
        "setPriority" -> "[{\"type\":\"setPriority\",\"value\":\"$actionPriority\"}]"
        "setStatusId" -> if (actionStatusId.isNotBlank()) "[{\"type\":\"setStatusId\",\"value\":\"$actionStatusId\"}]" else null
        "assignUserId" -> if (actionUserId.isNotBlank()) "[{\"type\":\"assignUserId\",\"value\":\"${actionUserId.trim()}\"}]" else null
        "addLabel" -> if (actionLabel.isNotBlank()) "[{\"type\":\"addLabel\",\"value\":\"${actionLabel.trim()}\"}]" else null
        "removeLabel" -> if (actionLabel.isNotBlank()) "[{\"type\":\"removeLabel\",\"value\":\"${actionLabel.trim()}\"}]" else null
        "moveUncompletedToNextSprint" -> "[{\"type\":\"moveUncompletedToNextSprint\"}]"
        else -> null
    }

    val hasLoopWarning = trigger == "task.status_changed" &&
            actionType == "setStatusId" &&
            triggerToStatusId.isNotBlank() &&
            actionStatusId.isNotBlank() &&
            triggerToStatusId == actionStatusId

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Bolt, null, tint = AppColors.brandPrimary, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(8.dp))
                Text("New Automation Rule", style = AppTypography.headline)
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth().heightIn(max = 450.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text("Quick Rule Presets", style = AppTypography.caption2.copy(fontWeight = FontWeight.Bold), color = AppColors.textSecondary)
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    IosFilterChip("Sprint Rollover", false, onClick = {
                        name = "Rollover Unfinished Sprint Tasks"
                        trigger = "sprint.completed"
                        conditionPreset = "any"
                        actionType = "moveUncompletedToNextSprint"
                    })
                    IosFilterChip("Escalate Bugs", false, onClick = {
                        name = "Auto-Escalate New Bugs"
                        trigger = "task.created"
                        conditionPreset = "only_bugs"
                        actionType = "setPriority"
                        actionPriority = "high"
                    })
                    IosFilterChip("Tag Critical Urgent", false, onClick = {
                        name = "Tag Critical Priority Urgent"
                        trigger = "task.priority_changed"
                        conditionPreset = "only_critical"
                        actionType = "addLabel"
                        actionLabel = "urgent"
                    })
                }

                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Rule Name *") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("input_rule_name")
                )

                Text("When (Trigger)", style = AppTypography.caption1.copy(fontWeight = FontWeight.Bold), color = AppColors.brandPrimary)
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    triggers.forEach { (tKey, tLabel) ->
                        IosFilterChip(
                            title = tLabel,
                            isSelected = trigger == tKey,
                            onClick = { trigger = tKey },
                            modifier = Modifier.testTag("chip_trigger_$tKey")
                        )
                    }
                }

                if (trigger != "sprint.completed") {
                    Text("If Condition (optional)", style = AppTypography.caption2, color = AppColors.textSecondary)
                    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        IosFilterChip("Any Task", conditionPreset == "any", onClick = { conditionPreset = "any" })
                        IosFilterChip("Only Bugs", conditionPreset == "only_bugs", onClick = { conditionPreset = "only_bugs" })
                        IosFilterChip("Only Critical", conditionPreset == "only_critical", onClick = { conditionPreset = "only_critical" })
                    }
                }

                if (trigger == "task.status_changed" && statuses.isNotEmpty()) {
                    Text("To Status (optional)", style = AppTypography.caption2, color = AppColors.textSecondary)
                    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        IosFilterChip("Any", triggerToStatusId.isBlank(), onClick = { triggerToStatusId = "" })
                        statuses.forEach { s ->
                            IosFilterChip(s.text("name"), triggerToStatusId == s.id, onClick = { triggerToStatusId = s.id })
                        }
                    }
                }

                Text("Then (Action)", style = AppTypography.caption1.copy(fontWeight = FontWeight.Bold), color = AppColors.brandPrimary)
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    actions.forEach { (aKey, aLabel) ->
                        IosFilterChip(
                            title = aLabel,
                            isSelected = actionType == aKey,
                            onClick = { actionType = aKey },
                            modifier = Modifier.testTag("chip_action_$aKey")
                        )
                    }
                }

                when (actionType) {
                    "setPriority" -> {
                        Text("Target Priority", style = AppTypography.caption2, color = AppColors.textSecondary)
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            listOf("low", "medium", "high", "critical").forEach { p ->
                                IosFilterChip(p.replaceFirstChar { it.uppercase() }, actionPriority == p, onClick = { actionPriority = p })
                            }
                        }
                    }
                    "setStatusId" -> {
                        Text("Target Status", style = AppTypography.caption2, color = AppColors.textSecondary)
                        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            statuses.forEach { s ->
                                IosFilterChip(s.text("name"), actionStatusId == s.id, onClick = { actionStatusId = s.id })
                            }
                        }
                    }
                    "assignUserId" -> {
                        OutlinedTextField(
                            value = actionUserId,
                            onValueChange = { actionUserId = it },
                            label = { Text("Assignee User UUID") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth().testTag("input_action_user_id")
                        )
                    }
                    "addLabel", "removeLabel" -> {
                        OutlinedTextField(
                            value = actionLabel,
                            onValueChange = { actionLabel = it },
                            label = { Text("Label tag") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth().testTag("input_action_label")
                        )
                    }
                    "moveUncompletedToNextSprint" -> {
                        Text(
                            "Unfinished tasks migrate to the next planned sprint upon completion.",
                            style = AppTypography.caption2,
                            color = AppColors.textSecondary
                        )
                    }
                }

                if (hasLoopWarning) {
                    Text(
                        "Warning: Trigger To Status matches action status (potential loop).",
                        style = AppTypography.caption2.copy(fontWeight = FontWeight.Bold),
                        color = AppColors.statusError
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (name.isNotBlank() && actionsJson != null) {
                        onSubmit(
                            json(
                                "name" to name.trim(),
                                "isEnabled" to true,
                                "triggerType" to trigger,
                                "triggerConfigJson" to triggerConfigJson,
                                "conditionsJson" to conditionsJson,
                                "actionsJson" to actionsJson
                            )
                        )
                    }
                },
                enabled = name.isNotBlank() && actionsJson != null,
                modifier = Modifier.testTag("btn_save_rule")
            ) {
                Text("Create Rule", color = AppColors.brandPrimary)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = AppColors.textSecondary)
            }
        },
        modifier = Modifier.testTag("dialog_create_rule")
    )
}

// MARK: - Integrations: API Keys & Webhooks Screen

@Composable
fun IntegrationsScreen(vm: AppViewModel, api: ApiClient) {
    val apiKeysRemote = rememberRemote(api, "/api/api-keys", vm.revision)
    val webhooksRemote = rememberRemote(api, "/api/webhooks", vm.revision)
    val action = rememberAction()

    var tab by rememberSaveable { mutableStateOf("API Keys") }
    var showCreateKey by remember { mutableStateOf(false) }
    var showCreateWebhook by remember { mutableStateOf(false) }
    var rawKeySecret by remember { mutableStateOf<String?>(null) }
    var testResult by remember { mutableStateOf<Pair<String, String>?>(null) }

    val apiKeys = apiKeysRemote.data.rows()
    val webhooks = webhooksRemote.data.rows()

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp).testTag("list_integrations"),
        contentPadding = PaddingValues(top = 16.dp, bottom = 48.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("Integrations & API", style = AppTypography.headline)
                    Text(
                        "Manage personal API tokens and outgoing webhooks",
                        style = AppTypography.caption1,
                        color = AppColors.textSecondary
                    )
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (tab == "API Keys") {
                        IconButton(
                            onClick = { showCreateKey = true },
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                                .testTag("btn_create_api_key")
                        ) {
                            Icon(Icons.Default.Add, "Generate key", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                        }
                    } else {
                        IconButton(
                            onClick = { showCreateWebhook = true },
                            modifier = Modifier
                                .size(36.dp)
                                .clip(CircleShape)
                                .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                                .testTag("btn_create_webhook")
                        ) {
                            Icon(Icons.Default.Add, "Add webhook", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }

            Spacer(Modifier.height(12.dp))

            // Segmented tabs: API Keys vs Webhooks
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                IosFilterChip(
                    title = "Personal API Keys (${apiKeys.size})",
                    isSelected = tab == "API Keys",
                    onClick = { tab = "API Keys" },
                    modifier = Modifier.testTag("tab_api_keys")
                )
                IosFilterChip(
                    title = "Outgoing Webhooks (${webhooks.size})",
                    isSelected = tab == "Webhooks",
                    onClick = { tab = "Webhooks" },
                    modifier = Modifier.testTag("tab_webhooks")
                )
            }

            Spacer(Modifier.height(8.dp))
            RemoteStatus(if (tab == "API Keys") apiKeysRemote else webhooksRemote)
            ActionStatus(action)
        }

        if (tab == "API Keys") {
            if (!apiKeysRemote.loading && apiKeysRemote.error == null && apiKeys.isEmpty()) {
                item {
                    IosCard(Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier.fillMaxWidth().padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(Icons.Default.VpnKey, null, tint = AppColors.brandPrimary, modifier = Modifier.size(36.dp))
                            Spacer(Modifier.height(8.dp))
                            Text("No API keys generated", style = AppTypography.headline)
                            Text(
                                "Generate API keys for automated tools and scripts.",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                        }
                    }
                }
            }

            items(apiKeys, key = { it.id }) { key ->
                val prefix = key.text("keyPrefix", key.text("key_prefix", ""))
                val isRevoked = key.flag("isRevoked") || key.flag("is_revoked")

                IosCard(
                    modifier = Modifier.fillMaxWidth().testTag("key_card_${key.id}")
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(
                            modifier = Modifier.weight(1f),
                            verticalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    key.text("name"),
                                    style = AppTypography.headline.copy(fontSize = 15.sp),
                                    color = AppColors.textPrimary
                                )
                                if (prefix.isNotBlank()) {
                                    Box(
                                        modifier = Modifier
                                            .clip(RoundedCornerShape(AppRadius.small))
                                            .background(AppColors.surfaceElevated)
                                            .padding(horizontal = 6.dp, vertical = 2.dp)
                                    ) {
                                        Text(
                                            "tf_${prefix}...",
                                            style = AppTypography.caption2.copy(fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace),
                                            color = AppColors.brandPrimary
                                        )
                                    }
                                }
                                if (isRevoked) {
                                    IosPill("Revoked")
                                }
                            }

                            if (key.has("scopes") && key.get("scopes").isJsonArray) {
                                Row(
                                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                                ) {
                                    key.get("scopes").asJsonArray.forEach { sc ->
                                        IosPill(sc.asString)
                                    }
                                }
                            }
                        }

                        if (!isRevoked) {
                            IconButton(
                                onClick = {
                                    action.run {
                                        api.request("/api/api-keys/${key.id}", "DELETE")
                                        vm.changed()
                                    }
                                },
                                modifier = Modifier.testTag("btn_revoke_key_${key.id}")
                            ) {
                                Icon(Icons.Default.Delete, "Revoke key", tint = AppColors.statusError, modifier = Modifier.size(18.dp))
                            }
                        }
                    }
                }
            }
        } else {
            // Webhooks Tab
            if (!webhooksRemote.loading && webhooksRemote.error == null && webhooks.isEmpty()) {
                item {
                    IosCard(Modifier.fillMaxWidth()) {
                        Column(
                            modifier = Modifier.fillMaxWidth().padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Icon(Icons.Default.Language, null, tint = AppColors.brandPrimary, modifier = Modifier.size(36.dp))
                            Spacer(Modifier.height(8.dp))
                            Text("No webhooks configured", style = AppTypography.headline)
                            Text(
                                "Subscribe URLs to receive real-time notifications.",
                                style = AppTypography.caption1,
                                color = AppColors.textSecondary
                            )
                        }
                    }
                }
            }

            items(webhooks, key = { it.id }) { wh ->
                val targetUrl = wh.text("targetUrl", wh.text("target_url", ""))
                val isActive = wh.flag("isActive") || wh.flag("is_active")
                val failureCount = wh.number("failureCount")

                IosCard(
                    modifier = Modifier.fillMaxWidth().testTag("webhook_card_${wh.id}")
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    targetUrl,
                                    style = AppTypography.body.copy(fontWeight = FontWeight.SemiBold, fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace, fontSize = 13.sp),
                                    color = AppColors.textPrimary
                                )
                                if (failureCount > 0) {
                                    Text(
                                        "$failureCount delivery failures",
                                        style = AppTypography.caption2,
                                        color = AppColors.statusError
                                    )
                                }
                            }

                            Row(
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Switch(
                                    checked = isActive,
                                    onCheckedChange = { checked ->
                                        action.run {
                                            api.request("/api/webhooks/${wh.id}", "PATCH", json("isActive" to checked))
                                            vm.changed()
                                        }
                                    },
                                    modifier = Modifier.testTag("btn_toggle_webhook_${wh.id}")
                                )

                                IconButton(
                                    onClick = {
                                        action.run {
                                            api.request("/api/webhooks/${wh.id}/test", "POST")
                                            testResult = wh.id to "Ping delivered (HTTP 200 OK)"
                                        }
                                    },
                                    modifier = Modifier.testTag("btn_test_webhook_${wh.id}")
                                ) {
                                    Icon(Icons.Default.Send, "Test webhook", tint = AppColors.brandPrimary, modifier = Modifier.size(18.dp))
                                }

                                IconButton(
                                    onClick = {
                                        action.run {
                                            api.request("/api/webhooks/${wh.id}", "DELETE")
                                            vm.changed()
                                        }
                                    },
                                    modifier = Modifier.testTag("btn_delete_webhook_${wh.id}")
                                ) {
                                    Icon(Icons.Default.Delete, "Delete webhook", tint = AppColors.statusError, modifier = Modifier.size(18.dp))
                                }
                            }
                        }

                        if (wh.has("events") && wh.get("events").isJsonArray) {
                            Row(
                                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                wh.get("events").asJsonArray.forEach { ev ->
                                    IosPill(ev.asString)
                                }
                            }
                        }

                        if (testResult?.first == wh.id) {
                            Text(
                                testResult?.second ?: "",
                                style = AppTypography.caption2.copy(fontWeight = FontWeight.Bold),
                                color = AppColors.statusSuccess
                            )
                        }
                    }
                }
            }
        }
    }

    if (showCreateKey) {
        CreateApiKeyDialog(
            onDismiss = { showCreateKey = false },
            onSubmit = { payload ->
                action.run {
                    val res = api.request("/api/api-keys", "POST", payload)
                    val rawSecret = res.data.obj().text("rawKey", res.data.obj().text("raw_key", ""))
                    if (rawSecret.isNotBlank()) {
                        rawKeySecret = rawSecret
                    }
                    vm.changed()
                    showCreateKey = false
                }
            }
        )
    }

    rawKeySecret?.let { secret ->
        ApiKeySecretDialog(
            secret = secret,
            onDismiss = { rawKeySecret = null }
        )
    }

    if (showCreateWebhook) {
        CreateWebhookDialog(
            onDismiss = { showCreateWebhook = false },
            onSubmit = { payload ->
                action.run {
                    api.request("/api/webhooks", "POST", payload)
                    vm.changed()
                    showCreateWebhook = false
                }
            }
        )
    }
}

@Composable
private fun CreateApiKeyDialog(
    onDismiss: () -> Unit,
    onSubmit: (JsonObject) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var readScope by remember { mutableStateOf(true) }
    var writeScope by remember { mutableStateOf(true) }
    var adminScope by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.VpnKey, null, tint = AppColors.brandPrimary, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(8.dp))
                Text("Generate Personal API Key", style = AppTypography.headline)
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Key Name *") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("input_key_name")
                )

                Text("Authorization Scopes", style = AppTypography.caption1.copy(fontWeight = FontWeight.Bold), color = AppColors.brandPrimary)

                Row(
                    modifier = Modifier.fillMaxWidth().clickable { readScope = !readScope },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(checked = readScope, onCheckedChange = { readScope = it })
                    Spacer(Modifier.width(8.dp))
                    Text("tasks.read — Read-only task and backlog data", style = AppTypography.caption1)
                }

                Row(
                    modifier = Modifier.fillMaxWidth().clickable { writeScope = !writeScope },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(checked = writeScope, onCheckedChange = { writeScope = it })
                    Spacer(Modifier.width(8.dp))
                    Text("tasks.write — Create and modify tasks", style = AppTypography.caption1)
                }

                Row(
                    modifier = Modifier.fillMaxWidth().clickable { adminScope = !adminScope },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(checked = adminScope, onCheckedChange = { adminScope = it })
                    Spacer(Modifier.width(8.dp))
                    Text("admin — Full workspace administration", style = AppTypography.caption1)
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (name.isNotBlank()) {
                        val scopesArray = com.google.gson.JsonArray().apply {
                            if (readScope) add("tasks.read")
                            if (writeScope) add("tasks.write")
                            if (adminScope) add("admin")
                        }
                        val payload = json("name" to name.trim())
                        payload.add("scopes", scopesArray)
                        onSubmit(payload)
                    }
                },
                enabled = name.isNotBlank(),
                modifier = Modifier.testTag("btn_save_key")
            ) {
                Text("Generate", color = AppColors.brandPrimary)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = AppColors.textSecondary)
            }
        },
        modifier = Modifier.testTag("dialog_create_api_key")
    )
}

@Composable
private fun ApiKeySecretDialog(
    secret: String,
    onDismiss: () -> Unit
) {
    val clipboardManager = LocalClipboardManager.current
    var copied by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Warning, null, tint = AppColors.statusWarning, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(8.dp))
                Text("Save Your API Token", style = AppTypography.headline)
            }
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    "This secret will NEVER be displayed again. Store it securely.",
                    style = AppTypography.caption1,
                    color = AppColors.statusWarning
                )
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(AppRadius.medium))
                        .background(AppColors.surfaceElevated)
                        .padding(12.dp)
                ) {
                    Text(
                        secret,
                        style = AppTypography.body.copy(fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace, fontSize = 12.sp),
                        color = AppColors.statusSuccess,
                        modifier = Modifier.testTag("text_secret_token")
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    clipboardManager.setText(AnnotatedString(secret))
                    copied = true
                },
                modifier = Modifier.testTag("btn_copy_secret")
            ) {
                Text(if (copied) "Copied!" else "Copy Secret", color = AppColors.brandPrimary)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.testTag("btn_dismiss_secret")) {
                Text("Done", color = AppColors.textSecondary)
            }
        },
        modifier = Modifier.testTag("dialog_api_key_secret")
    )
}

@Composable
private fun CreateWebhookDialog(
    onDismiss: () -> Unit,
    onSubmit: (JsonObject) -> Unit
) {
    var targetUrl by remember { mutableStateOf("") }
    var taskCreated by remember { mutableStateOf(true) }
    var taskUpdated by remember { mutableStateOf(true) }
    var sprintClosed by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Language, null, tint = AppColors.brandPrimary, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(8.dp))
                Text("Register Webhook", style = AppTypography.headline)
            }
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth().verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedTextField(
                    value = targetUrl,
                    onValueChange = { targetUrl = it },
                    label = { Text("Target URL *") },
                    placeholder = { Text("https://example.com/webhook") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("input_webhook_url")
                )

                Text("Event Subscriptions", style = AppTypography.caption1.copy(fontWeight = FontWeight.Bold), color = AppColors.brandPrimary)

                Row(
                    modifier = Modifier.fillMaxWidth().clickable { taskCreated = !taskCreated },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(checked = taskCreated, onCheckedChange = { taskCreated = it })
                    Spacer(Modifier.width(8.dp))
                    Text("task.created — New task logged", style = AppTypography.caption1)
                }

                Row(
                    modifier = Modifier.fillMaxWidth().clickable { taskUpdated = !taskUpdated },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(checked = taskUpdated, onCheckedChange = { taskUpdated = it })
                    Spacer(Modifier.width(8.dp))
                    Text("task.updated — Task modified", style = AppTypography.caption1)
                }

                Row(
                    modifier = Modifier.fillMaxWidth().clickable { sprintClosed = !sprintClosed },
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(checked = sprintClosed, onCheckedChange = { sprintClosed = it })
                    Spacer(Modifier.width(8.dp))
                    Text("sprint.closed — Sprint finalized", style = AppTypography.caption1)
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (targetUrl.isNotBlank()) {
                        val eventsArray = com.google.gson.JsonArray().apply {
                            if (taskCreated) add("task.created")
                            if (taskUpdated) add("task.updated")
                            if (sprintClosed) add("sprint.closed")
                        }
                        val payload = json("targetUrl" to targetUrl.trim())
                        payload.add("events", eventsArray)
                        onSubmit(payload)
                    }
                },
                enabled = targetUrl.isNotBlank() && (taskCreated || taskUpdated || sprintClosed),
                modifier = Modifier.testTag("btn_save_webhook")
            ) {
                Text("Register", color = AppColors.brandPrimary)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel", color = AppColors.textSecondary)
            }
        },
        modifier = Modifier.testTag("dialog_create_webhook")
    )
}
