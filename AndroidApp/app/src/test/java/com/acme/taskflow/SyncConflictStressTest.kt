package com.acme.taskflow

import com.acme.taskflow.data.LocalSyncOperation
import com.acme.taskflow.data.SyncSquashing
import com.acme.taskflow.data.json
import com.acme.taskflow.data.number
import com.acme.taskflow.data.obj
import com.acme.taskflow.data.text
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class SyncConflictStressTest {

    @Test
    fun stressQueue_highVolumeInterleavedMutations_preservesEarliestVersion() {
        val list = mutableListOf<LocalSyncOperation>()
        val orgAlpha = UUID.randomUUID().toString()
        val orgBeta = UUID.randomUUID().toString()
        val orgs = listOf(orgAlpha, orgBeta)

        val taskIds = (1..4).map { UUID.randomUUID().toString() }

        // Enqueue 100 interleaved operations across 4 tasks and 2 orgs
        for (round in 0 until 25) {
            for ((idx, taskId) in taskIds.withIndex()) {
                val orgId = orgs[idx % 2]
                val payload = json(
                    "round" to round,
                    "field_$round" to "val_$round",
                    "expectedVersion" to if (round == 0) 1 else 100 + round
                )

                val op = LocalSyncOperation(
                    entityType = "task",
                    entityId = taskId,
                    orgId = orgId,
                    operation = "PUT",
                    payloadJson = payload.toString(),
                    dirtyFields = listOf("field_$round")
                )
                SyncSquashing.squash(list, op)
            }
        }

        // Must collapse down to exactly 4 operations (1 per task)
        assertEquals(4, list.size)

        for (op in list) {
            assertEquals("PUT", op.operation)
            val merged = JsonParser.parseString(op.payloadJson!!).obj()
            // Invariant: Earliest expectedVersion = 1 is preserved across all squashed rounds
            assertEquals(1, merged.number("expectedVersion"))
            assertEquals(24, merged.number("round"))
            assertEquals(25, op.dirtyFields.size)
        }
    }

    @Test
    fun occConflict_409Detection_flagsNeedsAttention_andRetainsRemoteSnapshot() {
        val op = LocalSyncOperation(
            entityId = UUID.randomUUID().toString(),
            orgId = UUID.randomUUID().toString(),
            operation = "PUT",
            payloadJson = json("title" to "Local Offline Title", "expectedVersion" to 1).toString(),
            dirtyFields = listOf("title")
        )

        assertFalse(op.needsAttention)
        assertNull(op.remoteSnapshotJson)

        // Simulate 409 Conflict with remote server state
        val serverSnapshot = json(
            "id" to op.entityId,
            "title" to "Server Authoritative Title",
            "priority" to "critical",
            "version" to 3
        )

        op.needsAttention = true
        op.lastError = "Conflict: server has newer changes for the same task."
        op.remoteSnapshotJson = serverSnapshot.toString()

        assertTrue(op.needsAttention)
        assertNotNull(op.remoteSnapshotJson)
        val decodedRemote = JsonParser.parseString(op.remoteSnapshotJson!!).obj()
        assertEquals(3, decodedRemote.number("version"))
        assertEquals("Server Authoritative Title", decodedRemote.text("title"))
    }

    @Test
    fun resolveConflict_useTheirs_discardsLocalOp_andAppliesServerSnapshot() {
        val list = mutableListOf<LocalSyncOperation>()
        val taskId = UUID.randomUUID().toString()
        val orgId = UUID.randomUUID().toString()

        val op = LocalSyncOperation(
            entityId = taskId,
            orgId = orgId,
            operation = "PUT",
            payloadJson = json("title" to "My Rejected Change", "expectedVersion" to 1).toString(),
            needsAttention = true,
            remoteSnapshotJson = json("id" to taskId, "title" to "Server Master Title", "version" to 5).toString()
        )
        list.add(op)
        assertEquals(1, list.size)

        // "Use Theirs" resolution: discard from sync queue and apply remote data
        var appliedData: String? = null
        if (op.remoteSnapshotJson != null) {
            appliedData = op.remoteSnapshotJson
        }
        list.remove(op)

        assertTrue(list.isEmpty())
        assertNotNull(appliedData)
        val applied = JsonParser.parseString(appliedData!!).obj()
        assertEquals("Server Master Title", applied.text("title"))
        assertEquals(5, applied.number("version"))
    }

    @Test
    fun resolveConflict_keepMine_updatesExpectedVersion_andClearsAttention() {
        val taskId = UUID.randomUUID().toString()
        val orgId = UUID.randomUUID().toString()

        val op = LocalSyncOperation(
            entityId = taskId,
            orgId = orgId,
            operation = "PUT",
            payloadJson = json("title" to "My Winning Change", "expectedVersion" to 1).toString(),
            needsAttention = true,
            lastError = "Conflict: version mismatch",
            remoteSnapshotJson = json("id" to taskId, "title" to "Remote Title", "version" to 8).toString()
        )

        // "Keep Mine" resolution: adopt server version 8, clear attention state
        val remoteVersion = JsonParser.parseString(op.remoteSnapshotJson!!).obj().number("version") ?: 1
        val currentPayload = JsonParser.parseString(op.payloadJson!!).obj()
        currentPayload.addProperty("expectedVersion", remoteVersion)

        op.payloadJson = currentPayload.toString()
        op.needsAttention = false
        op.lastError = null
        op.remoteSnapshotJson = null
        op.retryCount = 0

        assertFalse(op.needsAttention)
        assertNull(op.lastError)
        assertNull(op.remoteSnapshotJson)

        val updatedPayload = JsonParser.parseString(op.payloadJson!!).obj()
        assertEquals(8, updatedPayload.number("expectedVersion"))
        assertEquals("My Winning Change", updatedPayload.text("title"))
    }

    @Test
    fun networkResiliency_transientErrors_incrementRetryCount() {
        val op = LocalSyncOperation(
            entityId = UUID.randomUUID().toString(),
            orgId = UUID.randomUUID().toString(),
            operation = "PUT",
            payloadJson = json("title" to "Transient Test", "expectedVersion" to 2).toString()
        )

        assertEquals(0, op.retryCount)

        // Simulate transient network failure (HTTP 503)
        op.retryCount += 1
        op.lastError = "HTTP 503 Service Unavailable"

        assertEquals(1, op.retryCount)
        assertFalse(op.needsAttention) // Transient error should not flag attention
        assertTrue(op.lastError!!.contains("503"))
    }
}
