package com.acme.taskflow.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.unit.dp
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.acme.taskflow.ui.theme.*
import com.google.gson.JsonObject
import java.time.Instant

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

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Backlog", Modifier.weight(1f), style = AppTypography.largeTitle)
                IconButton(
                    onClick = { create = true },
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                ) {
                    Icon(Icons.Default.Add, "Create sprint", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                }
            }
            Spacer(Modifier.height(8.dp))
            RemoteStatus(sprints)
            ChoiceMenu(
                "Sprint",
                sprint,
                listOf(Choice("", "Backlog")) + sprints.data.rows().map { Choice(it.id, "${it.text("name")} (${label(it.text("status"))})") }
            ) { sprint = it }

            sprints.data.rows().find { it.id == sprint }?.let { item ->
                Spacer(Modifier.height(4.dp))
                Text(
                    "${dateLabel(item.text("start_date"))} → ${dateLabel(item.text("end_date"))}",
                    style = AppTypography.caption1,
                    color = AppColors.brandPrimary
                )
                Spacer(Modifier.height(4.dp))
                ChoiceMenu("Status", item.text("status"), choices("planned", "active", "completed", "closed")) { status ->
                    action.run {
                        api.request("/api/sprints/$sprint", "PATCH", json("status" to status))
                        vm.changed()
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
                    IconButton(onClick = { moving = task }) {
                        Icon(Icons.Default.MoveUp, "Move to sprint", tint = AppColors.brandPrimary)
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
        EditorDialog(
            "Move to sprint",
            listOf(
                FormField(
                    "sprint_id",
                    "Sprint",
                    required = true,
                    options = sprints.data.rows().filter { it.text("status") in listOf("planned", "active") }.map { Choice(it.id, it.text("name")) }
                )
            ),
            { moving = null }
        ) {
            it.addProperty("expected_version", task.number("version"))
            api.request("/api/tasks/${task.id}", "PATCH", it, version = task.number("version"))
            vm.changed()
        }
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
        }
    }
}

@Composable
private fun ReleasesScreen(vm: AppViewModel, api: ApiClient, projectId: String, onTask: (String) -> Unit) {
    val remote = rememberRemote(api, "/api/projects/$projectId/releases", vm.revision)
    var selected by rememberSaveable(projectId) { mutableStateOf("") }
    var create by remember { mutableStateOf(false) }
    var finalize by remember { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Releases", Modifier.weight(1f), style = AppTypography.largeTitle)
                IconButton(
                    onClick = { create = true },
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(AppColors.brandPrimary.copy(alpha = 0.12f))
                ) {
                    Icon(Icons.Default.Add, "Create release", tint = AppColors.brandPrimary, modifier = Modifier.size(20.dp))
                }
            }
            RemoteStatus(remote)
        }

        items(remote.data.rows(), key = { it.id }) { release ->
            IosCard(
                modifier = Modifier.fillMaxWidth(),
                onClick = { selected = release.id }
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(release.text("name"), style = AppTypography.headline)
                        Text(
                            "${label(release.text("status"))} • ${dateLabel(release.text("release_date"))}",
                            style = AppTypography.caption1,
                            color = AppColors.textSecondary
                        )
                    }
                    IosPill(label(release.text("status")), selected = release.text("status") == "released")
                }
            }
        }

        if (selected.isNotBlank()) {
            item {
                val progress = rememberRemote(api, "/api/releases/$selected/progress", vm.revision)
                val issues = rememberRemote(api, "/api/releases/$selected/issues", vm.revision)
                RemoteStatus(progress)
                RemoteStatus(issues)

                IosCard(Modifier.fillMaxWidth()) {
                    Text(
                        "${progress.data.obj().number("done_issues")} / ${progress.data.obj().number("total_issues")} issues complete",
                        style = AppTypography.headline
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "${progress.data.obj().number("critical_bug_count")} critical bugs",
                        style = AppTypography.caption1,
                        color = AppColors.statusError
                    )
                    Spacer(Modifier.height(12.dp))

                    issues.data.rows().forEach { task ->
                        Text(
                            text = "• ${task.text("title")}",
                            style = AppTypography.body,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onTask(task.id) }
                                .padding(vertical = 4.dp)
                        )
                    }

                    if (remote.data.rows().find { it.id == selected }?.text("status") != "released") {
                        Spacer(Modifier.height(12.dp))
                        IosButton(
                            title = "Release",
                            onClick = { finalize = true },
                            modifier = Modifier.fillMaxWidth().height(44.dp)
                        )
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

    if (finalize) {
        ConfirmDialog("Finalize release?", "The release will be locked.", { finalize = false }) {
            api.request("/api/releases/$selected/release", "POST", json("lock" to true))
            vm.changed()
        }
    }
}
