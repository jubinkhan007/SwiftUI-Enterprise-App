package com.acme.taskflow.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private fun hsv(h: Float, s: Float, v: Float) = Color.hsv(h * 360, s, v)

// MARK: - AppSpacing & AppRadius (matching Spacing.swift)
object AppSpacing {
    val xxs: Dp = 2.dp
    val xs: Dp = 4.dp
    val sm: Dp = 8.dp
    val md: Dp = 12.dp
    val lg: Dp = 16.dp
    val xl: Dp = 24.dp
    val xxl: Dp = 32.dp
    val xxxl: Dp = 48.dp
}

object AppRadius {
    val small: Dp = 8.dp
    val medium: Dp = 12.dp
    val large: Dp = 16.dp
    val xl: Dp = 20.dp
    val pill: Dp = 100.dp
}

// MARK: - AppTypography (matching Typography.swift)
object AppTypography {
    private fun font(size: Int, weight: FontWeight = FontWeight.Normal) =
        TextStyle(fontSize = size.sp, fontWeight = weight, fontFamily = FontFamily.SansSerif, letterSpacing = 0.sp)

    val largeTitle = font(34, FontWeight.Bold)
    val title1 = font(28, FontWeight.Bold)
    val title2 = font(22, FontWeight.SemiBold)
    val title3 = font(20, FontWeight.SemiBold)
    val headline = font(17, FontWeight.SemiBold)
    val body = font(17, FontWeight.Normal)
    val callout = font(16, FontWeight.Normal)
    val subheadline = font(15, FontWeight.Normal)
    val footnote = font(13, FontWeight.Normal)
    val caption1 = font(12, FontWeight.Normal)
    val caption2 = font(11, FontWeight.Normal)
    val buttonLabel = font(17, FontWeight.SemiBold)
    val buttonLabelSmall = font(15, FontWeight.SemiBold)
}

// MARK: - AppColors (exact match with Colors.swift)
object AppColors {
    val brandPrimaryLight = hsv(0.694f, 0.80f, 0.80f)
    val brandPrimaryDark = hsv(0.694f, 0.72f, 0.92f)
    val brandPrimary: Color
        @Composable get() = if (isSystemInDarkTheme()) brandPrimaryDark else brandPrimaryLight

    val brandSecondaryLight = hsv(0.694f, 0.55f, 0.65f)
    val brandSecondaryDark = hsv(0.694f, 0.50f, 0.72f)
    val brandSecondary: Color
        @Composable get() = if (isSystemInDarkTheme()) brandSecondaryDark else brandSecondaryLight

    val accentLight = hsv(0.473f, 0.90f, 0.70f)
    val accentDark = hsv(0.473f, 1.00f, 0.85f)
    val accent: Color
        @Composable get() = if (isSystemInDarkTheme()) accentDark else accentLight

    val backgroundPrimary: Color
        @Composable get() = if (isSystemInDarkTheme()) hsv(0.633f, 0.30f, 0.07f) else Color.White

    val backgroundSecondary: Color
        @Composable get() = if (isSystemInDarkTheme()) hsv(0.633f, 0.25f, 0.11f) else Color(0xFFF2F2F7)

    val backgroundTertiary: Color
        @Composable get() = if (isSystemInDarkTheme()) hsv(0.633f, 0.20f, 0.15f) else Color(0xFFE5E5EA)

    val surfacePrimary: Color
        @Composable get() = if (isSystemInDarkTheme()) hsv(0.633f, 0.22f, 0.13f) else Color.White

    val surfaceElevated: Color
        @Composable get() = if (isSystemInDarkTheme()) hsv(0.633f, 0.18f, 0.18f) else Color(0xFFF7F7F8)

    val textPrimary: Color
        @Composable get() = if (isSystemInDarkTheme()) Color(0xFFF2F2F2) else Color(0xFF141414)

    val textSecondary: Color
        @Composable get() = if (isSystemInDarkTheme()) Color(0xFFB3B3B3) else Color(0xFF595959)

    val textTertiary: Color
        @Composable get() = if (isSystemInDarkTheme()) Color(0xFF808080) else Color(0xFF8C8C8C)

    val borderDefault: Color
        @Composable get() = if (isSystemInDarkTheme()) Color.White.copy(alpha = 0.10f) else Color.Black.copy(alpha = 0.10f)

    val borderSubtle: Color
        @Composable get() = if (isSystemInDarkTheme()) Color.White.copy(alpha = 0.06f) else Color.Black.copy(alpha = 0.06f)

    val statusSuccessLight = hsv(0.38f, 0.80f, 0.55f)
    val statusSuccessDark = hsv(0.38f, 0.75f, 0.75f)
    val statusSuccess: Color
        @Composable get() = if (isSystemInDarkTheme()) statusSuccessDark else statusSuccessLight

    val statusWarningLight = hsv(0.11f, 0.90f, 0.80f)
    val statusWarningDark = hsv(0.11f, 0.90f, 0.95f)
    val statusWarning: Color
        @Composable get() = if (isSystemInDarkTheme()) statusWarningDark else statusWarningLight

    val statusErrorLight = hsv(0.01f, 0.85f, 0.75f)
    val statusErrorDark = hsv(0.01f, 0.80f, 0.90f)
    val statusError: Color
        @Composable get() = if (isSystemInDarkTheme()) statusErrorDark else statusErrorLight

    val statusInfoLight = hsv(0.60f, 0.75f, 0.70f)
    val statusInfoDark = hsv(0.60f, 0.70f, 0.90f)
    val statusInfo: Color
        @Composable get() = if (isSystemInDarkTheme()) statusInfoDark else statusInfoLight

    val brandGradient: Brush
        @Composable get() = Brush.linearGradient(listOf(brandPrimary, accent))

    val brandGlowGradient: Brush
        @Composable get() = Brush.linearGradient(listOf(brandPrimary, brandSecondary, accent))

    val surfaceGradient: Brush
        @Composable get() = Brush.verticalGradient(listOf(surfacePrimary, surfaceElevated))
}

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
    background = Color(0xFFF2F2F7), surface = Color.White, surfaceVariant = Color(0xFFF7F7F8),
    onBackground = Color(.08f, .08f, .08f), onSurface = Color(.08f, .08f, .08f), onSurfaceVariant = Color(.35f, .35f, .35f),
    error = hsv(.01f, .85f, .75f), onPrimary = Color.White, outlineVariant = Color.Black.copy(alpha = .1f),
    secondaryContainer = hsv(.694f, .08f, .98f), onSecondaryContainer = Color(.08f, .08f, .08f)
)

val BrandGradient: Brush
    @Composable get() = AppColors.brandGradient

@Composable
fun TaskFlowTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors,
        typography = Typography(
            displaySmall = AppTypography.largeTitle,
            headlineMedium = AppTypography.title1,
            headlineSmall = AppTypography.title2,
            titleLarge = AppTypography.title3,
            titleMedium = AppTypography.headline,
            titleSmall = AppTypography.buttonLabelSmall,
            bodyLarge = AppTypography.body,
            bodyMedium = AppTypography.subheadline,
            bodySmall = AppTypography.footnote,
            labelLarge = AppTypography.buttonLabel,
            labelMedium = AppTypography.caption1,
            labelSmall = AppTypography.caption2
        ),
        shapes = Shapes(
            small = RoundedCornerShape(AppRadius.small),
            medium = RoundedCornerShape(AppRadius.medium),
            large = RoundedCornerShape(AppRadius.large)
        ),
        content = content
    )
}
