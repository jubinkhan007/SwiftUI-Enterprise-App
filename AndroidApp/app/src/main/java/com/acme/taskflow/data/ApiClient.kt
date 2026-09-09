package com.acme.taskflow.data

import com.google.gson.Gson
import com.google.gson.JsonElement
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.callbackFlow
import okhttp3.WebSocket
import okhttp3.WebSocketListener

fun json(vararg fields: Pair<String, Any?>): JsonObject = Gson().toJsonTree(fields.toMap()).asJsonObject
fun JsonElement.obj(): JsonObject = if (isJsonObject) asJsonObject else JsonObject()
fun JsonElement.rows(): List<JsonObject> = if (isJsonArray) asJsonArray.map { it.asJsonObject } else emptyList()
fun JsonObject.text(key: String, fallback: String = ""): String = get(key)?.takeUnless { it.isJsonNull }?.asString ?: fallback
fun JsonObject.number(key: String): Int = get(key)?.takeUnless { it.isJsonNull }?.asInt ?: 0
fun JsonObject.flag(key: String): Boolean = get(key)?.takeUnless { it.isJsonNull }?.asBoolean ?: false
fun JsonObject.child(key: String): JsonObject = get(key)?.obj() ?: JsonObject()
fun JsonObject.list(key: String): List<JsonObject> = get(key)?.rows() ?: emptyList()
val JsonObject.id: String get() = text("id")

class ApiFailure(val status: Int, message: String) : IOException(message)
data class ApiResult(val data: JsonElement, val pagination: JsonObject)

class ApiClient(
    val baseUrl: String,
    private val token: String = "",
    val orgId: String = "",
    private val client: OkHttpClient = transport
) {
    fun events() = callbackFlow<JsonObject> {
        val url = baseUrl.toHttpUrl().newBuilder().encodedPath("/ws").addQueryParameter("org_id", orgId).build()
        val request = Request.Builder().url(url).header("Authorization", "Bearer $token").build()
        val socket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) { trySend(json("type" to "connection.open")) }
            override fun onMessage(webSocket: WebSocket, text: String) {
                runCatching { JsonParser.parseString(text).obj() }.getOrNull()?.let { trySend(it) }
            }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) { close(t) }
            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) { close(IOException("Live updates disconnected.")) }
        })
        awaitClose { socket.cancel() }
    }

    suspend fun request(
        path: String,
        method: String = "GET",
        body: JsonObject? = null,
        query: Map<String, String> = emptyMap(),
        version: Int? = null
    ): ApiResult {
        require(path.startsWith("/api/"))
        val url = baseUrl.toHttpUrl().newBuilder().encodedPath(path).apply {
            query.forEach { (key, value) -> addQueryParameter(key, value) }
        }.build()
        val requestBody = if (method in listOf("GET", "HEAD")) null
            else (body ?: JsonObject()).toString().toRequestBody("application/json".toMediaType())
        val request = Request.Builder().url(url).method(method, requestBody)
            .header("Accept", "application/json")
            .header("User-Agent", "TaskFlow-Android/1.0")
            .apply {
                if (token.isNotEmpty()) header("Authorization", "Bearer $token")
                if (orgId.isNotEmpty()) header("X-Org-Id", orgId)
                if (version != null) header("If-Match", "\"v$version\"")
            }.build()
        return suspendCancellableCoroutine { continuation ->
            val call = client.newCall(request)
            continuation.invokeOnCancellation { call.cancel() }
            call.enqueue(object : Callback {
                override fun onFailure(call: Call, e: IOException) {
                    if (continuation.isActive) continuation.resumeWithException(e)
                }

                override fun onResponse(call: Call, response: Response) {
                    val result = runCatching {
                        response.use {
                            val raw = it.body?.string().orEmpty()
                            val envelope = runCatching { JsonParser.parseString(raw).obj() }.getOrDefault(JsonObject())
                            if (!it.isSuccessful || (envelope.has("success") && !envelope.flag("success"))) {
                                throw ApiFailure(it.code, envelope.child("error").text("message")
                                    .ifBlank { envelope.text("reason") }.ifBlank { "Request failed (${it.code})" })
                            }
                            if (it.code != 204 && !envelope.has("success")) {
                                throw ApiFailure(it.code, "The server returned an invalid response.")
                            }
                            ApiResult(envelope.get("data") ?: JsonNull.INSTANCE, envelope.child("pagination"))
                        }
                    }
                    if (continuation.isActive) result.fold(continuation::resume, continuation::resumeWithException)
                }
            })
        }
    }

    suspend fun all(path: String, query: Map<String, String> = emptyMap()): List<JsonObject> {
        val rows = mutableListOf<JsonObject>()
        var page = 1
        do {
            val result = request(path, query = query + mapOf("page" to page.toString(), "per_page" to "100"))
            rows += result.data.rows()
            page++
        } while (page <= result.pagination.number("total_pages"))
        return rows
    }

    companion object {
        val transport = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS)
            .followRedirects(false).followSslRedirects(false).build()
    }
}
