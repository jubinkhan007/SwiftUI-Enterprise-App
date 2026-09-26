package com.acme.taskflow.data

import android.content.Context
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID
import java.util.concurrent.CopyOnWriteArrayList

data class LocalSyncOperation(
    val id: String = UUID.randomUUID().toString(),
    val entityType: String = "task",
    val entityId: String,
    val orgId: String,
    var operation: String, // "POST", "PUT", "DELETE"
    var payloadJson: String? = null,
    var dirtyFields: List<String> = emptyList(),
    var baseSnapshotJson: String? = null,
    var remoteSnapshotJson: String? = null,
    var needsAttention: Boolean = false,
    var lastError: String? = null,
    var retryCount: Int = 0,
    var timestamp: Long = System.currentTimeMillis()
)

object SyncSquashing {
    fun squash(list: MutableList<LocalSyncOperation>, incoming: LocalSyncOperation): Boolean {
        val existingIndex = list.indexOfLast {
            it.orgId == incoming.orgId &&
            it.entityType == incoming.entityType &&
            it.entityId == incoming.entityId &&
            !it.needsAttention
        }
        if (existingIndex < 0) {
            list.add(incoming)
            return false
        }

        val last = list[existingIndex]
        val lastOp = last.operation.uppercase()
        val incOp = incoming.operation.uppercase()

        when {
            // Rule 1: PUT + PUT -> merge fields, preserve earliest expectedVersion
            lastOp == "PUT" && incOp == "PUT" -> {
                val older = runCatching { JsonParser.parseString(last.payloadJson ?: "{}").obj() }.getOrDefault(JsonObject())
                val newer = runCatching { JsonParser.parseString(incoming.payloadJson ?: "{}").obj() }.getOrDefault(JsonObject())

                val earliestVersion = when {
                    older.has("expectedVersion") -> older.get("expectedVersion")
                    newer.has("expectedVersion") -> newer.get("expectedVersion")
                    else -> null
                }

                // Copy all newer keys over older keys
                newer.entrySet().forEach { (k, v) -> older.add(k, v) }
                if (earliestVersion != null) older.add("expectedVersion", earliestVersion)

                last.payloadJson = older.toString()
                last.dirtyFields = (last.dirtyFields + incoming.dirtyFields).distinct().sorted()
                last.timestamp = maxOf(last.timestamp, incoming.timestamp)
                return true
            }

            // Rule 2: POST + PUT -> fold updates directly into create POST
            lastOp == "POST" && incOp == "PUT" -> {
                val create = runCatching { JsonParser.parseString(last.payloadJson ?: "{}").obj() }.getOrDefault(JsonObject())
                val update = runCatching { JsonParser.parseString(incoming.payloadJson ?: "{}").obj() }.getOrDefault(JsonObject())

                update.entrySet().forEach { (k, v) ->
                    if (k != "expectedVersion") create.add(k, v)
                }
                last.payloadJson = create.toString()
                last.timestamp = maxOf(last.timestamp, incoming.timestamp)
                return true
            }

            // Rule 3: PUT + DELETE -> replace PUT with single DELETE
            lastOp == "PUT" && incOp == "DELETE" -> {
                list.removeAt(existingIndex)
                list.add(incoming)
                return true
            }

            // Rule 4: POST + DELETE -> created and deleted offline => cancel both (NO-OP)
            lastOp == "POST" && incOp == "DELETE" -> {
                list.removeAt(existingIndex)
                return true
            }

            // Rule 5: DELETE + PUT -> invalid offline sequence
            lastOp == "DELETE" && incOp == "PUT" -> {
                last.needsAttention = true
                last.lastError = "Invalid offline sequence: DELETE followed by PUT."
                return true
            }

            else -> {
                list.add(incoming)
                return false
            }
        }
    }
}

class SyncEngineManager(
    private val apiProvider: () -> ApiClient,
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.Main),
    private val onLocalUpdate: ((JsonObject) -> Unit)? = null
) {
    private val operations = CopyOnWriteArrayList<LocalSyncOperation>()

    private val _pendingOperations = MutableStateFlow<List<LocalSyncOperation>>(emptyList())
    val pendingOperations: StateFlow<List<LocalSyncOperation>> = _pendingOperations.asStateFlow()

    private val _attentionOperations = MutableStateFlow<List<LocalSyncOperation>>(emptyList())
    val attentionOperations: StateFlow<List<LocalSyncOperation>> = _attentionOperations.asStateFlow()

    private val _isSyncing = MutableStateFlow(false)
    val isSyncing: StateFlow<Boolean> = _isSyncing.asStateFlow()

    private fun updateFlows() {
        _pendingOperations.value = operations.filter { !it.needsAttention }
        _attentionOperations.value = operations.filter { it.needsAttention }
    }

    fun enqueue(op: LocalSyncOperation) {
        val list = operations.toMutableList()
        SyncSquashing.squash(list, op)
        operations.clear()
        operations.addAll(list)
        updateFlows()
    }

    fun enqueueTaskCreate(id: String, orgId: String, payload: JsonObject) {
        enqueue(
            LocalSyncOperation(
                entityType = "task",
                entityId = id,
                orgId = orgId,
                operation = "POST",
                payloadJson = payload.toString()
            )
        )
    }

    fun enqueueTaskUpdate(id: String, orgId: String, payload: JsonObject, dirtyFields: List<String> = emptyList(), baseSnapshot: JsonObject? = null) {
        enqueue(
            LocalSyncOperation(
                entityType = "task",
                entityId = id,
                orgId = orgId,
                operation = "PUT",
                payloadJson = payload.toString(),
                dirtyFields = dirtyFields,
                baseSnapshotJson = baseSnapshot?.toString()
            )
        )
    }

    fun enqueueTaskDelete(id: String, orgId: String) {
        enqueue(
            LocalSyncOperation(
                entityType = "task",
                entityId = id,
                orgId = orgId,
                operation = "DELETE"
            )
        )
    }

    fun syncNow(onFinished: () -> Unit = {}) {
        if (_isSyncing.value) return
        _isSyncing.value = true
        scope.launch {
            try {
                val api = apiProvider()
                val pending = operations.filter { !it.needsAttention }

                for (op in pending) {
                    processOperation(api, op)
                }
            } finally {
                updateFlows()
                _isSyncing.value = false
                onFinished()
            }
        }
    }

    private suspend fun processOperation(api: ApiClient, op: LocalSyncOperation) {
        try {
            when (op.operation.uppercase()) {
                "POST" -> {
                    val payload = runCatching { JsonParser.parseString(op.payloadJson ?: "{}").obj() }.getOrDefault(JsonObject())
                    val res = api.request("/api/tasks", "POST", payload)
                    onLocalUpdate?.invoke(res.data.obj())
                    operations.remove(op)
                }
                "PUT" -> {
                    val payload = runCatching { JsonParser.parseString(op.payloadJson ?: "{}").obj() }.getOrDefault(JsonObject())
                    val res = api.request("/api/tasks/${op.entityId}", "PUT", payload)
                    onLocalUpdate?.invoke(res.data.obj())
                    operations.remove(op)
                }
                "DELETE" -> {
                    api.request("/api/tasks/${op.entityId}", "DELETE")
                    operations.remove(op)
                }
            }
        } catch (e: ApiFailure) {
            if (e.status == 409) {
                // Conflict detected (OCC mismatch)
                val raw = e.rawBody
                val serverObj = runCatching {
                    val env = JsonParser.parseString(raw).obj()
                    if (env.has("data")) env.child("data") else env
                }.getOrDefault(JsonObject())

                op.needsAttention = true
                op.lastError = "Conflict: server has newer changes for the same task."
                op.remoteSnapshotJson = serverObj.toString()
            } else {
                op.retryCount++
                op.lastError = e.message ?: "Sync failed (${e.status})"
            }
        } catch (e: Exception) {
            op.retryCount++
            op.lastError = e.message ?: "Sync failed"
        }
    }

    fun resolveConflictUseTheirs(op: LocalSyncOperation) {
        val serverObj = op.remoteSnapshotJson?.let {
            runCatching { JsonParser.parseString(it).obj() }.getOrNull()
        }
        if (serverObj != null) {
            onLocalUpdate?.invoke(serverObj)
        }
        discard(op)
    }

    fun resolveConflictKeepMine(op: LocalSyncOperation) {
        val serverObj = op.remoteSnapshotJson?.let {
            runCatching { JsonParser.parseString(it).obj() }.getOrNull()
        }
        val serverVersion = serverObj?.number("version") ?: 1

        val currentPayload = runCatching { JsonParser.parseString(op.payloadJson ?: "{}").obj() }.getOrDefault(JsonObject())
        currentPayload.addProperty("expectedVersion", serverVersion)
        op.payloadJson = currentPayload.toString()

        op.needsAttention = false
        op.lastError = null
        op.remoteSnapshotJson = null
        op.retryCount = 0

        updateFlows()
        syncNow()
    }

    fun retry(op: LocalSyncOperation) {
        op.needsAttention = false
        op.lastError = null
        op.retryCount = 0
        updateFlows()
        syncNow()
    }

    fun discard(op: LocalSyncOperation) {
        operations.remove(op)
        updateFlows()
    }

    fun clearAll() {
        operations.clear()
        updateFlows()
    }
}
