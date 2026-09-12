package com.acme.taskflow.data

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.acme.taskflow.BuildConfig
import com.google.gson.JsonObject
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

class AppViewModel @JvmOverloads constructor(
    application: Application,
    private val storage: SessionStore = SessionStore(application)
) : AndroidViewModel(application) {
    private var session = storage.read()
    var user by mutableStateOf(session?.child("user"))
        private set
    var workspace by mutableStateOf<JsonObject?>(null)
        private set
    var server by mutableStateOf(session?.text("server") ?: BuildConfig.API_BASE_URL)
        private set
    var busy by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set
    var revision by mutableStateOf(0)
        private set
    val sessionToken: String get() = session?.text("token").orEmpty()
    val api: ApiClient get() {
        val activeToken = session?.text("token").orEmpty()
        return ApiClient(server, activeToken, workspace?.id.orEmpty(), onUnauthorized = {
            viewModelScope.launch {
                if (session?.text("token") == activeToken) expired()
            }
        })
    }

    fun authenticate(email: String, password: String, name: String?, endpoint: String) {
        if (busy) return
        val url = endpoint.trim().toHttpUrlOrNull()
        if (url == null || url.username.isNotEmpty() || url.password.isNotEmpty() ||
            (url.scheme != "https" && url.host !in listOf("10.0.2.2", "127.0.0.1", "localhost"))) {
            error = "Enter an HTTPS server address, or use the local emulator server."
            return
        }
        busy = true
        error = null
        viewModelScope.launch {
            try {
                val auth = ApiClient(url.toString()).request(
                    if (name == null) "/api/auth/login" else "/api/auth/register", "POST",
                    json("email" to email.trim(), "password" to password, "display_name" to name)
                ).data.obj()
                check(auth.text("token").isNotBlank() && auth.child("user").id.isNotBlank()) { "Invalid sign-in response." }
                server = url.toString()
                auth.addProperty("server", server)
                storage.write(auth)
                session = auth
                user = auth.child("user")
            } catch (e: CancellationException) { throw e
            } catch (e: Exception) { error = e.message ?: "Unable to sign in."
            } finally { busy = false }
        }
    }

    fun selectWorkspace(value: JsonObject?) { workspace = value; revision++ }
    fun changed() { revision++ }
    fun signOut() { storage.clear(); session = null; user = null; workspace = null; error = null; revision++ }
    fun expired() { signOut(); error = "Your session expired. Please sign in again." }

    @androidx.annotation.VisibleForTesting
    internal fun restoreForTesting(userProfile: JsonObject, authServer: String, authToken: String) {
        server = authServer
        session = json("token" to authToken, "user" to userProfile, "server" to authServer)
        user = userProfile
    }
}
