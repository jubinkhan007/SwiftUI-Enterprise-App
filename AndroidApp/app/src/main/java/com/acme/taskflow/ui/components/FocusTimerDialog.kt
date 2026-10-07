package com.acme.taskflow.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.acme.taskflow.data.OngoingActivityManager
import com.acme.taskflow.ui.theme.AppColors
import com.acme.taskflow.ui.theme.AppRadius
import com.acme.taskflow.ui.theme.AppSpacing
import com.acme.taskflow.ui.theme.AppTypography
import kotlinx.coroutines.delay

@Composable
fun FocusTimerContent(
    initialTitle: String = "Deep Work Session",
    onClose: (() -> Unit)? = null
) {
    val context = LocalContext.current
    var sessionTitle by remember { mutableStateOf(initialTitle) }
    var targetMinutes by remember { mutableIntStateOf(25) }
    var remainingSeconds by remember { mutableIntStateOf(25 * 60) }
    var isRunning by remember { mutableStateOf(false) }
    var isPaused by remember { mutableStateOf(false) }
    var mode by remember { mutableStateOf("Focus") }

    val presets = listOf(
        Triple("Focus 25m", 25, "Focus"),
        Triple("Deep Work 45m", 45, "Focus"),
        Triple("Short Break 5m", 5, "Break"),
        Triple("Long Break 15m", 15, "Break")
    )

    // Ticking loop
    LaunchedEffect(isRunning, isPaused) {
        if (isRunning && !isPaused) {
            OngoingActivityManager.showFocusOngoingNotification(
                context = context,
                sessionTitle = sessionTitle,
                remainingMillis = remainingSeconds * 1000L,
                totalMinutes = targetMinutes,
                isPaused = false
            )
            while (isRunning && !isPaused && remainingSeconds > 0) {
                delay(1000L)
                remainingSeconds -= 1
                if (remainingSeconds % 5 == 0 || remainingSeconds <= 10) {
                    OngoingActivityManager.showFocusOngoingNotification(
                        context = context,
                        sessionTitle = sessionTitle,
                        remainingMillis = remainingSeconds * 1000L,
                        totalMinutes = targetMinutes,
                        isPaused = false
                    )
                }
            }
            if (remainingSeconds <= 0) {
                isRunning = false
                OngoingActivityManager.hideFocusNotification(context)
            }
        } else if (isRunning && isPaused) {
            OngoingActivityManager.showFocusOngoingNotification(
                context = context,
                sessionTitle = sessionTitle,
                remainingMillis = remainingSeconds * 1000L,
                totalMinutes = targetMinutes,
                isPaused = true
            )
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            if (!isRunning) {
                OngoingActivityManager.hideFocusNotification(context)
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(
                    imageVector = Icons.Default.Headphones,
                    contentDescription = null,
                    tint = if (mode == "Focus") Color(0xFFF59E0B) else Color(0xFF10B981),
                    modifier = Modifier.size(24.dp)
                )
                Text(
                    "Focus & Deep Work",
                    style = AppTypography.headline,
                    color = AppColors.textPrimary
                )
            }
            if (onClose != null) {
                IconButton(onClick = onClose) {
                    Icon(Icons.Default.Close, contentDescription = "Close", tint = AppColors.textSecondary)
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Presets row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            presets.forEach { (label, mins, modeType) ->
                val selected = targetMinutes == mins && mode == modeType
                Button(
                    onClick = {
                        if (!isRunning) {
                            targetMinutes = mins
                            remainingSeconds = mins * 60
                            mode = modeType
                            if (sessionTitle.isBlank() || sessionTitle == "Deep Work Session") {
                                sessionTitle = label
                            }
                        }
                    },
                    enabled = !isRunning,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (selected) AppColors.brandPrimary else AppColors.surfaceElevated,
                        contentColor = if (selected) Color.White else AppColors.textPrimary
                    ),
                    contentPadding = PaddingValues(horizontal = 8.dp, vertical = 6.dp),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    Text(label.split(" ").first(), fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Session title text input
        OutlinedTextField(
            value = sessionTitle,
            onValueChange = { if (!isRunning) sessionTitle = it },
            label = { Text("Session Goal") },
            singleLine = true,
            enabled = !isRunning,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(AppRadius.medium)
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Circular Progress Dial
        val totalSecs = (targetMinutes * 60).toFloat()
        val progress = if (totalSecs > 0) (totalSecs - remainingSeconds) / totalSecs else 0f
        val animatedProgress by animateFloatAsState(targetValue = progress, label = "progress")
        val activeColor = if (mode == "Focus") Color(0xFFF59E0B) else Color(0xFF10B981)

        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(200.dp)
        ) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                drawCircle(
                    color = Color.White.copy(alpha = 0.08f),
                    style = Stroke(width = 12.dp.toPx())
                )
                drawArc(
                    color = activeColor,
                    startAngle = -90f,
                    sweepAngle = 360f * animatedProgress,
                    useCenter = false,
                    style = Stroke(width = 12.dp.toPx(), cap = StrokeCap.Round)
                )
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                val mins = remainingSeconds / 60
                val secs = remainingSeconds % 60
                Text(
                    text = String.format("%02d:%02d", mins, secs),
                    fontSize = 38.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = AppColors.textPrimary
                )
                Text(
                    text = if (!isRunning) "READY" else if (isPaused) "PAUSED" else "${mode.uppercase()} ACTIVE",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = if (!isRunning) AppColors.textSecondary else if (isPaused) Color(0xFFF59E0B) else activeColor
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Controls
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (!isRunning) {
                Button(
                    onClick = {
                        isRunning = true
                        isPaused = false
                        remainingSeconds = targetMinutes * 60
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = activeColor),
                    shape = CircleShape,
                    modifier = Modifier.weight(1f).height(48.dp)
                ) {
                    Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Color.Black)
                    Spacer(Modifier.width(6.dp))
                    Text("Start Focus", color = Color.Black, fontWeight = FontWeight.Bold)
                }
            } else {
                Button(
                    onClick = { isPaused = !isPaused },
                    colors = ButtonDefaults.buttonColors(containerColor = if (isPaused) Color(0xFF10B981) else Color(0xFFF59E0B)),
                    shape = CircleShape,
                    modifier = Modifier.weight(1f).height(48.dp)
                ) {
                    Icon(if (isPaused) Icons.Default.PlayArrow else Icons.Default.Pause, contentDescription = null, tint = Color.Black)
                    Spacer(Modifier.width(6.dp))
                    Text(if (isPaused) "Resume" else "Pause", color = Color.Black, fontWeight = FontWeight.Bold)
                }

                Button(
                    onClick = {
                        isRunning = false
                        isPaused = false
                        remainingSeconds = targetMinutes * 60
                        OngoingActivityManager.hideFocusNotification(context)
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFEF4444)),
                    shape = CircleShape,
                    modifier = Modifier.weight(1f).height(48.dp)
                ) {
                    Icon(Icons.Default.Stop, contentDescription = null, tint = Color.White)
                    Spacer(Modifier.width(6.dp))
                    Text("Stop", color = Color.White, fontWeight = FontWeight.Bold)
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        Text(
            text = "Ongoing status bar notification with real-time countdown enabled",
            fontSize = 11.sp,
            color = AppColors.textSecondary
        )
    }
}

@Composable
fun FocusTimerDialog(
    initialTitle: String = "Deep Work Session",
    onDismiss: () -> Unit
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Card(
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            modifier = Modifier
                .fillMaxWidth(0.92f)
                .wrapContentHeight()
                .padding(16.dp)
                .testTag("focus_timer_dialog")
        ) {
            FocusTimerContent(initialTitle = initialTitle, onClose = onDismiss)
        }
    }
}
