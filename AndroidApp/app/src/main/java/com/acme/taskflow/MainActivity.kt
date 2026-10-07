package com.acme.taskflow

import android.os.Bundle
import android.Manifest
import android.content.pm.PackageManager
import android.content.Intent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.app.ActivityCompat
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import com.acme.taskflow.data.DeeplinkParser
import com.acme.taskflow.data.DeeplinkTarget
import com.acme.taskflow.ui.TaskFlowApp
import com.acme.taskflow.ui.theme.AppColors
import com.acme.taskflow.ui.theme.TaskFlowTheme

class MainActivity : ComponentActivity() {
    private val pendingDeeplink = mutableStateOf<DeeplinkTarget?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleDeeplinkIntent(intent)
        if (android.os.Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7001)
        }
        setContent {
            TaskFlowTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = AppColors.backgroundPrimary
                ) {
                    TaskFlowApp(
                        pendingDeeplink = pendingDeeplink.value,
                        onDeeplinkHandled = { pendingDeeplink.value = null }
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeeplinkIntent(intent)
    }

    private fun handleDeeplinkIntent(intent: Intent?) {
        if (intent == null) return
        val urlStr = intent.getStringExtra("EXTRA_DEEPLINK")
            ?: intent.getStringExtra("deep_link")
            ?: intent.dataString
        val target = DeeplinkParser.parse(urlStr) ?: DeeplinkParser.parse(intent.data)
        if (target != null) {
            pendingDeeplink.value = target
        }
    }
}
