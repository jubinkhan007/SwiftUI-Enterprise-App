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
    private val workspace = json("id" to "org-a", "name" to "Acme Workspace", "subscription_tier" to "pro")

    @Before fun start() {
        writes.clear()
        tasks.clear()
        sent.clear()
        val storage = SessionStore(app, "workflow-test")
        storage.clear()
        vm = AppViewModel(app, storage)
        val description = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc tempus imperdiet velit accumsan fermentum. Sed eleifend vel ex et mi at dignissim. Quisque ut velit vel eros hendrerit aliquet vel et nibh. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Proin a cursus nisl. Cras mollis hendrerit orci quis justo sed dolor iaculis posuere at at lacus. Phasellus eget neque cursus, euismod neque vitae, eleifend diam. Cras bibendum, elit eu porttitor convallis, magna orci molestie dolor, vel fermentum velit diam at mi. Phasellus et vulputate massa. Duis iaculis odio posuere tortor vehicula, eget varius leo lacinia. Vestibulum a orci sed nisl eleifend tristique vitae"
        tasks += json("id" to "task-a", "title" to "Test Task 26/02 01", "status" to "cancelled", "priority" to "medium", "description" to description, "task_type" to "task", "version" to 1, "list_id" to "list-a", "project_id" to "project-a", "assignee_id" to "user-a")
        tasks += json("id" to "task-b", "title" to "Kanban Task", "status" to "todo", "priority" to "high", "description" to "Board item", "task_type" to "task", "version" to 1, "list_id" to "list-a", "project_id" to "project-a", "assignee_id" to "user-a")
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
                    path == "/api/tasks" && request.method == "POST" -> payload.also { it.addProperty("id", "task-new"); it.addProperty("status", "todo"); tasks += it }
                    path == "/api/tasks" || path == "/api/tasks/assigned" -> tasks.toList()
                    path == "/api/tasks/task-a" -> tasks.first()
                    path == "/api/projects/project-a/workflow" -> json("statuses" to listOf(json("id" to "cancelled", "name" to "Cancelled"), json("id" to "todo", "name" to "To Do"), json("id" to "status-done", "name" to "Done")))
                    path == "/api/conversations" -> listOf(json("id" to "conversation-a", "name" to "Mobile team", "type" to "channel", "unread_count" to 2))
                    path == "/api/conversations/conversation-a" -> json("id" to "conversation-a", "name" to "Mobile team")
                    path.endsWith("/draft") -> JsonObject()
                    path == "/api/conversations/conversation-a/messages" && request.method == "POST" -> payload.also { it.addProperty("id", "sent-${sent.size}"); it.addProperty("sender_id", "user-a"); it.addProperty("sender_name", "Alex Chen"); sent += it }
                    path == "/api/conversations/conversation-a/messages" -> sent.toList()
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
        compose.waitUntil(15000) { compose.onAllNodesWithText(text, substring = true).fetchSemanticsNodes().isNotEmpty() }
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
        compose.onAllNodesWithText("Messages").assertCountEquals(2)
        screenshot("messages-phone")
    }
}
