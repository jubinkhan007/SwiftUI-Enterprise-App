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
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import okhttp3.WebSocket
import okhttp3.WebSocketListener

fun json(vararg fields: Pair<String, Any?>): JsonObject = Gson().toJsonTree(fields.toMap()).asJsonObject
fun JsonElement.obj(): JsonObject = if (isJsonObject) asJsonObject else JsonObject()
fun JsonElement.rows(): List<JsonObject> = if (isJsonArray) asJsonArray.map { it.asJsonObject } else emptyList()
fun JsonObject.text(key: String, fallback: String = ""): String = get(key)?.takeUnless { it.isJsonNull }?.asString ?: fallback
fun JsonObject.number(key: String): Int = get(key)?.takeUnless { it.isJsonNull }?.asInt ?: 0
fun JsonObject.double(key: String, fallback: Double = 0.0): Double = get(key)?.takeUnless { it.isJsonNull }?.asDouble ?: fallback
fun JsonObject.flag(key: String): Boolean = get(key)?.takeUnless { it.isJsonNull }?.asBoolean ?: false
fun JsonObject.child(key: String): JsonObject = get(key)?.obj() ?: JsonObject()
fun JsonObject.list(key: String): List<JsonObject> = get(key)?.rows() ?: emptyList()
val JsonObject.id: String get() = text("id")

class ApiFailure(val status: Int, message: String, val rawBody: String = "") : IOException(message)
data class ApiResult(val data: JsonElement, val pagination: JsonObject)

data class AIAssistantStreamEvent(
    val event: String,
    val token: String? = null,
    val citations: List<JsonObject>? = null,
    val suggestedFollowUps: List<String>? = null,
    val response: JsonObject? = null,
    val error: String? = null
)

class ApiClient(
    val baseUrl: String,
    private val token: String = "",
    val orgId: String = "",
    private val client: OkHttpClient = transport,
    private val onUnauthorized: () -> Unit = {}
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
                                val errorMessage = when {
                                    envelope.has("reason") && envelope.get("reason").isJsonPrimitive -> envelope.text("reason")
                                    envelope.has("error") && envelope.get("error").isJsonObject -> envelope.child("error").text("message")
                                    envelope.has("error") && envelope.get("error").isJsonPrimitive && !envelope.get("error").asString.equals("true", ignoreCase = true) -> envelope.text("error")
                                    else -> "Request failed (${it.code})"
                                }
                                throw ApiFailure(it.code, errorMessage, raw)
                            }
                            if (it.code != 204 && !envelope.has("success")) {
                                throw ApiFailure(it.code, "The server returned an invalid response.", raw)
                            }
                            ApiResult(envelope.get("data") ?: JsonNull.INSTANCE, envelope.child("pagination"))
                        }
                    }
                    if (continuation.isActive) {
                        if ((result.exceptionOrNull() as? ApiFailure)?.status == 401) onUnauthorized()
                        result.fold(continuation::resume, continuation::resumeWithException)
                    }
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

    suspend fun search(
        query: String,
        types: List<String> = emptyList(),
        limit: Int = 20,
        mode: String = "hybrid",
        threshold: Double? = null
    ): JsonObject {
        val qParams = mutableMapOf("q" to query, "limit" to limit.toString(), "mode" to mode)
        if (types.isNotEmpty()) {
            qParams["types"] = types.joinToString(",")
        }
        if (threshold != null) {
            qParams["threshold"] = threshold.toString()
        }
        val result = request("/api/org/search", query = qParams)
        return result.data.obj()
    }

    suspend fun runAICopilot(
        action: String,
        prompt: String? = null,
        contextId: String? = null,
        entityPayload: Map<String, String>? = null
    ): JsonObject {
        val payload = JsonObject().apply {
            addProperty("action", action)
            if (prompt != null) addProperty("prompt", prompt)
            if (contextId != null) addProperty("contextId", contextId)
            if (entityPayload != null) {
                val entityObj = JsonObject()
                entityPayload.forEach { (k, v) -> entityObj.addProperty(k, v) }
                add("entityPayload", entityObj)
            }
        }
        val result = request("/api/org/ai/copilot", method = "POST", body = payload)
        return result.data.obj()
    }

    suspend fun breakdownTask(prompt: String): JsonObject {
        return runAICopilot(action = "breakdown_task", prompt = prompt)
    }

    suspend fun generateStandupSummary(): JsonObject {
        return runAICopilot(action = "generate_standup_summary")
    }

    suspend fun askKnowledgeBase(prompt: String): JsonObject {
        return runAICopilot(action = "ask_knowledge_base", prompt = prompt)
    }

    fun streamAICopilot(
        action: String,
        prompt: String? = null,
        contextId: String? = null,
        entityPayload: Map<String, String>? = null,
        entityTypes: List<String>? = null,
        maxSources: Int? = null
    ): Flow<AIAssistantStreamEvent> = callbackFlow {
        val payload = JsonObject().apply {
            addProperty("action", action)
            if (prompt != null) addProperty("prompt", prompt)
            if (contextId != null) addProperty("contextId", contextId)
            if (entityPayload != null) {
                val entityObj = JsonObject()
                entityPayload.forEach { (k, v) -> entityObj.addProperty(k, v) }
                add("entityPayload", entityObj)
            }
            if (entityTypes != null) {
                val arr = com.google.gson.JsonArray()
                entityTypes.forEach { arr.add(it) }
                add("entityTypes", arr)
            }
            if (maxSources != null) {
                addProperty("maxSources", maxSources)
            }
        }

        val url = baseUrl.toHttpUrl().newBuilder().encodedPath("/api/ai/stream").build()
        val reqBuilder = Request.Builder()
            .url(url)
            .header("Authorization", "Bearer $token")
            .header("Accept", "text/event-stream")
            .post(payload.toString().toRequestBody("application/json".toMediaType()))

        if (orgId.isNotBlank()) {
            reqBuilder.header("X-Org-Id", orgId)
        }

        val call = client.newCall(reqBuilder.build())
        call.enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                close(e)
            }

            override fun onResponse(call: Call, response: Response) {
                if (!response.isSuccessful) {
                    close(ApiFailure(response.code, "Streaming failed with HTTP ${response.code}", response.body?.string().orEmpty()))
                    return
                }
                val source = response.body?.source()
                if (source == null) {
                    close(IOException("Response body is null"))
                    return
                }

                try {
                    var currentEvent: String? = null
                    val dataBuffer = StringBuilder()

                    while (!source.exhausted()) {
                        val line = source.readUtf8Line() ?: break
                        if (line.isEmpty()) {
                            if (dataBuffer.isNotEmpty()) {
                                val dataStr = dataBuffer.toString().trim()
                                dataBuffer.setLength(0)
                                try {
                                    val parsed = JsonParser.parseString(dataStr).asJsonObject
                                    val eventType = currentEvent ?: parsed.text("event", "token")
                                    val token = if (parsed.has("token") && !parsed.get("token").isJsonNull) parsed.get("token").asString else null
                                    val citations = if (parsed.has("citations") && parsed.get("citations").isJsonArray) {
                                        parsed.getAsJsonArray("citations").map { it.asJsonObject }
                                    } else null
                                    val followUps = if (parsed.has("suggestedFollowUps") && parsed.get("suggestedFollowUps").isJsonArray) {
                                        parsed.getAsJsonArray("suggestedFollowUps").map { it.asString }
                                    } else if (parsed.has("suggested_follow_ups") && parsed.get("suggested_follow_ups").isJsonArray) {
                                        parsed.getAsJsonArray("suggested_follow_ups").map { it.asString }
                                    } else null
                                    val respObj = if (parsed.has("response") && parsed.get("response").isJsonObject) {
                                        parsed.getAsJsonObject("response")
                                    } else null
                                    val err = if (parsed.has("error") && !parsed.get("error").isJsonNull) parsed.get("error").asString else null

                                    trySend(AIAssistantStreamEvent(
                                        event = eventType,
                                        token = token,
                                        citations = citations,
                                        suggestedFollowUps = followUps,
                                        response = respObj,
                                        error = err
                                    ))
                                } catch (e: Exception) {
                                    // ignore parse err
                                }
                            }
                            currentEvent = null
                            continue
                        }

                        if (line.startsWith("event:")) {
                            currentEvent = line.substring(6).trim()
                        } else if (line.startsWith("data:")) {
                            val dataPart = line.substring(5).trim()
                            if (dataBuffer.isNotEmpty()) dataBuffer.append("\n")
                            dataBuffer.append(dataPart)
                        }
                    }
                    close()
                } catch (e: Exception) {
                    close(e)
                } finally {
                    response.close()
                }
            }
        })

        awaitClose {
            call.cancel()
        }
    }

    fun streamAskKnowledgeBase(
        prompt: String,
        entityTypes: List<String>? = null,
        maxSources: Int? = null
    ): Flow<AIAssistantStreamEvent> {
        return streamAICopilot(
            action = "ask_knowledge_base",
            prompt = prompt,
            entityTypes = entityTypes,
            maxSources = maxSources
        )
    }

    fun streamBreakdownTask(prompt: String): Flow<AIAssistantStreamEvent> {
        return streamAICopilot(action = "breakdown_task", prompt = prompt)
    }

    fun streamGenerateStandupSummary(): Flow<AIAssistantStreamEvent> {
        return streamAICopilot(action = "generate_standup_summary")
    }

    companion object {
        val transport = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS).readTimeout(30, TimeUnit.SECONDS)
            .followRedirects(false).followSslRedirects(false).build()
    }
}
