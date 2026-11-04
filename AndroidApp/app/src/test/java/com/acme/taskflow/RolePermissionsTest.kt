package com.acme.taskflow

import com.acme.taskflow.ui.screens.RolePermissions
import com.acme.taskflow.ui.screens.sessionClientLabel
import com.google.gson.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RolePermissionsTest {
    @Test
    fun `owner has all 37 permissions and strict hierarchy holds`() {
        val guest = RolePermissions.permissionsFor("guest")
        val viewer = RolePermissions.permissionsFor("viewer")
        val member = RolePermissions.permissionsFor("member")
        val manager = RolePermissions.permissionsFor("manager")
        val admin = RolePermissions.permissionsFor("admin")
        val owner = RolePermissions.permissionsFor("owner")

        assertEquals(37, RolePermissions.total)
        assertEquals(RolePermissions.total, owner.size)
        assertTrue(viewer.containsAll(guest) && viewer.size > guest.size)
        assertTrue(manager.containsAll(member) && manager.size > member.size)
        assertTrue(admin.containsAll(manager) && admin.size > manager.size)
        assertTrue(owner.containsAll(admin) && owner.size > admin.size)
        assertFalse("org.delete" in admin)
        assertTrue("org.delete" in owner)
    }

    @Test
    fun `sessionClientLabel detects Android iOS and desktop browsers`() {
        val android = JsonObject().apply { addProperty("user_agent", "okhttp/4.12.0") }
        val ios = JsonObject().apply { addProperty("user_agent", "EnterpriseApp/1.0 CFNetwork/1494 Darwin/23.4") }
        val chrome = JsonObject().apply { addProperty("user_agent", "Mozilla/5.0 Chrome/124.0 Safari/537.36") }

        assertEquals("Android App", sessionClientLabel(android))
        assertEquals("iOS App", sessionClientLabel(ios))
        assertEquals("Chrome", sessionClientLabel(chrome))
    }
}

