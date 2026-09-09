package com.acme.taskflow.data

import com.google.gson.JsonParser
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.runBlocking
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.SocketPolicy
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.util.concurrent.TimeUnit

class ApiClientTest {
    private lateinit var server: MockWebServer
    @Before fun start() { server = MockWebServer(); server.start() }
    @After fun stop() { server.shutdown() }
    private fun client(org: String = "org-a") = ApiClient(server.url("/").toString(), "test-token", org)

    @Test fun `task update sends tenant credentials and version precondition`() = runBlocking {
        server.enqueue(MockResponse().setBody("""{"success":true,"data":{"id":"task-a","version":4}}"""))
        val response = client().request("/api/tasks/task-a", "PATCH", json("title" to "Revised", "expected_version" to 3), version = 3)
        val request = server.takeRequest()
        assertEquals("Bearer test-token", request.getHeader("Authorization"))
        assertEquals("org-a", request.getHeader("X-Org-Id"))
        assertEquals("\"v3\"", request.getHeader("If-Match"))
        assertEquals(3, JsonParser.parseString(request.body.readUtf8()).obj().number("expected_version"))
        assertEquals(4, response.data.obj().number("version"))
    }

    @Test fun `pagination includes all pages and encodes searches`() = runBlocking {
        server.enqueue(MockResponse().setBody("""{"success":true,"data":[{"id":"a"}],"pagination":{"total_pages":2}}"""))
        server.enqueue(MockResponse().setBody("""{"success":true,"data":[{"id":"b"}],"pagination":{"total_pages":2}}"""))
        val rows = client().all("/api/tasks", mapOf("search" to "A&B + C"))
        assertEquals(listOf("a", "b"), rows.map { it.id })
        assertEquals("A&B + C", server.takeRequest().requestUrl?.queryParameter("search"))
        assertEquals("2", server.takeRequest().requestUrl?.queryParameter("page"))
    }

    @Test fun `server conflicts remain errors with their message`() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(409).setBody("""{"success":false,"error":{"code":"CONFLICT","message":"Task changed on another device"}}"""))
        val failure = runCatching { client().request("/api/tasks/a", "PATCH", json("title" to "New")) }.exceptionOrNull()
        assertTrue(failure is ApiFailure)
        assertEquals(409, (failure as ApiFailure).status)
        assertEquals("Task changed on another device", failure.message)
    }

    @Test fun `redirects do not forward a session to another host`() = runBlocking {
        MockWebServer().use { other ->
            other.start()
            server.enqueue(MockResponse().setResponseCode(302).addHeader("Location", other.url("/api/tasks")))
            assertTrue(runCatching { client().request("/api/tasks") }.exceptionOrNull() is ApiFailure)
            assertNull(other.takeRequest(100, TimeUnit.MILLISECONDS))
        }
    }

    @Test fun `tenant is bound to each client instance`() = runBlocking {
        repeat(2) { server.enqueue(MockResponse().setBody("""{"success":true,"data":[]}""")) }
        client("first").request("/api/tasks")
        client("second").request("/api/tasks")
        assertEquals("first", server.takeRequest().getHeader("X-Org-Id"))
        assertEquals("second", server.takeRequest().getHeader("X-Org-Id"))
    }

    @Test fun `malformed successful response is not accepted as empty data`() = runBlocking {
        server.enqueue(MockResponse().setBody("<html>proxy error</html>"))
        assertTrue(runCatching { client().request("/api/tasks") }.exceptionOrNull() is ApiFailure)
    }

    @Test fun `empty deletion response is accepted`() = runBlocking {
        server.enqueue(MockResponse().setResponseCode(204))
        assertTrue(client().request("/api/tasks/a", "DELETE").data.isJsonNull)
    }

    @Test fun `cancelled caller cancels a pending request`() = runBlocking {
        server.enqueue(MockResponse().setSocketPolicy(SocketPolicy.NO_RESPONSE))
        val job = async { client().request("/api/tasks") }
        kotlinx.coroutines.yield()
        assertNotNull(server.takeRequest(5, TimeUnit.SECONDS))
        job.cancelAndJoin()
        assertTrue(job.isCancelled)
    }
}
