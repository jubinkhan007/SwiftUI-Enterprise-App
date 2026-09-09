package com.acme.taskflow.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private fun hsv(h: Float, s: Float, v: Float) = Color.hsv(h * 360, s, v)

// The same HSB values as DesignSystem/Tokens/Colors.swift.
private val DarkColors = darkColorScheme(
    primary = hsv(.694f, .72f, .92f), secondary = hsv(.694f, .50f, .72f), tertiary = hsv(.473f, 1f, .85f),
    background = hsv(.633f, .30f, .07f), surface = hsv(.633f, .22f, .13f), surfaceVariant = hsv(.633f, .18f, .18f),
    onBackground = Color(.95f, .95f, .95f), onSurface = Color(.95f, .95f, .95f), onSurfaceVariant = Color(.70f, .70f, .70f),
    error = hsv(.01f, .80f, .90f), onPrimary = Color.White, outlineVariant = Color.White.copy(alpha = .1f),
    secondaryContainer = hsv(.694f, .36f, .24f), onSecondaryContainer = Color(.95f, .95f, .95f)
)
private val LightColors = lightColorScheme(
    primary = hsv(.694f, .80f, .80f), secondary = hsv(.694f, .55f, .65f), tertiary = hsv(.473f, .90f, .70f),
    background = Color.White, surface = Color.White, surfaceVariant = Color(.97f, .97f, .97f),
    onBackground = Color(.08f, .08f, .08f), onSurface = Color(.08f, .08f, .08f), onSurfaceVariant = Color(.35f, .35f, .35f),
    error = hsv(.01f, .85f, .75f), onPrimary = Color.White, outlineVariant = Color.Black.copy(alpha = .1f),
    secondaryContainer = hsv(.694f, .08f, .98f), onSecondaryContainer = Color(.08f, .08f, .08f)
)

val BrandGradient: Brush
    @Composable get() = Brush.linearGradient(listOf(MaterialTheme.colorScheme.primary, MaterialTheme.colorScheme.tertiary))

@Composable
fun TaskFlowTheme(content: @Composable () -> Unit) {
    fun style(size: Int, weight: FontWeight = FontWeight.Normal) = TextStyle(fontSize = size.sp, fontWeight = weight, letterSpacing = 0.sp)
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        typography = Typography(
            displaySmall = style(34, FontWeight.Bold), headlineMedium = style(28, FontWeight.Bold), headlineSmall = style(22, FontWeight.SemiBold),
            titleLarge = style(20, FontWeight.SemiBold), titleMedium = style(17, FontWeight.SemiBold), titleSmall = style(15, FontWeight.SemiBold),
            bodyLarge = style(17), bodyMedium = style(15), bodySmall = style(13),
            labelLarge = style(15, FontWeight.SemiBold), labelMedium = style(12, FontWeight.SemiBold), labelSmall = style(11, FontWeight.SemiBold)),
        shapes = Shapes(small = RoundedCornerShape(8.dp), medium = RoundedCornerShape(12.dp), large = RoundedCornerShape(16.dp)),
        content = content
    )
}
