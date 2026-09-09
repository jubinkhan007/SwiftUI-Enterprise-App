package com.acme.taskflow.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.components.*
import com.google.gson.JsonObject
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId

private val priorities = choices("low", "medium", "high", "critical")
private val statuses = choices("todo", "in_progress", "in_review", "done", "cancelled")
private val types = choices("task", "bug", "story", "epic", "subtask")

@Composable
fun TasksScreen(vm: AppViewModel, api: ApiClient, lists: List<Choice>, listId: String, mine: Boolean) {
    var search by rememberSaveable(listId, mine) { mutableStateOf("") }
    var priority by rememberSaveable { mutableStateOf("") }
    var status by rememberSaveable { mutableStateOf("") }
    var mode by rememberSaveable { mutableStateOf("List") }
    var selected by rememberSaveable(listId, mine) { mutableStateOf<String?>(null) }
    var create by remember { mutableStateOf(false) }
    val remote = rememberRemote(api, if (mine) "/api/tasks/assigned" else "/api/tasks", vm.revision,
        query = if (listId.isBlank()) emptyMap() else mapOf("list_id" to listId), paged = true)
    val members = rememberRemote(api, "/api/organizations/${api.orgId}/members")
    val memberChoices = members.data.rows().map { Choice(it.text("user_id"), it.text("display_name")) }
    val tasks = remote.data.rows().filter {
        (search.isBlank() || "${it.text("title")} ${it.text("issue_key")}".contains(search, true)) &&
            (priority.isBlank() || it.text("priority") == priority) && (status.isBlank() || it.text("status") == status)
    }
    if (selected != null) {
        key(selected) { TaskDetailScreen(vm, api, selected!!, lists, memberChoices) { selected = null } }
        return
    }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(search, { search = it }, label = { Text("Search tasks") }, singleLine = true,
                leadingIcon = { Icon(Icons.Default.Search, null) }, modifier = Modifier.weight(1f))
            ToolButton(Icons.Default.Add, "Create task", lists.isNotEmpty()) { create = true }
        }
        Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("List", "Board", "Calendar", "Timeline", "Table").forEach { item -> FilterChip(mode == item, { mode = item }, label = { Text(item) }) }
        }
        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.weight(1f)) { ChoiceMenu("Status", status, listOf(Choice("", "All")) + statuses) { status = it } }
            Box(Modifier.weight(1f)) { ChoiceMenu("Priority", priority, listOf(Choice("", "All")) + priorities) { priority = it } }
        }
        RemoteStatus(remote)
        Text("${tasks.size} tasks", style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(16.dp))
        if (!remote.loading && remote.error == null && tasks.isEmpty()) Text("No tasks found.", modifier = Modifier.padding(24.dp))
        when (mode) {
            "Board" -> LazyRow(contentPadding = PaddingValues(16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                items(statuses) { column ->
                    LazyColumn(Modifier.width(288.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        item { Text("${column.label} (${tasks.count { it.text("status") == column.value }})", style = MaterialTheme.typography.titleMedium) }
                        items(tasks.filter { it.text("status") == column.value }, key = { it.id }) { task ->
                            OutlinedCard(onClick = { selected = task.id }) { TaskRow(task, memberChoices) }
                        }
                    }
                }
            }
            "Calendar" -> TaskCalendar(tasks, onSelect = { selected = it })
            "Timeline" -> LazyColumn(contentPadding = PaddingValues(16.dp)) {
                items(tasks.sortedBy { it.text("start_date", it.text("due_date", "9999")) }, key = { it.id }) { task ->
                    Column(Modifier.clickable { selected = task.id }.padding(vertical = 12.dp)) {
                        Text("${dateLabel(task.text("start_date")).ifBlank { "No start date" }} - ${dateLabel(task.text("due_date")).ifBlank { "No due date" }}", style = MaterialTheme.typography.labelSmall)
                        TaskRow(task, memberChoices)
                    }
                }
            }
            "Table" -> Box(Modifier.horizontalScroll(rememberScrollState())) {
                LazyColumn(Modifier.width(900.dp)) {
                    item { Row(Modifier.padding(16.dp)) { listOf("Task", "Status", "Priority", "Assignee").forEach { Text(it, Modifier.weight(1f), style = MaterialTheme.typography.titleSmall) } } }
                    items(tasks, key = { it.id }) { task ->
                        Row(Modifier.clickable { selected = task.id }.padding(16.dp)) {
                            Text(task.text("title"), Modifier.weight(1f))
                            Text(label(task.text("status")), Modifier.weight(1f))
                            Text(label(task.text("priority")), Modifier.weight(1f))
                            Text(memberChoices.find { it.value == task.text("assignee_id") }?.label ?: "Unassigned", Modifier.weight(1f))
                        }
                        HorizontalDivider()
                    }
                }
            }
            else -> LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
                items(tasks, key = { it.id }) { task -> Box(Modifier.clickable { selected = task.id }) { TaskRow(task, memberChoices) }; HorizontalDivider() }
            }
        }
    }
    if (create) EditorDialog("New task", taskFields(null, lists, memberChoices, listId), { create = false }) {
        it.addProperty("id", java.util.UUID.randomUUID().toString())
        api.request("/api/tasks", "POST", it); vm.changed()
    }
}

@Composable
private fun TaskRow(task: JsonObject, members: List<Choice>) {
    ListItem(headlineContent = { Text(task.text("title"), maxLines = 3, overflow = TextOverflow.Ellipsis) },
        overlineContent = { Text(task.text("issue_key", label(task.text("task_type")))) },
        supportingContent = { Text("${label(task.text("status"))} / ${members.find { it.value == task.text("assignee_id") }?.label ?: "Unassigned"}\n${dateLabel(task.text("due_date")).ifBlank { "No due date" }}") },
        trailingContent = { Text(label(task.text("priority")), style = MaterialTheme.typography.labelSmall,
            color = if (task.text("priority") in listOf("high", "critical")) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary) })
}

@Composable
private fun TaskCalendar(tasks: List<JsonObject>, onSelect: (String) -> Unit) {
    var monthText by rememberSaveable { mutableStateOf(YearMonth.now().toString()) }
    var selectedText by rememberSaveable { mutableStateOf(LocalDate.now().toString()) }
    val month = YearMonth.parse(monthText)
    val selected = LocalDate.parse(selectedText)
    fun due(task: JsonObject): LocalDate? = runCatching { Instant.parse(task.text("due_date")).atZone(ZoneId.systemDefault()).toLocalDate() }.getOrNull()
    LazyColumn(contentPadding = PaddingValues(16.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                ToolButton(Icons.Default.ChevronLeft, "Previous month") { monthText = month.minusMonths(1).toString() }
                Text(month.toString(), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                ToolButton(Icons.Default.ChevronRight, "Next month") { monthText = month.plusMonths(1).toString() }
            }
            Row { listOf("M", "T", "W", "T", "F", "S", "S").forEach { Text(it, Modifier.weight(1f).padding(8.dp)) } }
            val start = month.atDay(1).dayOfWeek.value - 1
            repeat((start + month.lengthOfMonth() + 6) / 7) { week ->
                Row {
                    repeat(7) { day ->
                        val number = week * 7 + day - start + 1
                        Box(Modifier.weight(1f).height(52.dp), contentAlignment = Alignment.Center) {
                            if (number in 1..month.lengthOfMonth()) {
                                val date = month.atDay(number)
                                TextButton(onClick = { selectedText = date.toString() }, contentPadding = PaddingValues(0.dp)) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text(number.toString(), color = if (date == selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface)
                                        Text(if (tasks.any { due(it) == date }) "-" else "", style = MaterialTheme.typography.labelSmall)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            HorizontalDivider()
        }
        items(tasks.filter { due(it) == selected }, key = { it.id }) { task ->
            ListItem(headlineContent = { Text(task.text("title")) }, modifier = Modifier.clickable { onSelect(task.id) })
        }
    }
}

private fun taskFields(task: JsonObject?, lists: List<Choice>, members: List<Choice>, listId: String = ""): List<FormField> = listOf(
    FormField("title", "Title", task?.text("title").orEmpty(), required = true),
    FormField("description", "Description", task?.text("description").orEmpty(), multiline = true),
    FormField("list_id", "List", task?.text("list_id") ?: listId.ifBlank { lists.firstOrNull()?.value.orEmpty() }, required = true, options = lists),
    FormField("priority", "Priority", task?.text("priority") ?: "medium", options = priorities),
    FormField("task_type", "Type", task?.text("task_type") ?: "task", options = types),
    FormField("assignee_id", "Assignee", task?.text("assignee_id").orEmpty(), options = listOf(Choice("", "Unassigned")) + members),
    FormField("story_points", "Story points", task?.text("story_points").orEmpty(), numeric = true),
    FormField("start_date", "Start", task?.text("start_date").orEmpty(), date = true),
    FormField("due_date", "Due", task?.text("due_date").orEmpty(), date = true)
)

@Composable
private fun TaskDetailScreen(vm: AppViewModel, api: ApiClient, taskId: String, lists: List<Choice>, members: List<Choice>, onBack: () -> Unit) {
    BackHandler(onBack = onBack)
    val remote = rememberRemote(api, "/api/tasks/$taskId", vm.revision)
    val task = remote.data.obj()
    var tab by rememberSaveable { mutableStateOf("Activity") }
    var editor by remember { mutableStateOf<String?>(null) }
    var delete by remember { mutableStateOf(false) }
    val action = rememberAction()
    Column(Modifier.fillMaxSize()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ToolButton(Icons.Default.ArrowBack, "Back to tasks", onClick = onBack)
            Text(task.text("issue_key", "Task"), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            ToolButton(Icons.Default.Edit, "Edit task", task.id.isNotEmpty()) { editor = "Edit task" }
            ToolButton(Icons.Default.Delete, "Delete task", task.id.isNotEmpty()) { delete = true }
        }
        RemoteStatus(remote); ActionStatus(action)
        if (task.id.isNotBlank()) {
            val projectId = task.text("project_id")
            val workflow = if (projectId.isNotEmpty()) rememberRemote(api, "/api/projects/$projectId/workflow", vm.revision) else null
            LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                item {
                    Text(task.text("title"), style = MaterialTheme.typography.headlineSmall)
                    Text(task.text("description"), modifier = Modifier.padding(vertical = 12.dp))
                    if (workflow != null) RemoteStatus(workflow)
                    val custom = workflow?.data?.obj()?.list("statuses").orEmpty()
                    ChoiceMenu("Status", if (custom.isEmpty()) task.text("status") else task.text("status_id"),
                        if (custom.isEmpty()) statuses else custom.map { Choice(it.id, it.text("name")) }) { next ->
                        action.run {
                            api.request("/api/tasks/$taskId", "PATCH", json((if (custom.isEmpty()) "status" else "status_id") to next, "expected_version" to task.number("version")), version = task.number("version")); vm.changed()
                        }
                    }
                    Text("${label(task.text("priority"))} priority / ${label(task.text("task_type"))}")
                    Text("Due: ${dateLabel(task.text("due_date")).ifBlank { "Not set" }}", style = MaterialTheme.typography.bodySmall)
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("Activity", "Checklist", "Subtasks", "Time logs").forEach { name -> FilterChip(tab == name, { tab = name }, label = { Text(name) }) }
                    }
                }
                item {
                    val endpoint = when (tab) { "Checklist" -> "checklist"; "Subtasks" -> "subtasks"; "Time logs" -> "time-logs"; else -> "activity" }
                    val section = rememberRemote(api, "/api/tasks/$taskId/$endpoint", vm.revision)
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(tab, Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                            ToolButton(Icons.Default.Add, "Add to $tab") { editor = tab }
                        }
                        RemoteStatus(section)
                        section.data.rows().forEach { item ->
                            when (tab) {
                                "Checklist" -> Row(verticalAlignment = Alignment.CenterVertically) {
                                    Checkbox(item.flag("is_completed"), enabled = !action.busy, onCheckedChange = { checked -> action.run {
                                        api.request("/api/tasks/$taskId/checklist/${item.id}", "PATCH", json("is_completed" to checked)); vm.changed()
                                    } })
                                    Text(item.text("title"), Modifier.weight(1f))
                                    ToolButton(Icons.Default.Delete, "Delete checklist item", !action.busy) { action.run { api.request("/api/tasks/$taskId/checklist/${item.id}", "DELETE"); vm.changed() } }
                                }
                                "Time logs" -> ListItem(headlineContent = { Text("${item.text("hours_logged")} hours / ${item.text("user_display_name")}") }, supportingContent = { Text("${item.text("description")}\n${dateLabel(item.text("logged_at"))}") })
                                "Subtasks" -> TaskRow(item, members)
                                else -> ListItem(headlineContent = { Text(item.text("content", label(item.text("type")))) }, supportingContent = { Text(dateLabel(item.text("created_at"))) })
                            }
                        }
                    }
                }
            }
        }
    }
    editor?.let { title ->
        val fields = when (title) {
            "Edit task" -> taskFields(task, lists, members)
            "Checklist" -> listOf(FormField("title", "Title", required = true))
            "Subtasks" -> listOf(FormField("title", "Title", required = true))
            "Time logs" -> listOf(FormField("hours_logged", "Hours", required = true), FormField("description", "Description"), FormField("logged_at", "Date", Instant.now().toString(), required = true, date = true))
            else -> listOf(FormField("content", "Comment", required = true, multiline = true))
        }
        EditorDialog(title, fields, { editor = null }) { payload ->
            when (title) {
                "Edit task" -> { payload.addProperty("expected_version", task.number("version")); api.request("/api/tasks/$taskId", "PATCH", payload, version = task.number("version")) }
                "Subtasks" -> { payload.addProperty("parent_id", taskId); payload.addProperty("task_type", "subtask"); payload.addProperty("list_id", task.text("list_id")); api.request("/api/tasks", "POST", payload) }
                "Time logs" -> { val hours = payload.text("hours_logged").toDoubleOrNull(); require(hours != null && hours > 0 && hours <= 24) { "Enter hours between 0 and 24." }; payload.addProperty("hours_logged", hours); api.request("/api/tasks/$taskId/time-logs", "POST", payload) }
                "Checklist" -> api.request("/api/tasks/$taskId/checklist", "POST", payload)
                else -> api.request("/api/tasks/$taskId/comments", "POST", payload)
            }
            vm.changed()
        }
    }
    if (delete) ConfirmDialog("Delete task?", task.text("title"), { delete = false }) { api.request("/api/tasks/$taskId", "DELETE"); vm.changed(); onBack() }
}
