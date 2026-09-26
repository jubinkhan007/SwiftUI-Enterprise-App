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
    private val convMembers = CopyOnWriteArrayList<JsonObject>()
    private val epicChildren = CopyOnWriteArrayList<JsonObject>()
    private val meetings = CopyOnWriteArrayList<JsonObject>()
    private val meetingParticipants = CopyOnWriteArrayList<JsonObject>()
    private val callParticipants = CopyOnWriteArrayList<JsonObject>()
    private val orgMembers = CopyOnWriteArrayList<JsonObject>()
    private val orgInvites = CopyOnWriteArrayList<JsonObject>()
    private val orgJoinRequests = CopyOnWriteArrayList<JsonObject>()
    private val mockNotifications = CopyOnWriteArrayList<JsonObject>()
    private val mockSprints = CopyOnWriteArrayList<JsonObject>()
    private val mockSprintIssues = CopyOnWriteArrayList<JsonObject>()
    private lateinit var callSessionData: JsonObject
    private lateinit var callTicketData: JsonObject
    private lateinit var meetingData: JsonObject
    private lateinit var meetingSummary: JsonObject
    private lateinit var conversationData: JsonObject
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
        convMembers.clear()
        convMembers += json("id" to "cm-1", "user_id" to "user-a", "display_name" to "Alex Chen", "email" to "alex@example.com", "role" to "owner", "status" to "active")
        convMembers += json("id" to "cm-2", "user_id" to "user-b", "display_name" to "Sarah Connor", "email" to "sarah@example.com", "role" to "member", "status" to "active")

        orgMembers.clear()
        orgMembers += listOf(
            json("id" to "member-a", "user_id" to "user-a", "display_name" to "Alex Chen", "email" to "alex@example.com", "role" to "owner"),
            json("id" to "member-b", "user_id" to "user-b", "display_name" to "Sarah Connor", "email" to "sarah@example.com", "role" to "member"),
            json("id" to "member-c", "user_id" to "user-c", "display_name" to "John Wick", "email" to "john@example.com", "role" to "member")
        )
        orgInvites.clear()
        orgInvites += json(
            "id" to "inv-1",
            "email" to "invited@example.com",
            "role" to "member",
            "status" to "pending",
            "expires_at" to "2026-10-01T00:00:00Z"
        )
        orgJoinRequests.clear()
        orgJoinRequests += json(
            "id" to "req-1",
            "user_display_name" to "Neo Anderson",
            "user_email" to "neo@matrix.org",
            "message" to "Requesting access to mobile project",
            "status" to "pending"
        )
        mockNotifications.clear()
        mockNotifications += json(
            "id" to "notif-1",
            "type" to "mention",
            "title" to "",
            "body" to "Alex, please review the latest sprint designs",
            "payload_json" to json("message" to "Alex, please review the latest sprint designs", "actorName" to "Taylor").toString(),
            "read_at" to "",
            "created_at" to "2026-09-23T10:00:00Z"
        )
        mockNotifications += json(
            "id" to "notif-2",
            "type" to "task.assigned",
            "title" to "",
            "body" to "You have been assigned to Auth Backend V2",
            "payload_json" to json("message" to "You have been assigned to Auth Backend V2").toString(),
            "read_at" to "",
            "created_at" to "2026-09-23T09:30:00Z"
        )
        mockNotifications += json(
            "id" to "notif-3",
            "type" to "task.updated",
            "title" to "",
            "body" to "Task PROJ-100 moved to In Progress",
            "payload_json" to json("message" to "Task PROJ-100 moved to In Progress").toString(),
            "read_at" to "2026-09-23T08:00:00Z",
            "created_at" to "2026-09-23T08:00:00Z"
        )

        conversationData = json(
            "id" to "conversation-a",
            "name" to "Mobile team",
            "topic" to "All mobile topics",
            "description" to "Engineering discussions",
            "is_private" to false,
            "is_archived" to false,
            "owner_id" to "user-a",
            "unread_count" to 2,
            "members" to convMembers
        )

        epicChildren.clear()
        epicChildren += json("id" to "child-1", "issue_key" to "PROJ-101", "title" to "Design Specs", "status" to "done", "story_points" to 8, "parent_id" to "epic-1")
        epicChildren += json("id" to "child-2", "issue_key" to "PROJ-102", "title" to "Compose Implementation", "status" to "in_progress", "story_points" to 5, "parent_id" to "epic-1")

        meetingParticipants.clear()
        meetingParticipants += json(
            "id" to "part-1",
            "user_id" to "user-a",
            "display_name" to "Alex Chen",
            "email" to "alex@example.com",
            "role" to "host",
            "join_state" to "in_meeting"
        )
        meetingParticipants += json(
            "id" to "part-2",
            "user_id" to "user-b",
            "display_name" to "Sarah Connor",
            "email" to "sarah@example.com",
            "role" to "attendee",
            "join_state" to "waiting"
        )

        meetingSummary = json(
            "meeting_id" to "meeting-a",
            "source" to "ai",
            "summary_text" to "The team aligned on the mobile 2.0 release roadmap and agreed to conduct lobby security checks.",
            "action_items" to listOf(
                json("id" to "ai-1", "text" to "Deploy lobby service to staging", "due_at" to "2026-09-25T17:00:00Z", "linked_task_id" to "task-a")
            )
        )

        meetingData = json(
            "id" to "meeting-a",
            "title" to "Sprint Planning & Sync",
            "agenda" to "Review sprint backlog, epics, and meeting controls.",
            "description" to "Engineering sprint planning meeting.",
            "status" to "scheduled",
            "scheduled_start_at" to "2026-09-22T10:00:00Z",
            "scheduled_end_at" to "2026-09-22T10:45:00Z",
            "timezone" to "UTC",
            "requires_waiting_room" to true,
            "allow_guests" to false,
            "host_id" to "user-a",
            "host_display_name" to "Alex Chen",
            "my_participant" to json("id" to "part-1", "role" to "host", "join_state" to "in_meeting"),
            "participants" to meetingParticipants
        )

        meetings.clear()
        meetings += meetingData

        callParticipants.clear()
        callParticipants += json(
            "id" to "cp-1",
            "call_session_id" to "call-1",
            "user_id" to "user-a",
            "display_name" to "Alex Chen",
            "role" to "host",
            "status" to "connected",
            "is_audio_muted" to false,
            "is_video_muted" to false,
            "is_screen_sharing" to false
        )
        callParticipants += json(
            "id" to "cp-2",
            "call_session_id" to "call-1",
            "user_id" to "user-b",
            "display_name" to "Sarah Connor",
            "role" to "participant",
            "status" to "connected",
            "is_audio_muted" to true,
            "is_video_muted" to true,
            "is_screen_sharing" to false
        )

        callSessionData = json(
            "id" to "call-1",
            "org_id" to "org-a",
            "conversation_id" to "conversation-a",
            "host_id" to "user-a",
            "status" to "active",
            "room_name" to "room-call-1",
            "has_video" to true,
            "is_locked" to false,
            "provider" to "internal",
            "active_speaker_user_id" to "cp-1",
            "my_participant" to json("id" to "cp-1", "role" to "host"),
            "participants" to callParticipants
        )

        callTicketData = json(
            "session" to callSessionData,
            "token" to json(
                "call_session_id" to "call-1",
                "room_name" to "room-call-1",
                "identity" to "user-a",
                "token" to "mock-call-token",
                "provider" to "internal",
                "url" to "mock://livekit",
                "can_publish" to true,
                "can_subscribe" to true,
                "can_publish_data" to true
            )
        )

        val storage = SessionStore(app, "workflow-test")
        storage.clear()
        vm = AppViewModel(app, storage)
        val description = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc tempus imperdiet velit accumsan fermentum. Sed eleifend vel ex et mi at dignissim. Quisque ut velit vel eros hendrerit aliquet vel et nibh. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Proin a cursus nisl. Cras mollis hendrerit orci quis justo sed dolor iaculis posuere at at lacus. Phasellus eget neque cursus, euismod neque vitae, eleifend diam. Cras bibendum, elit eu porttitor convallis, magna orci molestie dolor, vel fermentum velit diam at mi. Phasellus et vulputate massa. Duis iaculis odio posuere tortor vehicula, eget varius leo lacinia. Vestibulum a orci sed nisl eleifend tristique vitae"
        tasks += json("id" to "task-a", "title" to "Test Task 26/02 01", "status" to "cancelled", "priority" to "medium", "description" to description, "task_type" to "task", "version" to 1, "list_id" to "list-a", "project_id" to "project-a", "assignee_id" to "user-a", "start_date" to "2026-09-15T00:00:00Z", "due_date" to "2026-09-20T00:00:00Z")
        tasks += json("id" to "task-b", "title" to "Kanban Task", "status" to "todo", "priority" to "high", "description" to "Board item", "task_type" to "task", "version" to 1, "list_id" to "list-a", "project_id" to "project-a", "assignee_id" to "user-a", "start_date" to "2026-09-16T00:00:00Z", "due_date" to "2026-09-22T00:00:00Z")
        tasks += json(
            "id" to "epic-1",
            "issue_key" to "PROJ-100",
            "title" to "Mobile 2.0 Redesign",
            "status" to "in_progress",
            "priority" to "high",
            "description" to "Epic for mobile 2.0 architecture overhaul",
            "task_type" to "epic",
            "type" to "epic",
            "version" to 1,
            "list_id" to "list-a",
            "project_id" to "project-a",
            "assignee_id" to "user-a",
            "start_date" to "2026-09-14T00:00:00Z",
            "due_date" to "2026-09-24T00:00:00Z",
            "epic_completed_points" to 8,
            "epic_total_points" to 13,
            "epic_children_done_count" to 1,
            "epic_children_count" to 2
        )
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

        mockSprints.clear()
        mockSprints += json(
            "id" to "sprint-1",
            "project_id" to "project-a",
            "name" to "Sprint 14 - Mobile Parity",
            "status" to "active",
            "start_date" to "2026-09-15T00:00:00Z",
            "end_date" to "2026-09-29T00:00:00Z",
            "capacity" to 20
        )
        mockSprints += json(
            "id" to "sprint-2",
            "project_id" to "project-a",
            "name" to "Sprint 15 - Enterprise Release",
            "status" to "planned",
            "start_date" to "2026-09-30T00:00:00Z",
            "end_date" to "2026-10-14T00:00:00Z",
            "capacity" to 25
        )

        mockSprintIssues.clear()
        mockSprintIssues += json(
            "id" to "task-s1",
            "title" to "LiveKit Calling Bridge",
            "issue_key" to "PROJ-105",
            "status" to "in_progress",
            "priority" to "high",
            "story_points" to 5,
            "project_id" to "project-a",
            "sprint_id" to "sprint-1",
            "version" to 1
        )
        mockSprintIssues += json(
            "id" to "task-s2",
            "title" to "Sync Squashing Parity",
            "issue_key" to "PROJ-106",
            "status" to "todo",
            "priority" to "medium",
            "story_points" to 8,
            "project_id" to "project-a",
            "sprint_id" to "sprint-1",
            "version" to 1
        )

        tasks += json(
            "id" to "task-backlog-1",
            "title" to "Groomed Backlog Story",
            "issue_key" to "PROJ-108",
            "status" to "todo",
            "priority" to "high",
            "story_points" to 3,
            "project_id" to "project-a",
            "version" to 1
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
                    path == "/api/organizations/org-a/members" && request.method == "GET" -> orgMembers.toList()
                    path.startsWith("/api/organizations/org-a/members/") && request.method == "PATCH" -> {
                        val mId = path.substringAfterLast("/")
                        val m = orgMembers.firstOrNull { it.id == mId }
                        if (m != null && payload.has("role")) {
                            m.addProperty("role", payload.text("role"))
                        }
                        m ?: json("success" to true)
                    }
                    path.startsWith("/api/organizations/org-a/members/") && request.method == "DELETE" -> {
                        val mId = path.substringAfterLast("/")
                        orgMembers.removeAll { it.id == mId }
                        json("success" to true)
                    }
                    path == "/api/organizations/org-a/invites" && request.method == "GET" -> orgInvites.toList()
                    path == "/api/organizations/org-a/invites" && request.method == "POST" -> {
                        val newInv = json(
                            "id" to "inv-new",
                            "email" to payload.text("email"),
                            "role" to payload.text("role", "member"),
                            "status" to "pending",
                            "expires_at" to "2026-10-15T00:00:00Z"
                        )
                        orgInvites.add(0, newInv)
                        newInv
                    }
                    path.startsWith("/api/organizations/org-a/invites/") && request.method == "DELETE" -> {
                        val invId = path.substringAfterLast("/")
                        orgInvites.removeAll { it.id == invId }
                        json("success" to true)
                    }
                    path == "/api/organizations/org-a/join-requests" && request.method == "GET" -> orgJoinRequests.toList()
                    path.startsWith("/api/organizations/org-a/join-requests/") && request.method == "POST" -> {
                        val reqId = path.substringAfterLast("/")
                        val req = orgJoinRequests.firstOrNull { it.id == reqId }
                        val act = payload.text("action")
                        if (req != null) {
                            orgJoinRequests.remove(req)
                            if (act == "accept") {
                                orgMembers += json(
                                    "id" to "member-${req.id}",
                                    "user_id" to "user-${req.id}",
                                    "display_name" to req.text("user_display_name"),
                                    "email" to req.text("user_email"),
                                    "role" to "member"
                                )
                            }
                        }
                        json("success" to true, "action" to act)
                    }
                    path == "/api/organizations/search" -> listOf(
                        json("id" to "org-external", "name" to "External Acme Org", "slug" to "external-acme")
                    )
                    path.startsWith("/api/organizations/") && path.endsWith("/join") && request.method == "POST" -> json("success" to true, "message" to "Join request submitted")
                    path.startsWith("/api/organizations/invites/") && path.endsWith("/accept") && request.method == "POST" -> json("success" to true, "message" to "Invite accepted")
                    path == "/api/organizations/org-a" -> json("id" to "org-a", "name" to "Acme Workspace", "subscription_tier" to "free", "member_count" to 3)
                    path == "/api/org/billing/checkout" && request.method == "POST" -> json("url" to "https://checkout.stripe.com/c/pay/cs_test_mock_123")
                    path == "/api/org/billing/portal" && request.method == "POST" -> json("url" to "https://billing.stripe.com/p/session/portal_test_mock_123")
                    path.endsWith("/sprints") && request.method == "GET" -> mockSprints.toList()
                    path.endsWith("/sprints") && request.method == "POST" -> {
                        val newS = json(
                            "id" to "sprint-${mockSprints.size + 1}",
                            "name" to payload.text("name"),
                            "status" to "planned",
                            "start_date" to payload.text("start_date"),
                            "end_date" to payload.text("end_date"),
                            "capacity" to if (payload.has("capacity")) payload.number("capacity") else 20
                        )
                        mockSprints += newS
                        newS
                    }
                    path.endsWith("/backlog") && request.method == "GET" -> {
                        tasks.filter { it.id == "task-backlog-1" }
                    }
                    path.contains("/sprints/") && path.endsWith("/issues") && request.method == "GET" -> mockSprintIssues.toList()
                    path.startsWith("/api/sprints/") && request.method == "PATCH" -> {
                        val sId = path.substringAfterLast("/")
                        val s = mockSprints.firstOrNull { it.id == sId }
                        if (s != null && payload.has("status")) {
                            s.addProperty("status", payload.text("status"))
                        }
                        s ?: json("success" to true)
                    }
                    path.startsWith("/api/tasks/") && request.method == "PATCH" -> {
                        val tId = path.substringAfterLast("/")
                        val t = tasks.firstOrNull { it.id == tId } ?: mockSprintIssues.firstOrNull { it.id == tId }
                        if (t != null) {
                            if (payload.has("sprint_id")) {
                                if (payload.get("sprint_id").isJsonNull) {
                                    t.remove("sprint_id")
                                } else {
                                    t.addProperty("sprint_id", payload.text("sprint_id"))
                                }
                            }
                            if (payload.has("status")) t.addProperty("status", payload.text("status"))
                            t.addProperty("version", (if (t.has("version")) t.number("version") else 1) + 1)
                        }
                        t ?: json("id" to tId, "success" to true)
                    }
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
                    path == "/api/tasks/task-a" -> tasks.first { it.id == "task-a" }
                    path == "/api/tasks/epic-1" -> tasks.first { it.id == "epic-1" }
                    path == "/api/tasks/epic-1/subtasks" -> epicChildren.toList()
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
                    path == "/api/conversations" -> listOf(conversationData)
                    path == "/api/conversations/conversation-a" && request.method == "GET" -> conversationData
                    path == "/api/conversations/conversation-a" && request.method == "PUT" -> {
                        if (payload.has("name")) conversationData.addProperty("name", payload.text("name"))
                        if (payload.has("topic")) conversationData.addProperty("topic", payload.text("topic"))
                        if (payload.has("description")) conversationData.addProperty("description", payload.text("description"))
                        if (payload.has("is_private")) conversationData.addProperty("is_private", payload.get("is_private").asBoolean)
                        conversationData
                    }
                    path == "/api/conversations/conversation-a/members" && request.method == "POST" -> {
                        convMembers += json("id" to "cm-3", "user_id" to "user-c", "display_name" to "John Wick", "email" to "john@example.com", "role" to "member", "status" to "active")
                        conversationData.add("members", com.google.gson.Gson().toJsonTree(convMembers))
                        conversationData
                    }
                    path.startsWith("/api/conversations/conversation-a/members/") && request.method == "DELETE" -> {
                        val memberId = path.substringAfterLast("/")
                        convMembers.removeIf { it.id == memberId || it.text("user_id") == memberId }
                        conversationData.add("members", com.google.gson.Gson().toJsonTree(convMembers))
                        conversationData
                    }
                    path == "/api/conversations/conversation-a/archive" && request.method == "POST" -> {
                        conversationData.addProperty("is_archived", true)
                        conversationData
                    }
                    path == "/api/conversations/conversation-a" && request.method == "DELETE" -> {
                        json("success" to true)
                    }
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
                    path == "/api/meetings" && request.method == "GET" -> meetings.toList()
                    path == "/api/meetings" && request.method == "POST" -> payload.also {
                        it.addProperty("id", "meeting-new-${meetings.size + 1}")
                        it.addProperty("host_id", "user-a")
                        it.addProperty("host_display_name", "Alex Chen")
                        it.addProperty("status", "scheduled")
                        meetings += it
                    }
                    path == "/api/meetings/meeting-a" && request.method == "GET" -> {
                        meetingData.add("participants", com.google.gson.Gson().toJsonTree(meetingParticipants))
                        meetingData
                    }
                    path == "/api/meetings/meeting-a/notes" -> emptyList<JsonObject>()
                    path == "/api/meetings/meeting-a/join" && request.method == "POST" -> json(
                        "ticket_id" to "ticket-1",
                        "join_state" to "waiting",
                        "token" to "join-token-123"
                    )
                    path == "/api/meetings/meeting-a/leave" && request.method == "POST" -> json("success" to true)
                    path == "/api/meetings/meeting-a/end" && request.method == "POST" -> {
                        meetingData.addProperty("status", "ended")
                        json("success" to true)
                    }
                    path == "/api/meetings/meeting-a/participants/part-2/admit" && request.method == "POST" -> {
                        meetingParticipants.firstOrNull { it.id == "part-2" }?.addProperty("join_state", "in_meeting")
                        json("success" to true)
                    }
                    path == "/api/meetings/meeting-a/participants/part-2/deny" && request.method == "POST" -> {
                        meetingParticipants.firstOrNull { it.id == "part-2" }?.addProperty("join_state", "denied")
                        json("success" to true)
                    }
                    path.startsWith("/api/meetings/meeting-a/participants/") && path.endsWith("/role") && request.method == "PUT" -> {
                        val pId = path.substringBefore("/role").substringAfterLast("/")
                        val role = payload.text("role")
                        meetingParticipants.firstOrNull { it.id == pId }?.addProperty("role", role)
                        json("success" to true)
                    }
                    path == "/api/meetings/meeting-a/summary" && request.method == "GET" -> meetingSummary
                    path == "/api/meetings/meeting-a/summary" && request.method == "POST" -> {
                        meetingSummary.addProperty("summary_text", "Regenerated AI Summary: Key architectural decisions ratified.")
                        meetingSummary.addProperty("source", "ai-regenerated")
                        meetingSummary
                    }
                    path == "/api/meetings/meeting-a/summary/action-items" && request.method == "POST" -> {
                        val currentItems = meetingSummary.list("action_items").toMutableList()
                        currentItems.add(json(
                            "id" to "ai-${currentItems.size + 1}",
                            "text" to payload.text("text"),
                            "due_at" to "2026-09-30T18:00:00Z"
                        ))
                        meetingSummary.add("action_items", com.google.gson.Gson().toJsonTree(currentItems))
                        json("success" to true)
                    }
                    path == "/api/calls/initiate" && request.method == "POST" -> {
                        callSessionData.add("participants", com.google.gson.Gson().toJsonTree(callParticipants))
                        callTicketData.add("session", callSessionData)
                        callTicketData
                    }
                    path == "/api/calls/call-1" && request.method == "GET" -> {
                        callSessionData.add("participants", com.google.gson.Gson().toJsonTree(callParticipants))
                        callSessionData
                    }
                    path == "/api/calls/call-incoming-test/accept" && request.method == "POST" -> {
                        callSessionData.add("participants", com.google.gson.Gson().toJsonTree(callParticipants))
                        callTicketData.add("session", callSessionData)
                        callTicketData
                    }
                    path == "/api/calls/call-incoming-test/decline" && request.method == "POST" -> json("success" to true)
                    path == "/api/calls/call-1/leave" && request.method == "POST" -> json("success" to true)
                    path == "/api/calls/call-1/end" && request.method == "POST" -> {
                        callSessionData.addProperty("status", "ended")
                        json("success" to true)
                    }
                    path == "/api/calls/call-1/state" && request.method == "PUT" -> {
                        if (payload.has("is_audio_muted")) {
                            callParticipants.firstOrNull { it.id == "cp-1" }?.addProperty("is_audio_muted", payload.flag("is_audio_muted"))
                        }
                        if (payload.has("is_video_muted")) {
                            callParticipants.firstOrNull { it.id == "cp-1" }?.addProperty("is_video_muted", payload.flag("is_video_muted"))
                        }
                        json("success" to true)
                    }
                    path == "/api/calls/call-1/admin" && request.method == "POST" -> {
                        val action = payload.text("action")
                        val targetId = payload.text("target_participant_id")
                        when (action) {
                            "lock_room" -> callSessionData.addProperty("is_locked", true)
                            "unlock_room" -> callSessionData.addProperty("is_locked", false)
                            "mute_remote_audio" -> callParticipants.firstOrNull { it.id == targetId }?.addProperty("is_audio_muted", true)
                            "mute_remote_video" -> callParticipants.firstOrNull { it.id == targetId }?.addProperty("is_video_muted", true)
                            "promote_to_presenter" -> callParticipants.firstOrNull { it.id == targetId }?.addProperty("role", "presenter")
                            "demote_from_presenter" -> callParticipants.firstOrNull { it.id == targetId }?.addProperty("role", "participant")
                            "eject" -> callParticipants.removeIf { it.id == targetId }
                        }
                        callSessionData.add("participants", com.google.gson.Gson().toJsonTree(callParticipants))
                        callSessionData
                    }
                    path == "/api/notifications" && request.method == "GET" -> {
                        val unreadQuery = request.requestUrl?.queryParameter("unread")?.toBoolean() ?: false
                        if (unreadQuery) {
                            mockNotifications.filter { it.text("read_at").isBlank() }
                        } else {
                            mockNotifications
                        }
                    }
                    path.startsWith("/api/notifications/") && path.endsWith("/read") && request.method == "POST" -> {
                        val id = path.removePrefix("/api/notifications/").removeSuffix("/read")
                        mockNotifications.firstOrNull { it.id == id }?.addProperty("read_at", "2026-09-23T11:00:00Z")
                        json("success" to true)
                    }
                    path == "/api/notifications/mark-all-read" && request.method == "POST" -> {
                        mockNotifications.forEach { it.addProperty("read_at", "2026-09-23T11:00:00Z") }
                        json("success" to true)
                    }
                    path.startsWith("/api/conversations/") && path.endsWith("/preferences") && request.method == "PATCH" -> {
                        json("success" to true, "notification_preference" to payload.text("notification_preference", "all"), "is_muted" to payload.flag("is_muted"))
                    }
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
            runCatching { androidx.test.espresso.Espresso.closeSoftKeyboard() }
            Thread.sleep(350)
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
        compose.onNodeWithTag("input_save_view_name").performTextInput("Sprint Priority View")
        compose.onNodeWithTag("btn_save_view_confirm").performClick()
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

    @Test fun epicDashboardAndRoadmapTimelineWorkflow() {
        login()
        compose.onNodeWithText("All Tasks").performClick()
        waitFor("Test Task 26/02 01")

        // 1. Switch to Timeline view
        compose.onNodeWithTag("mode_chips").performScrollToIndex(4)
        compose.waitForIdle()
        compose.onNodeWithTag("chip_Timeline").performClick()
        compose.waitForIdle()
        waitFor("Tasks")
        waitFor("Kanban Task")
        screenshot("android_timeline_gantt")

        // 2. Switch to Epics view
        compose.onNodeWithTag("mode_chips").performScrollToIndex(5)
        compose.waitForIdle()
        compose.onNodeWithTag("chip_Epics").performClick()
        compose.waitForIdle()
        waitFor("Mobile 2.0 Redesign")
        waitFor("Points: 8 / 13")
        waitFor("Issues: 1 / 2")

        // 3. Open Epic Detail Dashboard Modal
        compose.onNodeWithText("Mobile 2.0 Redesign").performClick()
        compose.waitForIdle()
        waitFor("Epic Dashboard")
        waitFor("Child Issues")
        waitFor("Design Specs")
        waitFor("Compose Implementation")
        waitFor("8 pts")
        screenshot("android_epic_dashboard")

        // Dismiss modal
        compose.onNode(hasContentDescription("Close")).performClick()
        compose.waitForIdle()

        // 4. Open Epic task detail directly and verify Epic Dashboard button in top bar
        compose.onNodeWithTag("mode_chips").performScrollToIndex(0)
        compose.waitForIdle()
        compose.onNodeWithTag("chip_List").performClick()
        compose.waitForIdle()
        waitFor("Mobile 2.0 Redesign")
        compose.onNodeWithText("Mobile 2.0 Redesign").performClick()
        waitFor("Task Details")
        compose.onNodeWithText("Epic Dashboard").performClick()
        waitFor("Child Issues")
        compose.onNode(hasContentDescription("Close")).performClick()
    }

    @Test fun channelSettingsAndMemberManagementWorkflow() {
        login()
        compose.onNodeWithText("Messages").performClick()
        waitFor("Mobile team")
        compose.onNodeWithText("Mobile team").performClick()
        waitFor("Alex Chen")

        // Open Channel Settings
        compose.onNode(hasContentDescription("Settings")).performClick()
        waitFor("Channel Settings")
        waitFor("Metadata")
        screenshot("android_channel_settings_members")

        // 1. Edit Topic and save
        compose.onNode(hasSetTextAction() and hasText("All mobile topics")).performTextReplacement("Release 2.0 Discussion Hub")
        compose.onNodeWithText("Save Changes").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/conversations/conversation-a" && it.second.text("topic") == "Release 2.0 Discussion Hub" })
        }

        // 2. Add Member: scroll to Add Member, choose from dropdown and click Add Selected Member
        compose.onNodeWithTag("channel_settings_list").performScrollToIndex(2)
        compose.onNodeWithText("Select Member: Choose").performClick()
        waitFor("John Wick")
        compose.onNodeWithText("John Wick").performClick()
        compose.onNodeWithText("Add Selected Member").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/conversations/conversation-a/members" })
        }

        // 3. Remove Member: scroll to Members, click Remove on Sarah Connor
        compose.onNodeWithTag("channel_settings_list").performScrollToIndex(1)
        waitFor("Remove")
        compose.onAllNodesWithText("Remove").onFirst().performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first.startsWith("/api/conversations/conversation-a/members/") })
        }

        // 4. Archive Channel: scroll to Lifecycle, click Archive Channel
        compose.onNodeWithTag("channel_settings_list").performScrollToIndex(3)
        waitFor("Archive Channel")
        compose.onNodeWithText("Archive Channel").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/conversations/conversation-a/archive" })
        }
    }

    @Test fun scheduleMeetingWithRecurrenceAndWaitingRoomWorkflow() {
        login()
        compose.onNodeWithText("Meetings").performClick()
        waitFor("Meetings")
        waitFor("Sprint Planning & Sync")
        screenshot("android_meetings_list")

        // Open Schedule Meeting Sheet
        compose.onNodeWithTag("btn_schedule_meeting").performClick()
        waitFor("New Meeting")
        waitFor("Details")
        screenshot("android_schedule_meeting_sheet")

        // Fill Title
        compose.onAllNodes(hasSetTextAction()).onFirst().performTextInput("All-Hands Engineering Review")

        // Scroll to Member Selection and pick Sarah Connor
        compose.onNodeWithTag("schedule_meeting_list").performScrollToIndex(2)
        waitFor("Sarah Connor")
        compose.onNodeWithText("Sarah Connor").performClick()

        // Scroll to Recurrence and Settings, then pick Weekly
        compose.onNodeWithTag("schedule_meeting_list").performScrollToIndex(4)
        waitFor("Recurrence")
        screenshot("android_schedule_meeting_sheet_recurrence")
        compose.onNodeWithText("Weekly").performClick()

        // Submit Schedule Meeting
        compose.onNodeWithTag("btn_submit_meeting").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/meetings" && it.second.text("title") == "All-Hands Engineering Review" })
        }
    }

    @Test fun meetingLobbyWaitingRoomAndHostControlsWorkflow() {
        login()
        compose.onNodeWithText("Meetings").performClick()
        waitFor("Sprint Planning & Sync")

        // Open Meeting Detail
        compose.onNodeWithTag("meeting_card_meeting-a").performClick()
        waitFor("Sprint Planning & Sync")
        waitFor("Join Meeting")
        waitFor("Host Panel")
        screenshot("android_meeting_detail")

        // 1. Pre-Join Lobby
        compose.onNodeWithTag("btn_join_meeting").performClick()
        waitFor("Lobby")
        waitFor("Camera off")
        screenshot("android_meeting_lobby")

        // Toggle camera & mic
        compose.onNodeWithTag("btn_lobby_cam").performClick()
        waitFor("Camera preview active")
        compose.onNodeWithTag("btn_lobby_mic").performClick()

        // Click Join meeting from lobby -> enters waiting room
        compose.onNodeWithTag("btn_lobby_join").performClick()
        waitFor("Waiting for host…")
        screenshot("android_waiting_room")

        // Leave waiting room
        compose.onNodeWithTag("btn_leave_waiting_room").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/meetings/meeting-a/leave" })
        }

        // 2. Open Host Controls Panel
        compose.onNodeWithTag("btn_host_panel").performClick()
        waitFor("Host Controls")
        waitFor("Waiting room (1)")
        waitFor("Admit")
        compose.waitForIdle()
        screenshot("android_host_controls_panel")

        // Admit Sarah Connor
        compose.onNodeWithTag("btn_admit_part-2").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/meetings/meeting-a/participants/part-2/admit" })
        }

        // Change Alex Chen role
        compose.onAllNodesWithText("Alex Chen").onLast().performClick()
        waitFor("Change Role:")
        compose.onNodeWithText("Co-host").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first.endsWith("/role") && it.second.text("role") == "co_host" })
        }

        // End meeting for all
        compose.onNodeWithTag("btn_end_meeting_for_all").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/meetings/meeting-a/end" })
        }
    }

    @Test fun meetingSummaryAndActionItemsWorkflow() {
        login()
        compose.onNodeWithText("Meetings").performClick()
        waitFor("Sprint Planning & Sync")

        // Open Meeting Detail
        compose.onNodeWithTag("meeting_card_meeting-a").performClick()
        waitFor("Sprint Planning & Sync")

        // Open Summary Modal
        compose.onNodeWithTag("btn_view_summary").performClick()
        waitFor("Meeting Summary")
        waitFor("Summary")
        waitFor("The team aligned on the mobile 2.0 release roadmap")
        waitFor("Deploy lobby service to staging")
        screenshot("android_meeting_summary_ai")

        // Regenerate Summary
        compose.onNodeWithTag("btn_regenerate_summary").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/meetings/meeting-a/summary" })
        }

        // Add Action Item
        compose.onAllNodes(hasSetTextAction()).onLast().performTextInput("Finalize security review for waiting room")
        compose.onNodeWithTag("btn_add_action_item").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/meetings/meeting-a/summary/action-items" && it.second.text("text") == "Finalize security review for waiting room" })
        }

        // Close modal
        compose.onNodeWithText("Done").performClick()
        compose.waitForIdle()
    }

    @Test fun callInitiationAndInCallControlsWorkflow() {
        login()
        compose.onNodeWithTag("nav_item_calls").performScrollTo().performClick()
        waitFor("Calls")
        waitFor("Mobile team")

        // Start video call on conversation-a
        compose.onNodeWithTag("btn_start_video_call_conversation-a").performClick()
        waitFor("2 on the call")
        waitFor("Connected")
        waitFor("Speaking")
        waitFor("Alex Chen")
        waitFor("Sarah Connor")
        screenshot("android_call_participant_grid")

        // Toggle Mic
        compose.onNodeWithTag("btn_call_mic").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/calls/call-1/state" && it.second.has("is_audio_muted") })
        }

        // Toggle Camera
        compose.onNodeWithTag("btn_call_cam").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/calls/call-1/state" && it.second.has("is_video_muted") })
        }
        screenshot("android_call_controls_dock")

        // Hang up call
        compose.onNodeWithTag("btn_call_hangup").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/calls/call-1/end" || it.first == "/api/calls/call-1/leave" })
        }
    }

    @Test fun callHostControlsAndRoomLockWorkflow() {
        login()
        compose.onNodeWithTag("nav_item_calls").performScrollTo().performClick()
        waitFor("Calls")

        // Start call
        compose.onNodeWithTag("btn_start_video_call_conversation-a").performClick()
        waitFor("2 on the call")

        // Open Host Controls
        compose.onNodeWithTag("btn_call_host").performClick()
        waitFor("Host controls")
        waitFor("Lock room (block new joiners)")
        waitFor("Participants (2)")
        waitFor("Mute mic")
        screenshot("android_call_host_controls")

        // Toggle Lock Room switch
        compose.onNodeWithTag("switch_lock_room").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/calls/call-1/admin" && it.second.text("action") == "lock_room" })
        }

        // Mute remote participant mic
        compose.onNodeWithTag("btn_mute_mic_cp-2").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/calls/call-1/admin" && it.second.text("action") == "mute_remote_audio" })
        }

        // Promote participant to presenter
        compose.onNodeWithTag("btn_promote_cp-2").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/calls/call-1/admin" && it.second.text("action") == "promote_to_presenter" })
        }

        // Eject remote participant
        compose.onNodeWithTag("btn_eject_cp-2").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/calls/call-1/admin" && it.second.text("action") == "eject" })
        }

        // Close host controls
        compose.onNodeWithTag("btn_done_host_controls").performClick()
        compose.waitForIdle()

        // Hang up
        compose.onNodeWithTag("btn_call_hangup").performClick()
    }

    @Test fun incomingCallAcceptWorkflow() {
        login()
        compose.onNodeWithTag("nav_item_calls").performScrollTo().performClick()
        waitFor("Calls")

        // Simulate incoming call
        compose.onNodeWithTag("btn_trigger_incoming_call").performClick()
        waitFor("Incoming call…")
        waitFor("Sarah Connor")
        screenshot("android_call_incoming_modal")

        // Accept call
        compose.onNodeWithTag("btn_accept_call").performClick()
        waitFor("2 on the call")
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/calls/call-incoming-test/accept" })
        }

        // Hang up
        compose.onNodeWithTag("btn_call_hangup").performClick()
        compose.waitForIdle()
    }

    @Test fun teamMembersAndInviteWorkflow() {
        login()
        // Navigate to Team
        compose.onNodeWithTag("nav_item_team").performScrollTo().performClick()
        waitFor("Team")
        waitFor("Alex Chen")
        waitFor("Sarah Connor")
        screenshot("android_team_members")

        // Open Invite Member Modal
        compose.onNodeWithTag("btn_invite_member").performClick()
        waitFor("Invite Member")
        compose.onNodeWithTag("tf_invite_email").performTextInput("newhire@example.com")
        compose.onNodeWithTag("chip_role_admin").performClick()
        screenshot("android_team_invite_sheet")

        // Send invite
        compose.onNodeWithTag("btn_send_invite").performClick()
        compose.waitForIdle()

        // Switch to Invites tab
        compose.onNodeWithTag("team_tab_1").performClick()
        waitFor("newhire@example.com")
        waitFor("invited@example.com")
        screenshot("android_team_invites_tab")

        // Copy Invite ID
        compose.onNodeWithTag("btn_copy_invite_inv-1").performClick()
        compose.waitForIdle()
        waitFor("Invite ID copied to clipboard!")
    }

    @Test fun teamJoinRequestsAndRoleEditWorkflow() {
        login()
        compose.onNodeWithTag("nav_item_team").performScrollTo().performClick()
        waitFor("Team")

        // Switch to Requests tab
        compose.onNodeWithTag("team_tab_2").performClick()
        waitFor("Neo Anderson")
        waitFor("neo@matrix.org")
        screenshot("android_team_join_requests_tab")

        // Accept request
        compose.onNodeWithTag("btn_accept_request_req-1").performClick()
        compose.waitForIdle()

        // Switch back to Members tab and verify Neo is now a member
        compose.onNodeWithTag("team_tab_0").performClick()
        waitFor("Neo Anderson")

        // Edit Sarah Connor's role
        compose.onNodeWithTag("btn_edit_role_member-b").performClick()
        waitFor("Edit Member Role")
        compose.onNodeWithTag("edit_chip_role_admin").performClick()
        compose.onNodeWithTag("btn_update_role").performClick()
        compose.waitForIdle()

        // Remove John Wick
        compose.onNodeWithTag("btn_remove_member_member-c").performClick()
        waitFor("Remove member?")
        compose.onNodeWithText("Confirm").performClick()
        compose.waitForIdle()
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/organizations/org-a/members/member-c" })
        }
    }

    @Test fun workspaceSwitcherAndJoinWorkflow() {
        login()
        // Open Navigation / Drawer and click workspace header
        compose.onNodeWithTag("workspace_header_switcher").performClick()
        waitFor("Workspaces")
        waitFor("Acme Workspace")
        screenshot("android_workspace_switcher")

        // Click Join Workspace
        compose.onNodeWithTag("btn_join_workspace").performClick()
        waitFor("Join Workspace")
        compose.onNodeWithTag("tf_search_workspace").performTextInput("External")
        waitFor("External Acme Org")
        compose.onNodeWithTag("btn_request_join_org-external").performClick()
        waitFor("Join request sent!")

        // Close Join Modal
        compose.onNodeWithTag("btn_close_join").performClick()
        compose.waitForIdle()
    }

    @Test fun inboxFilteringAndMarkAllReadWorkflow() {
        login()
        compose.onNodeWithTag("nav_item_inbox").performScrollTo().performClick()
        waitFor("Inbox")

        // Verify initial notifications listed with type headers
        compose.onNodeWithText("You were mentioned").assertIsDisplayed()
        compose.onNodeWithText("New Assignment").assertIsDisplayed()
        compose.onNodeWithText("Task Updated").assertIsDisplayed()
        screenshot("android_inbox_all")

        // Filter by Mentions
        compose.onNodeWithTag("InboxFilterChip_Mentions").performClick()
        compose.onNodeWithText("You were mentioned").assertIsDisplayed()
        compose.onNodeWithText("New Assignment").assertDoesNotExist()
        compose.onNodeWithText("Task Updated").assertDoesNotExist()
        screenshot("android_inbox_mentions_chip")

        // Filter by Assignments
        compose.onNodeWithTag("InboxFilterChip_Assignments").performClick()
        compose.onNodeWithText("New Assignment").assertIsDisplayed()
        compose.onNodeWithText("You were mentioned").assertDoesNotExist()

        // Filter by Updates
        compose.onNodeWithTag("InboxFilterChip_Updates").performClick()
        compose.onNodeWithText("Task Updated").assertIsDisplayed()
        compose.onNodeWithText("You were mentioned").assertDoesNotExist()

        // Switch back to All
        compose.onNodeWithTag("InboxFilterChip_All").performClick()
        compose.onNodeWithText("You were mentioned").assertIsDisplayed()

        // Mark single notification read
        compose.onNodeWithTag("InboxItemReadButton_notif-1").performClick()

        // Mark All Read
        compose.onNodeWithTag("InboxMarkAllReadButton").performClick()

        // Toggle unread only -> should show "All caught up!" empty state
        compose.onNodeWithTag("InboxUnreadToggle").performClick()
        waitFor("All caught up!")
        compose.onNodeWithText("All caught up!").assertIsDisplayed()
        screenshot("android_inbox_all_caught_up")
    }

    @Test fun billingSettingsAndStripeRedirectWorkflow() {
        login()
        // Navigate to Team
        compose.onNodeWithTag("nav_item_team").performScrollTo().performClick()
        waitFor("Team")
        waitFor("Alex Chen")

        // Open Billing Settings Modal
        compose.onNodeWithTag("btn_billing_settings").performClick()
        waitFor("Subscription & Billing")
        compose.onNodeWithText("Subscription & Billing").assertIsDisplayed()

        // Verify Current Plan card and Quota gauge
        compose.onNodeWithTag("card_current_subscription").assertIsDisplayed()
        compose.onNodeWithText("Team Members Quota").assertIsDisplayed()

        // Verify 3 Plan Tiers are displayed
        compose.onNodeWithTag("tier_free").performScrollTo().assertIsDisplayed()
        compose.onNodeWithTag("tier_pro").performScrollTo().assertIsDisplayed()
        screenshot("android_billing_plans_modal")

        compose.onNodeWithTag("tier_enterprise").performScrollTo().assertIsDisplayed()

        // Trigger Upgrade to Pro
        compose.onNodeWithTag("btn_action_tier_pro").performScrollTo().performClick()

        // Verify POST /api/org/billing/checkout was dispatched
        compose.waitUntil(10000) {
            writes.any { it.first == "/api/org/billing/checkout" }
        }
        val checkoutCall = writes.firstOrNull { it.first == "/api/org/billing/checkout" }
        assertNotNull("Expected checkout API call", checkoutCall)

        // Verify Redirect URL displayed in UI
        compose.waitUntil(10000) {
            runCatching {
                compose.onNodeWithTag("txt_checkout_url").assertIsDisplayed()
                true
            }.getOrDefault(false)
        }
        screenshot("android_billing_checkout_redirect")

        // Close Billing Modal
        compose.onNodeWithTag("btn_close_billing").performClick()
        compose.onNodeWithTag("modal_billing_settings").assertDoesNotExist()
    }

    @Test fun syncEngineConflictResolutionWorkflow() {
        login()
        compose.onNodeWithText("All Tasks").performClick()
        waitFor("Test Task 26/02 01")

        // Enqueue an operation with conflict into vm.syncEngine
        compose.runOnIdle {
            vm.syncEngine.clearAll()
            val conflictOp = com.acme.taskflow.data.LocalSyncOperation(
                id = "op-conflict-1",
                entityType = "task",
                entityId = "task-a",
                orgId = "org-a",
                operation = "PUT",
                payloadJson = json("title" to "Local Conflict Title", "expectedVersion" to 1).toString(),
                dirtyFields = listOf("title"),
                needsAttention = true,
                lastError = "Conflict: server has newer changes for the same task.",
                remoteSnapshotJson = json("id" to "task-a", "title" to "Server Title", "version" to 2).toString()
            )
            vm.syncEngine.enqueue(conflictOp)
        }

        // Open Sync Center
        compose.onNode(hasContentDescription("Sync center")).performClick()
        waitFor("Sync Center")
        waitFor("Needs Attention")
        waitFor("Conflict: server has newer changes for the same task.")
        screenshot("android_sync_center_conflict")

        // Verify "Use Theirs" and "Keep Mine" buttons exist
        compose.onNodeWithTag("btn_use_theirs_op-conflict-1").assertExists()
        compose.onNodeWithTag("btn_keep_mine_op-conflict-1").assertExists()

        // Click Keep Mine to resolve conflict
        compose.onNodeWithTag("btn_keep_mine_op-conflict-1").performClick()
        compose.waitForIdle()

        // Verify conflict was cleared and PUT /api/tasks/task-a was dispatched with version 2
        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/tasks/task-a" && it.second.number("expectedVersion") == 2 })
        }

        // Close Sync Center
        compose.onNodeWithTag("btn_close_sync_center").performClick()
    }

    @Test fun sprintAndBacklogPlanningWorkflow() {
        login()
        compose.onNodeWithText("All Tasks").performClick()
        waitFor("Test Task 26/02 01")

        // Select Backlog view mode
        compose.onNodeWithTag("mode_chips").performScrollToIndex(2)
        compose.onNodeWithText("Backlog").performClick()

        // Verify Product Backlog section and item
        waitFor("Product Backlog")
        waitFor("Groomed Backlog Story")
        waitFor("3 pts")

        // Switch sprint selector to Sprint 14
        compose.onNodeWithTag("sprint_selector").performClick()
        waitFor("Sprint 14 - Mobile Parity (Active)")
        compose.onNodeWithText("Sprint 14 - Mobile Parity (Active)").performClick()

        // Verify Sprint Planning card with capacity gauge and tasks
        waitFor("Sprint Planning")
        waitFor("Story Points Capacity")
        waitFor("13 / 20 pts")
        waitFor("LiveKit Calling Bridge")
        screenshot("android_agile_backlog_planning")

        // Complete Sprint action
        compose.onNodeWithTag("btn_complete_sprint").performClick()
        compose.waitForIdle()

        compose.runOnIdle {
            assertTrue(writes.any { it.first == "/api/sprints/sprint-1" && it.second.text("status") == "completed" })
        }
    }
}


