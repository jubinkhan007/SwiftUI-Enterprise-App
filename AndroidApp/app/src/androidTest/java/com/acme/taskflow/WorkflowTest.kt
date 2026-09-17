package com.acme.taskflow

import android.app.Application
import android.graphics.Bitmap
import androidx.activity.ComponentActivity
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.test.core.app.ApplicationProvider
import com.acme.taskflow.data.*
import com.acme.taskflow.ui.TaskFlowApp
import com.acme.taskflow.ui.theme.TaskFlowTheme
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.util.concurrent.CopyOnWriteArrayList

class WorkflowTest {
    @get:Rule val compose = createAndroidComposeRule<ComponentActivity>()
    private val app: Application = ApplicationProvider.getApplicationContext()
    private lateinit var vm: AppViewModel
    private lateinit var server: MockWebServer
    private lateinit var endpoint: String
    private val writes = CopyOnWriteArrayList<Pair<String, JsonObject>>()
    private val tasks = CopyOnWriteArrayList<JsonObject>()
    private val sent = CopyOnWriteArrayList<JsonObject>()
    private val checklist = CopyOnWriteArrayList<JsonObject>()
    private val subtasks = CopyOnWriteArrayList<JsonObject>()
    private val relations = CopyOnWriteArrayList<JsonObject>()
    private val views = CopyOnWriteArrayList<JsonObject>()
    private val activities = CopyOnWriteArrayList<JsonObject>()
    private val workspace = json("id" to "org-a", "name" to "Acme Workspace", "subscription_tier" to "pro")

    @Before fun start() {
        writes.clear()
        tasks.clear()
        sent.clear()
        checklist.clear()
        subtasks.clear()
        relations.clear()
        views.clear()
        activities.clear()
        val storage = SessionStore(app, "workflow-test")
        storage.clear()
        vm = AppViewModel(app, storage)
        val description = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc tempus imperdiet velit accumsan fermentum. Sed eleifend vel ex et mi at dignissim. Quisque ut velit vel eros hendrerit aliquet vel et nibh. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Proin a cursus nisl. Cras mollis hendrerit orci quis justo sed dolor iaculis posuere at at lacus. Phasellus eget neque cursus, euismod neque vitae, eleifend diam. Cras bibendum, elit eu porttitor convallis, magna orci molestie dolor, vel fermentum velit diam at mi. Phasellus et vulputate massa. Duis iaculis odio posuere tortor vehicula, eget varius leo lacinia. Vestibulum a orci sed nisl eleifend tristique vitae"
        tasks += json("id" to "task-a", "title" to "Test Task 26/02 01", "status" to "cancelled", "priority" to "medium", "description" to description, "task_type" to "task", "version" to 1, "list_id" to "list-a", "project_id" to "project-a", "assignee_id" to "user-a")
        tasks += json("id" to "task-b", "title" to "Kanban Task", "status" to "todo", "priority" to "high", "description" to "Board item", "task_type" to "task", "version" to 1, "list_id" to "list-a", "project_id" to "project-a", "assignee_id" to "user-a")
        checklist += json("id" to "chk-1", "title" to "Unit Tests Pass", "is_completed" to false)
        subtasks += json("id" to "sub-1", "title" to "Draft RFC", "status" to "todo", "priority" to "high", "parent_id" to "task-a")
        relations += json("id" to "rel-1", "relation_type" to "blocked_by", "related_task_title" to "Auth Backend V2", "relatedTaskId" to "task-b")
        views += json("id" to "view-1", "name" to "Active Sprints", "type" to "list", "is_default" to true, "filters_json" to json("status" to "todo").toString())
        activities += json("id" to "act-1", "type" to "comment", "user_name" to "Alex Chen", "content" to "Initial requirements posted", "created_at" to "2026-09-14T10:00:00Z")
        sent += json(
            "id" to "sent-0",
            "body" to "Hello team! Check https://example.com for specs",
            "sender_id" to "user-a",
            "sender_name" to "Alex Chen",
            "reply_count" to 1,
            "created_at" to "2026-09-14T10:00:00Z"
        )
        server = MockWebServer()
        server.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                val path = request.requestUrl!!.encodedPath
                val payload = runCatching { JsonParser.parseString(request.body.readUtf8()).obj() }.getOrDefault(JsonObject())
                if (request.method != "GET") writes += path to payload
                if (path == "/ws") return MockResponse().setResponseCode(503)
                if (path == "/api/tasks/task-a" && request.method == "PATCH") {
                    return MockResponse().setResponseCode(400).setHeader("Content-Type", "application/json").setBody(json("success" to false, "error" to "Invalid project ID.", "reason" to "Invalid project ID.").toString())
                }
                val data: Any = when {
                    path == "/api/auth/login" -> json("token" to "fixture-token", "user" to json("id" to "user-a", "display_name" to "Alex Chen", "email" to "alex@example.com"))
                    path == "/api/organizations" -> listOf(workspace)
                    path == "/api/me" -> json("user" to json("id" to "user-a"), "role" to "owner", "permissions" to json("permissions" to listOf("members.invite")))
                    path == "/api/hierarchy" -> json("spaces" to listOf(json("space" to json("id" to "space-a", "name" to "Ex1 Space"), "projects" to listOf(json("project" to json("id" to "project-a", "name" to "Mobile"), "lists" to listOf(json("id" to "list-a", "name" to "Release")))))))
                    path == "/api/organizations/org-a/members" -> listOf(json("id" to "member-a", "user_id" to "user-a", "display_name" to "Alex Chen", "email" to "alex@example.com", "role" to "owner"))
                    path == "/api/tasks/move-multiple" && request.method == "POST" -> {
                        val target = payload.text("targetStatus")
                        payload.list("moves").forEach { m ->
                            tasks.firstOrNull { it.id == m.text("taskId") }?.addProperty("status", target)
                        }
                        tasks.toList()
                    }
                    path == "/api/tasks" && request.method == "POST" -> payload.also {
                        it.addProperty("id", "task-new")
                        it.addProperty("status", "todo")
                        tasks += it
                        if (it.text("task_type") == "subtask" || it.has("parent_id") || it.has("parent_task_id")) {
                            subtasks += it
                        }
                    }
                    path == "/api/tasks" || path == "/api/tasks/assigned" -> tasks.toList()
                    path == "/api/tasks/task-a" -> tasks.first()
                    path == "/api/tasks/task-a/checklist" && request.method == "POST" -> payload.also {
                        it.addProperty("id", "chk-${checklist.size + 1}")
                        it.addProperty("is_completed", false)
                        checklist += it
                    }
                    path == "/api/tasks/task-a/checklist" -> checklist.toList()
                    path.startsWith("/api/tasks/task-a/checklist/") && request.method == "PATCH" -> {
                        val id = path.substringAfterLast("/")
                        val item = checklist.firstOrNull { it.id == id }
                        if (payload.has("is_completed")) {
                            item?.addProperty("is_completed", payload.get("is_completed").asBoolean)
                        }
                        item ?: JsonObject()
                    }
                    path.startsWith("/api/tasks/task-a/checklist/") && request.method == "DELETE" -> {
                        val id = path.substringAfterLast("/")
                        checklist.removeIf { it.id == id }
                        json("success" to true)
                    }
                    path == "/api/tasks/task-a/subtasks" -> subtasks.toList()
                    path.startsWith("/api/tasks/sub-") && request.method == "PATCH" -> {
                        val id = path.substringAfterLast("/")
                        val item = subtasks.firstOrNull { it.id == id }
                        if (payload.has("status")) {
                            item?.addProperty("status", payload.get("status").asString)
                        }
                        item ?: JsonObject()
                    }
                    path == "/api/tasks/task-a/relations" && request.method == "GET" -> relations.toList()
                    path == "/api/tasks/task-a/relations" && request.method == "POST" -> payload.also {
                        it.addProperty("id", "rel-${relations.size + 1}")
                        it.addProperty("related_task_title", "Dependency Task")
                        relations += it
                    }
                    path.startsWith("/api/tasks/task-a/relations/") && request.method == "DELETE" -> {
                        val id = path.substringAfterLast("/")
                        relations.removeIf { it.id == id }
                        json("success" to true)
                    }
                    path == "/api/tasks/task-a/activity" -> activities.toList()
                    path == "/api/tasks/task-a/comments" && request.method == "POST" -> payload.also {
                        it.addProperty("id", "act-${activities.size + 1}")
                        it.addProperty("type", "comment")
                        it.addProperty("user_name", "Alex Chen")
                        it.addProperty("created_at", "2026-09-14T10:15:00Z")
                        activities += it
                    }
                    path == "/api/tasks/task-a/time-logs" -> emptyList<JsonObject>()
                    path.startsWith("/api/views") && request.method == "GET" -> views.toList()
                    path.startsWith("/api/views") && request.method == "POST" -> payload.also {
                        it.addProperty("id", "view-${views.size + 1}")
                        views += it
                    }
                    path.startsWith("/api/views/") && request.method == "DELETE" -> {
                        val id = path.substringAfterLast("/")
                        views.removeIf { it.id == id }
                        json("success" to true)
                    }
                    path == "/api/spaces" && request.method == "POST" -> payload.also { it.addProperty("id", "space-new") }
                    path.startsWith("/api/spaces/") && path.endsWith("/projects") && request.method == "POST" -> payload.also { it.addProperty("id", "project-new") }
                    path.startsWith("/api/projects/") && path.endsWith("/lists") && request.method == "POST" -> payload.also { it.addProperty("id", "list-new") }
                    path == "/api/projects/project-a/workflow" -> json("statuses" to listOf(json("id" to "cancelled", "name" to "Cancelled"), json("id" to "todo", "name" to "To Do"), json("id" to "status-done", "name" to "Done")))
                    path == "/api/conversations" -> listOf(json("id" to "conversation-a", "name" to "Mobile team", "type" to "channel", "unread_count" to 2))
                    path == "/api/conversations/conversation-a" -> json("id" to "conversation-a", "name" to "Mobile team")
                    path.endsWith("/draft") -> JsonObject()
                    path == "/api/conversations/conversation-a/messages" && request.method == "POST" -> payload.also {
                        it.addProperty("id", "sent-${sent.size}")
                        it.addProperty("sender_id", "user-a")
                        it.addProperty("sender_name", "Alex Chen")
                        it.addProperty("created_at", "2026-09-14T10:10:00Z")
                        sent += it
                    }
                    path == "/api/conversations/conversation-a/messages" -> sent.toList()
                    path.startsWith("/api/messages/") && path.endsWith("/thread") -> json(
                        "rootMessage" to (sent.firstOrNull() ?: JsonObject()),
                        "replies" to listOf(
                            json("id" to "reply-1", "parent_id" to "sent-0", "body" to "I reviewed the specs!", "sender_id" to "user-a", "sender_name" to "Alex Chen", "created_at" to "2026-09-14T10:05:00Z")
                        )
                    )
                    path.startsWith("/api/messages/") && path.endsWith("/convert-to-task") && request.method == "POST" -> payload.also {
                        it.addProperty("id", "task-converted")
                        it.addProperty("status", "todo")
                        tasks += it
                    }
                    path == "/api/templates" -> listOf(
                        json("id" to "tmpl-1", "name" to "Bug Report", "body" to "Steps to reproduce:\n")
                    )
                    path.endsWith("/scheduled-messages") && request.method == "POST" -> payload.also {
                        it.addProperty("id", "sched-1")
                    }
                    path == "/api/me/scheduled-messages" -> listOf(
                        json("id" to "sched-1", "body" to "Scheduled standup", "scheduled_for" to "2026-09-15T09:00:00Z")
                    )
                    path.startsWith("/api/messages/") && path.endsWith("/remind") && request.method == "POST" -> json("id" to "remind-1")
                    path == "/api/search" || path == "/api/search/files" -> listOf(
                        json("id" to "res-1", "title" to "Mobile team", "subtitle" to "Found message here", "type" to "message")
                    )
                    else -> emptyList<JsonObject>()
                }
                return MockResponse().setHeader("Content-Type", "application/json").setBody(json("success" to true, "data" to data).toString())
            }
        }
        server.start()
        endpoint = server.url("/").toString()
        compose.setContent { TaskFlowTheme { TaskFlowApp(vm) } }
    }

    @After fun stop() {
        compose.runOnIdle { vm.signOut() }
        server.shutdown()
    }

    private fun waitFor(text: String) {
        compose.waitUntil(15000) {
            runCatching {
                compose.onAllNodesWithText(text, substring = true).fetchSemanticsNodes().isNotEmpty()
            }.getOrDefault(false)
        }
    }

    private fun login() {
        compose.runOnIdle { vm.restoreForTesting(json("id" to "user-a", "display_name" to "Alex Chen", "email" to "alex@example.com"), endpoint, "fixture-token") }
        compose.runOnIdle { vm.selectWorkspace(workspace) }
        waitFor("All Tasks")
    }

    private fun screenshot(name: String) {
        runCatching {
            val bitmap = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
            val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext
            val dir = context.getExternalFilesDir(null) ?: File("/sdcard/Download")
            if (!dir.exists()) dir.mkdirs()
            val dest = File(dir, "$name.png")
            dest.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            runCatching {
                val pub = File("/sdcard/Download", "$name.png")
                pub.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            }
        }
    }

    @Test fun signInFieldsAreEditableAndPasswordIsMasked() {
        compose.onAllNodes(hasSetTextAction())[0].performTextClearance()
        compose.onAllNodes(hasSetTextAction())[0].performTextInput("alex@example.com")
        compose.onAllNodes(hasSetTextAction())[1].performTextClearance()
        compose.onAllNodes(hasSetTextAction())[1].performTextInput("fixture-password")
        compose.onNode(hasSetTextAction() and hasText("alex@example.com")).assertExists()
        compose.onNodeWithText("fixture-password").assertDoesNotExist()
        screenshot("auth-phone")
    }

    @Test fun workspaceNavigationMatchesIosApp() {
        login()
        waitFor("Ex1 Space")
        compose.onNodeWithText("Workspace").assertExists()
        compose.onNodeWithText("NAVIGATION").assertExists()
        compose.onNodeWithText("All Tasks").assertExists()
        compose.onNodeWithText("My Tasks").assertExists()
        compose.onNodeWithText("Inbox").assertExists()
        compose.onNodeWithText("Ex1 Space").assertExists()
        screenshot("workspace-phone")
    }

    @Test fun taskDetailsAndAlertMatchIosApp() {
        login()
        compose.onNodeWithText("All Tasks").performClick()
        waitFor("Test Task 26/02 01")
        screenshot("tasks-phone")

        compose.onNodeWithText("Test Task 26/02 01").performClick()
        waitFor("Task Details")
        compose.onNodeWithText("Save").assertExists()
        compose.onAllNodesWithText("Description").assertCountEquals(2)
        screenshot("task-details-phone")

        compose.onNodeWithText("Save").performClick()
        waitFor("Invalid project ID.")
        compose.onNodeWithText("Error").assertExists()
        compose.onNodeWithText("OK").assertExists()
        screenshot("task-details-alert-phone")
    }

    @Test fun taskCreationAndViewSwitching() {
        login()
        compose.onNodeWithText("All Tasks").performClick()
        compose.onNodeWithText("Board").performClick()
        compose.onNodeWithText("Board").assertExists()
        waitFor("Kanban Task")
        // Verify Group By toolbar and WIP limits
        compose.onNodeWithText("Group By:").assertExists()
        compose.onNodeWithText("WIP: 3").assertExists()
        // Verify task move action on Kanban board
        compose.onAllNodes(hasContentDescription("Task options"))[0].performClick()
        compose.onAllNodes(hasText("In Progress")).onLast().performClick()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/tasks/move-multiple" })
        }
        // Test switching Group By to Priority
        compose.onNodeWithText("Status").performClick()
        compose.onAllNodes(hasText("Priority")).onLast().performClick()
        compose.onAllNodesWithText("Critical").assertCountEquals(2)
        compose.onNodeWithText("WIP: 2").assertExists()
        screenshot("board-priority-wip")
        compose.onNodeWithText("List").performClick()
    }

    @Test fun messagesOpenOnPhoneAndSendToSelectedConversation() {
        login()
        compose.onNodeWithText("Messages").performClick()
        assertTrue(compose.onAllNodesWithText("Messages").fetchSemanticsNodes().size >= 2)

        // Open conversation
        compose.onNodeWithText("Mobile team").performClick()
        waitFor("Hello team!")
        compose.onNodeWithText("example.com").assertExists()
        compose.onNode(hasContentDescription("Open link")).assertExists()
        compose.onNodeWithText("1 reply").assertExists()
        screenshot("android_messages_rich")

        // Test Slash command palette appearance on typing "/"
        val input = compose.onNode(hasSetTextAction())
        input.performTextInput("/")
        waitFor("/task")
        compose.onNodeWithText("/remind", substring = true).assertExists()
        screenshot("android_slash_commands")

        // Clear and send a message
        input.performTextClearance()
        input.performTextInput("Checking thread support")
        compose.onNode(hasContentDescription("Send")).performClick()
        waitFor("Checking thread support")
    }

    @Test fun messageThreadsWorkflow() {
        login()
        compose.onNodeWithText("Messages").performClick()
        waitFor("Mobile team")
        compose.onNodeWithText("Mobile team").performClick()
        waitFor("Hello team!")

        // Open thread modal via reply badge
        compose.onNodeWithText("1 reply").performClick()
        waitFor("Thread")
        waitFor("I reviewed the specs!")
        screenshot("android_message_thread")
    }

    @Test fun convertMessageToTaskWorkflow() {
        login()
        compose.onNodeWithText("Messages").performClick()
        waitFor("Mobile team")
        compose.onNodeWithText("Mobile team").performClick()
        waitFor("Hello team!")

        // Open message context menu and convert to task
        compose.onAllNodes(hasContentDescription("Message options"))[0].performClick()
        waitFor("Convert to Task")
        compose.onAllNodes(hasText("Convert to Task")).onLast().performClick()
        waitFor("Target List")
        screenshot("android_convert_to_task")
        compose.onNodeWithText("Create Task").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first.endsWith("/convert-to-task") })
        }
    }

    @Test fun taskSubtasksAndDependenciesWorkflow() {
        login()
        compose.onNodeWithText("All Tasks").performClick()
        waitFor("Test Task 26/02 01")
        compose.onNodeWithText("Test Task 26/02 01").performClick()
        waitFor("Task Details")

        // Scroll to sections row (index 5) so tabs are visible
        compose.onAllNodes(hasScrollToIndexAction())[0].performScrollToIndex(5)
        waitFor("Checklist")

        // 1. Checklist Tab
        compose.onNodeWithText("Checklist").performClick()
        compose.onAllNodes(hasScrollToIndexAction())[0].performScrollToIndex(6)
        waitFor("Unit Tests Pass")
        compose.onNodeWithText("0 of 1 completed (0%)").assertExists()
        // Toggle checklist checkbox
        compose.onAllNodes(isToggleable())[0].performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first.contains("/checklist/chk-1") })
        }

        // 2. Subtasks Tab
        compose.onAllNodes(hasScrollToIndexAction())[0].performScrollToIndex(5)
        compose.onNodeWithText("Subtasks").performClick()
        compose.onAllNodes(hasScrollToIndexAction())[0].performScrollToIndex(6)
        waitFor("Draft RFC")
        compose.onNodeWithText("0 of 1 subtasks completed (0%)").assertExists()
        // Toggle subtask checkbox
        compose.onAllNodes(isToggleable())[0].performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/tasks/sub-1" })
        }
        // Add a new subtask
        compose.onNode(hasContentDescription("Add to Subtasks")).performClick()
        waitFor("Title")
        compose.onAllNodes(hasSetTextAction() and hasText("")).onFirst().performTextInput("Implement Service")
        compose.onAllNodesWithText("Save").onLast().performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/tasks" && it.second.text("title") == "Implement Service" })
        }

        // 3. Dependencies Tab
        compose.onAllNodes(hasScrollToIndexAction())[0].performScrollToIndex(5)
        compose.onNodeWithText("Dependencies").performClick()
        compose.onAllNodes(hasScrollToIndexAction())[0].performScrollToIndex(6)
        waitFor("Blocked by")
        waitFor("Auth Backend V2")
        screenshot("android_task_subtasks_dependencies")
        // Add a dependency
        compose.onNode(hasContentDescription("Add to Dependencies")).performClick()
        waitFor("Related Task ID")
        compose.onAllNodes(hasSetTextAction() and hasText("")).onLast().performTextInput("task-b")
        compose.onAllNodesWithText("Save").onLast().performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/tasks/task-a/relations" })
        }

        // 4. Activity Tab
        compose.onAllNodes(hasScrollToIndexAction())[0].performScrollToIndex(5)
        compose.onNodeWithText("Activity").performClick()
        compose.onAllNodes(hasScrollToIndexAction())[0].performScrollToIndex(6)
        waitFor("Initial requirements posted")
        compose.onAllNodes(hasSetTextAction() and hasText("")).onLast().performTextInput("Great work on RFC @Alex")
        compose.onNode(hasContentDescription("Send")).performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/tasks/task-a/comments" })
        }
    }

    @Test fun savedViewsAndSyncCenterWorkflow() {
        login()
        compose.onNodeWithText("All Tasks").performClick()
        waitFor("Test Task 26/02 01")

        // 1. Saved Views
        compose.onNode(hasContentDescription("Saved views")).performClick()
        waitFor("Saved Views")
        screenshot("android_saved_views_sync_center")

        // Click Save Current View
        compose.onNodeWithText("Save Current View").performClick()
        waitFor("View Name")
        compose.onAllNodes(hasSetTextAction() and hasText("")).onLast().performTextInput("Sprint Priority View")
        compose.onAllNodesWithText("Save").onLast().performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/views" && it.second.text("name") == "Sprint Priority View" })
        }
        // Dismiss Saved Views
        compose.onNode(hasContentDescription("Close")).performClick()
        compose.waitForIdle()

        // 2. Sync Center
        compose.onNode(hasContentDescription("Sync center")).performClick()
        waitFor("Sync Center")
        compose.onNodeWithText("Sync Now").assertExists()
        compose.onNodeWithText("Sync Now").performClick()
        compose.waitForIdle()
        compose.onNodeWithText("Close").performClick()
    }

    @Test fun createHierarchyItemWorkflow() {
        login()
        // Mobile compact workspace has Create (+) in header
        compose.onNode(hasContentDescription("Create")).performClick()
        waitFor("Team")
        waitFor("Project")
        waitFor("List")
        screenshot("android_create_hierarchy_item")

        // Enter Team Name and create
        compose.onAllNodes(hasSetTextAction() and hasText("")).onFirst().performTextInput("Platform Core")
        compose.onAllNodesWithText("Create").onLast().performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/spaces" && it.second.text("name") == "Platform Core" })
        }
    }
}

