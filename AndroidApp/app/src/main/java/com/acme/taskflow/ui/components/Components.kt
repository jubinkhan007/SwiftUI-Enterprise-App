package com.acme.taskflow.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.acme.taskflow.ui.theme.*

// MARK: - iOS Inset Grouped Section & Rows (matching app_running.png)
@Composable
fun IosSectionHeader(title: String, modifier: Modifier = Modifier) {
    Text(
        text = title.uppercase(),
        style = AppTypography.caption1.copy(fontWeight = FontWeight.Medium),
        color = AppColors.textTertiary,
        modifier = modifier.padding(start = 16.dp, bottom = 8.dp)
    )
}

@Composable
fun IosInsetGroupedCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppRadius.medium))
            .background(AppColors.surfacePrimary)
            .border(BorderStroke(0.5.dp, AppColors.borderSubtle), RoundedCornerShape(AppRadius.medium)),
        content = content
    )
}

@Composable
fun IosGroupedRow(
    title: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    iconTint: Color = Color(0xFF007AFF),
    subtitle: String? = null,
    showChevron: Boolean = true,
    showDivider: Boolean = true,
    onClick: () -> Unit
) {
    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .clickable(onClick = onClick)
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (icon != null) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = iconTint,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(Modifier.width(16.dp))
            }
            Column(Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = AppTypography.body,
                    color = AppColors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                if (subtitle != null) {
                    Text(
                        text = subtitle,
                        style = AppTypography.caption1,
                        color = AppColors.textSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
            if (showChevron) {
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = Color(0xFFC7C7CC),
                    modifier = Modifier.size(20.dp)
                )
            }
        }
        if (showDivider) {
            HorizontalDivider(
                modifier = Modifier.padding(start = if (icon != null) 56.dp else 16.dp),
                thickness = 0.5.dp,
                color = AppColors.borderSubtle
            )
        }
    }
}

// MARK: - iOS Navigation Bar / Top Bar
@Composable
fun IosTopBar(
    title: String,
    modifier: Modifier = Modifier,
    backText: String? = null,
    onBack: (() -> Unit)? = null,
    actions: @Composable RowScope.() -> Unit = {}
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp)
            .padding(horizontal = 8.dp)
    ) {
        if (onBack != null) {
            Row(
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = onBack
                    )
                    .padding(horizontal = 8.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.ChevronLeft,
                    contentDescription = "Back",
                    tint = AppColors.brandPrimary,
                    modifier = Modifier.size(26.dp)
                )
                if (backText != null) {
                    Text(
                        text = backText,
                        style = AppTypography.body,
                        color = AppColors.brandPrimary
                    )
                }
            }
        }

        Text(
            text = title,
            style = if (onBack == null) AppTypography.largeTitle else AppTypography.headline,
            color = AppColors.textPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .align(if (onBack == null) Alignment.CenterStart else Alignment.Center)
                .padding(horizontal = if (onBack == null) 8.dp else 72.dp)
        )

        Row(
            modifier = Modifier.align(Alignment.CenterEnd),
            verticalAlignment = Alignment.CenterVertically,
            content = actions
        )
    }
}

// MARK: - iOS Text Field Validation State (matching AppTextField.swift)
sealed class ValidationState {
    object Normal : ValidationState()
    object Success : ValidationState()
    data class Error(val message: String) : ValidationState()
}

// MARK: - iOS Text Field (exact match to AppTextField.swift)
@Composable
fun IosTextField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    placeholder: String = "",
    validationState: ValidationState = ValidationState.Normal,
    isSecure: Boolean = false,
    errorMessage: String? = null,
    singleLine: Boolean = true,
    minLines: Int = 1,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    keyboardActions: KeyboardActions = KeyboardActions.Default,
    leadingIcon: (@Composable () -> Unit)? = null,
    trailingIcon: (@Composable () -> Unit)? = null,
    testTag: String? = null
) {
    var passwordVisible by remember { mutableStateOf(false) }
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val isFloating = isFocused || value.isNotEmpty()

    val labelOffset by animateDpAsState(if (isFloating) (-4).dp else 0.dp, label = "labelOffset")
    val labelSize by animateFloatAsState(if (isFloating) 12f else 17f, label = "labelSize")

    val effectiveValidationState = if (errorMessage != null && validationState is ValidationState.Normal) {
        ValidationState.Error(errorMessage)
    } else {
        validationState
    }

    val accentColor = when (effectiveValidationState) {
        is ValidationState.Normal -> if (isFocused) AppColors.brandPrimary else AppColors.borderDefault
        is ValidationState.Error -> AppColors.statusError
        is ValidationState.Success -> AppColors.statusSuccess
    }

    val labelColor = when {
        effectiveValidationState is ValidationState.Error -> AppColors.statusError
        effectiveValidationState is ValidationState.Success -> AppColors.statusSuccess
        isFocused -> AppColors.brandPrimary
        else -> AppColors.textTertiary
    }

    val borderWidth = if (isFocused) 2.dp else 1.dp

    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(AppSpacing.xs)) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(AppRadius.medium))
                .background(AppColors.surfacePrimary)
                .border(BorderStroke(borderWidth, accentColor), RoundedCornerShape(AppRadius.medium))
                .padding(horizontal = AppSpacing.lg, vertical = AppSpacing.md)
        ) {
            Column(Modifier.fillMaxWidth()) {
                Text(
                    text = label,
                    fontSize = labelSize.sp,
                    color = labelColor,
                    modifier = Modifier.offset(y = labelOffset)
                )
                if (isFloating) {
                    Spacer(Modifier.height(2.dp))
                }
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (leadingIcon != null) {
                        leadingIcon()
                        Spacer(Modifier.width(AppSpacing.sm))
                    }
                    Box(modifier = Modifier.weight(1f)) {
                        if (value.isEmpty() && isFloating && placeholder.isNotEmpty()) {
                            Text(
                                text = placeholder,
                                style = AppTypography.body,
                                color = AppColors.textTertiary
                            )
                        }
                        BasicTextField(
                            value = value,
                            onValueChange = onValueChange,
                            modifier = Modifier.fillMaxWidth().then(if (testTag != null) Modifier.testTag(testTag) else Modifier),
                            textStyle = AppTypography.body.copy(color = AppColors.textPrimary),
                            singleLine = singleLine,
                            minLines = minLines,
                            interactionSource = interactionSource,
                            visualTransformation = if (isSecure && !passwordVisible) PasswordVisualTransformation() else VisualTransformation.None,
                            keyboardOptions = keyboardOptions,
                            keyboardActions = keyboardActions,
                            cursorBrush = SolidColor(AppColors.brandPrimary)
                        )
                    }
                    if (isSecure) {
                        IconButton(
                            onClick = { passwordVisible = !passwordVisible },
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = if (passwordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                contentDescription = if (passwordVisible) "Hide password" else "Show password",
                                tint = AppColors.textSecondary,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    } else if (trailingIcon != null) {
                        trailingIcon()
                    }
                }
            }
        }

        // Live validation message row matching AppTextField.swift
        AnimatedVisibility(
            visible = effectiveValidationState !is ValidationState.Normal,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            when (effectiveValidationState) {
                is ValidationState.Success -> {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs),
                        modifier = Modifier.padding(start = 4.dp, top = 2.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.CheckCircle,
                            contentDescription = null,
                            tint = AppColors.statusSuccess,
                            modifier = Modifier.size(14.dp)
                        )
                        Text(
                            text = "Looks good!",
                            style = AppTypography.caption1,
                            color = AppColors.statusSuccess
                        )
                    }
                }
                is ValidationState.Error -> {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(AppSpacing.xs),
                        modifier = Modifier.padding(start = 4.dp, top = 2.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Error,
                            contentDescription = null,
                            tint = AppColors.statusError,
                            modifier = Modifier.size(14.dp)
                        )
                        Text(
                            text = effectiveValidationState.message,
                            style = AppTypography.caption1,
                            color = AppColors.statusError
                        )
                    }
                }
                else -> {}
            }
        }
    }
}

// MARK: - Person Checkmark Composite Icon (matching SF Symbol person.fill.checkmark)
@Composable
fun PersonCheckmarkIcon(
    tint: Color,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier.size(20.dp),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Icons.Default.Person,
            contentDescription = null,
            tint = tint,
            modifier = Modifier
                .size(17.dp)
                .align(Alignment.CenterStart)
        )
        Icon(
            imageVector = Icons.Default.Check,
            contentDescription = null,
            tint = tint,
            modifier = Modifier
                .size(11.dp)
                .align(Alignment.BottomEnd)
        )
    }
}

// MARK: - iOS Primary Button (exact match to PrimaryButton.swift)
enum class IosButtonVariant { Primary, Secondary, Ghost, Destructive }

@Composable
fun IosButton(
    title: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    variant: IosButtonVariant = IosButtonVariant.Primary,
    leadingIcon: ImageVector? = null,
    leadingIconComposable: (@Composable () -> Unit)? = null,
    trailingIcon: ImageVector? = null,
    isEnabled: Boolean = true,
    isLoading: Boolean = false
) {
    val backgroundBrush = when (variant) {
        IosButtonVariant.Primary -> if (isEnabled) AppColors.brandGradient else SolidColor(AppColors.surfaceElevated)
        IosButtonVariant.Secondary -> SolidColor(AppColors.surfaceElevated)
        IosButtonVariant.Ghost -> SolidColor(Color.Transparent)
        IosButtonVariant.Destructive -> SolidColor(AppColors.statusError.copy(alpha = 0.12f))
    }

    val foregroundColor = when {
        !isEnabled -> AppColors.textTertiary
        variant == IosButtonVariant.Primary -> Color.White
        variant == IosButtonVariant.Destructive -> AppColors.statusError
        else -> AppColors.brandPrimary
    }

    val borderColor = when (variant) {
        IosButtonVariant.Secondary -> AppColors.borderDefault
        IosButtonVariant.Ghost -> AppColors.borderDefault
        IosButtonVariant.Destructive -> AppColors.statusError.copy(alpha = 0.4f)
        else -> Color.Transparent
    }

    val shadowModifier = if (variant == IosButtonVariant.Primary && isEnabled) {
        Modifier.shadow(
            elevation = 8.dp,
            shape = RoundedCornerShape(AppRadius.large),
            ambientColor = AppColors.brandPrimary.copy(alpha = 0.35f),
            spotColor = AppColors.brandPrimary.copy(alpha = 0.35f)
        )
    } else Modifier

    Box(
        modifier = modifier
            .then(shadowModifier)
            .fillMaxWidth()
            .height(52.dp)
            .clip(RoundedCornerShape(AppRadius.large))
            .background(backgroundBrush)
            .border(BorderStroke(if (borderColor != Color.Transparent) 1.dp else 0.dp, borderColor), RoundedCornerShape(AppRadius.large))
            .clickable(enabled = isEnabled && !isLoading, onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                color = foregroundColor,
                strokeWidth = 2.dp
            )
        } else {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(AppSpacing.sm)
            ) {
                if (leadingIconComposable != null) {
                    leadingIconComposable()
                } else if (leadingIcon != null) {
                    Icon(
                        imageVector = leadingIcon,
                        contentDescription = null,
                        tint = foregroundColor,
                        modifier = Modifier.size(20.dp)
                    )
                }
                Text(
                    text = title,
                    style = AppTypography.buttonLabel,
                    color = foregroundColor
                )
                if (trailingIcon != null) {
                    Icon(
                        imageVector = trailingIcon,
                        contentDescription = null,
                        tint = foregroundColor,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
}

// MARK: - iOS Pill Mode Picker (exact match to AuthFlowView modePicker)
@Composable
fun IosSegmentedPicker(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppRadius.pill))
            .background(AppColors.surfaceElevated.copy(alpha = 0.75f))
            .border(BorderStroke(1.dp, AppColors.borderSubtle), RoundedCornerShape(AppRadius.pill))
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        options.forEachIndexed { index, title ->
            val isSelected = index == selectedIndex
            val itemBackground = if (isSelected) AppColors.brandGradient else SolidColor(Color.Transparent)
            val shadowMod = if (isSelected) {
                Modifier.shadow(
                    elevation = 8.dp,
                    shape = RoundedCornerShape(AppRadius.pill),
                    ambientColor = AppColors.brandPrimary.copy(alpha = 0.25f),
                    spotColor = AppColors.brandPrimary.copy(alpha = 0.25f)
                )
            } else Modifier

            Box(
                modifier = Modifier
                    .weight(1f)
                    .then(shadowMod)
                    .clip(RoundedCornerShape(AppRadius.pill))
                    .background(itemBackground)
                    .clickable { onSelect(index) }
                    .padding(vertical = 12.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = title,
                    style = AppTypography.buttonLabelSmall,
                    color = if (isSelected) Color.White else AppColors.textSecondary,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

// MARK: - iOS Filter Chip (matching FilterChip in SwiftUI)
@Composable
fun IosFilterChip(
    title: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null
) {
    val backgroundColor = if (isSelected) AppColors.brandPrimary else AppColors.surfaceElevated
    val textColor = if (isSelected) Color.White else AppColors.textPrimary
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(AppRadius.pill))
            .background(backgroundColor)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = textColor,
                modifier = Modifier.size(14.dp)
            )
        }
        Text(
            text = title,
            style = AppTypography.subheadline.copy(fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal),
            color = textColor
        )
    }
}

// MARK: - iOS Modal Alert Dialog (matching screenshot.png)
@Composable
fun IosAlertDialog(
    title: String,
    message: String,
    onDismiss: () -> Unit,
    confirmText: String = "OK",
    onConfirm: () -> Unit = onDismiss
) {
    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(14.dp),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            elevation = CardDefaults.cardElevation(defaultElevation = 24.dp),
            modifier = Modifier.widthIn(min = 270.dp, max = 320.dp)
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(top = 20.dp)
            ) {
                Text(
                    text = title,
                    style = AppTypography.headline.copy(fontWeight = FontWeight.Bold),
                    color = AppColors.textPrimary,
                    textAlign = TextAlign.Center
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    text = message,
                    style = AppTypography.footnote,
                    color = AppColors.textPrimary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
                Spacer(Modifier.height(18.dp))
                HorizontalDivider(thickness = 0.5.dp, color = AppColors.borderSubtle)
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp)
                        .clickable(onClick = onConfirm),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = confirmText,
                        style = AppTypography.headline.copy(fontWeight = FontWeight.SemiBold),
                        color = Color(0xFF007AFF)
                    )
                }
            }
        }
    }
}

// MARK: - iOS Dropdown Selector Button (matching screenshot.png dropdowns)
@Composable
fun IosDropdownSelector(
    label: String,
    value: String,
    options: List<Choice>,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = label,
            style = AppTypography.caption1,
            color = AppColors.textSecondary
        )
        Box {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(AppRadius.small))
                    .background(AppColors.surfaceElevated)
                    .clickable { expanded = true }
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = options.find { it.value == value }?.label ?: value.ifBlank { "Choose" },
                    style = AppTypography.body,
                    color = AppColors.textPrimary
                )
                Icon(
                    imageVector = Icons.Default.UnfoldMore,
                    contentDescription = null,
                    tint = AppColors.textTertiary,
                    modifier = Modifier.size(16.dp)
                )
            }
            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
                modifier = Modifier.background(AppColors.surfacePrimary)
            ) {
                options.forEach { option ->
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = option.label,
                                style = AppTypography.body,
                                color = if (option.value == value) AppColors.brandPrimary else AppColors.textPrimary,
                                fontWeight = if (option.value == value) FontWeight.SemiBold else FontWeight.Normal
                            )
                        },
                        onClick = {
                            onSelect(option.value)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Standard Cards and Badges (matching AppCard.swift)
@Composable
fun IosCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    hasBorderGlow: Boolean = false,
    elevation: Dp = 4.dp,
    contentPadding: Dp = 20.dp,
    content: @Composable ColumnScope.() -> Unit
) {
    val borderColor = if (hasBorderGlow) AppColors.accent.copy(alpha = 0.55f) else AppColors.borderDefault
    val shadowMod = if (elevation > 0.dp) {
        Modifier.shadow(
            elevation = elevation,
            shape = RoundedCornerShape(AppRadius.large),
            ambientColor = Color.Black.copy(alpha = 0.08f),
            spotColor = Color.Black.copy(alpha = 0.16f)
        )
    } else Modifier

    if (onClick != null) {
        Card(
            onClick = onClick,
            modifier = modifier.then(shadowMod),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
            border = BorderStroke(1.dp, borderColor),
            content = { Column(Modifier.padding(contentPadding), content = content) }
        )
    } else {
        Card(
            modifier = modifier.then(shadowMod),
            shape = RoundedCornerShape(AppRadius.large),
            colors = CardDefaults.cardColors(containerColor = AppColors.surfacePrimary),
            elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
            border = BorderStroke(1.dp, borderColor),
            content = { Column(Modifier.padding(contentPadding), content = content) }
        )
    }
}

@Composable
fun IosPill(text: String, selected: Boolean = false) {
    Surface(
        color = if (selected) AppColors.brandPrimary else AppColors.surfaceElevated,
        shape = RoundedCornerShape(AppRadius.pill)
    ) {
        Text(
            text = text,
            color = if (selected) Color.White else AppColors.textSecondary,
            style = AppTypography.subheadline,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp)
        )
    }
}

@Composable
fun AppAvatar(label: String) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(AppColors.brandPrimary),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label.take(1).uppercase(),
            color = Color.White,
            style = AppTypography.headline
        )
    }
}

@Composable
fun SectionHeader(title: String, subtitle: String? = null, action: (@Composable () -> Unit)? = null) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = AppTypography.title2)
            if (subtitle != null) {
                Text(subtitle, style = AppTypography.subheadline, color = AppColors.textSecondary)
            }
        }
        action?.invoke()
    }
}
