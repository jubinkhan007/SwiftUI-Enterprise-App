package com.acme.taskflow

import com.acme.taskflow.data.LocalSyncOperation
import com.acme.taskflow.data.SyncSquashing
import com.acme.taskflow.data.child
import com.acme.taskflow.data.json
import com.acme.taskflow.data.number
import com.acme.taskflow.data.obj
import com.acme.taskflow.data.text
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.UUID

class SyncSquashingTest {

    @Test
    fun putPlusPut_mergesPayloads_and_preservesEarliestExpectedVersion() {
        val list = mutableListOf<LocalSyncOperation>()
        val orgId = UUID.randomUUID().toString()
        val taskId = UUID.randomUUID().toString()

        val olderPayload = json("title" to "Old Title", "expectedVersion" to 10)
        val newerPayload = json("priority" to "high", "expectedVersion" to 999)

        val op1 = LocalSyncOperation(
            entityType = "task",
            entityId = taskId,
            orgId = orgId,
            operation = "PUT",
            payloadJson = olderPayload.toString(),
            dirtyFields = listOf("title")
        )
        val op2 = LocalSyncOperation(
            entityType = "task",
            entityId = taskId,
            orgId = orgId,
            operation = "PUT",
            payloadJson = newerPayload.toString(),
            dirtyFields = listOf("priority")
        )

        SyncSquashing.squash(list, op1)
        val squashed = SyncSquashing.squash(list, op2)

        assertTrue(squashed)
        assertEquals(1, list.size)
        assertEquals("PUT", list[0].operation)

        val merged = JsonParser.parseString(list[0].payloadJson!!).obj()
        assertEquals("Old Title", merged.text("title"))
        assertEquals("high", merged.text("priority"))
        // Preserves earliest expectedVersion
        assertEquals(10, merged.number("expectedVersion"))
        assertEquals(listOf("priority", "title"), list[0].dirtyFields)
    }

    @Test
    fun postPlusPut_foldsIntoCreate() {
        val list = mutableListOf<LocalSyncOperation>()
        val orgId = UUID.randomUUID().toString()
        val taskId = UUID.randomUUID().toString()

        val createPayload = json("id" to taskId, "title" to "Initial Title", "list_id" to "list-1")
        val updatePayload = json("title" to "Updated Title", "description" to "Some details", "expectedVersion" to 1)

        val opPost = LocalSyncOperation(
            entityType = "task",
            entityId = taskId,
            orgId = orgId,
            operation = "POST",
            payloadJson = createPayload.toString()
        )
        val opPut = LocalSyncOperation(
            entityType = "task",
            entityId = taskId,
            orgId = orgId,
            operation = "PUT",
            payloadJson = updatePayload.toString(),
            dirtyFields = listOf("title", "description")
        )

        SyncSquashing.squash(list, opPost)
        val squashed = SyncSquashing.squash(list, opPut)

        assertTrue(squashed)
        assertEquals(1, list.size)
        assertEquals("POST", list[0].operation)

        val folded = JsonParser.parseString(list[0].payloadJson!!).obj()
        assertEquals(taskId, folded.text("id"))
        assertEquals("Updated Title", folded.text("title"))
        assertEquals("Some details", folded.text("description"))
        assertEquals("list-1", folded.text("list_id"))
        assertFalse(folded.has("expectedVersion"))
    }

    @Test
    fun putPlusDelete_replacesWithDelete() {
        val list = mutableListOf<LocalSyncOperation>()
        val orgId = UUID.randomUUID().toString()
        val taskId = UUID.randomUUID().toString()

        val opPut = LocalSyncOperation(
            entityType = "task",
            entityId = taskId,
            orgId = orgId,
            operation = "PUT",
            payloadJson = json("title" to "Updated").toString()
        )
        val opDelete = LocalSyncOperation(
            entityType = "task",
            entityId = taskId,
            orgId = orgId,
            operation = "DELETE"
        )

        SyncSquashing.squash(list, opPut)
        val squashed = SyncSquashing.squash(list, opDelete)

        assertTrue(squashed)
        assertEquals(1, list.size)
        assertEquals("DELETE", list[0].operation)
    }

    @Test
    fun postPlusDelete_becomesNoop() {
        val list = mutableListOf<LocalSyncOperation>()
        val orgId = UUID.randomUUID().toString()
        val taskId = UUID.randomUUID().toString()

        val opPost = LocalSyncOperation(
            entityType = "task",
            entityId = taskId,
            orgId = orgId,
            operation = "POST",
            payloadJson = json("title" to "Offline Created").toString()
        )
        val opDelete = LocalSyncOperation(
            entityType = "task",
            entityId = taskId,
            orgId = orgId,
            operation = "DELETE"
        )

        SyncSquashing.squash(list, opPost)
        val squashed = SyncSquashing.squash(list, opDelete)

        assertTrue(squashed)
        assertTrue(list.isEmpty())
    }

    @Test
    fun deletePlusPut_marksNeedsAttention() {
        val list = mutableListOf<LocalSyncOperation>()
        val orgId = UUID.randomUUID().toString()
        val taskId = UUID.randomUUID().toString()

        val opDelete = LocalSyncOperation(
            entityType = "task",
            entityId = taskId,
            orgId = orgId,
            operation = "DELETE"
        )
        val opPut = LocalSyncOperation(
            entityType = "task",
            entityId = taskId,
            orgId = orgId,
            operation = "PUT",
            payloadJson = json("title" to "Edit after delete").toString()
        )

        SyncSquashing.squash(list, opDelete)
        val squashed = SyncSquashing.squash(list, opPut)

        assertTrue(squashed)
        assertEquals(1, list.size)
        assertTrue(list[0].needsAttention)
        assertTrue(list[0].lastError?.contains("Invalid offline sequence") == true)
    }
}
