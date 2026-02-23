import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Button Style Variants

public enum AppButtonVariant {
    case primary
    case secondary
    case ghost
    case destructive
}

// MARK: - AppButton

public struct AppButton: View {
    let title: String
    let variant: AppButtonVariant
    let leadingIcon: String?
    let trailingIcon: String?
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    public init(
        _ title: String,
        variant: AppButtonVariant = .primary,
        leadingIcon: String? = nil,
        trailingIcon: String? = nil,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button {
            triggerHaptic()
            action()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                        .scaleEffect(0.85)
                } else {
                    if let icon = leadingIcon {
                        Image(systemName: icon)
                            .font(AppTypography.buttonLabel)
                    }
                    Text(title)
                        .font(AppTypography.buttonLabel)
                    if let icon = trailingIcon {
                        Image(systemName: icon)
                            .font(AppTypography.buttonLabel)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .padding(.horizontal, AppSpacing.xl)
            .background(backgroundView)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: shadowColor, radius: 10, x: 0, y: 4)
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(SpringScaleButtonStyle())
        .opacity(isEnabled ? 1 : 0.5)
    }

    // MARK: - Helpers

    private func triggerHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch variant {
        case .primary:
            if isEnabled {
                AppColors.brandGradient
            } else {
                AppColors.surfaceElevated
            }
        case .secondary:
            AppColors.surfaceElevated
        case .ghost:
            Color.clear
        case .destructive:
            AppColors.statusError.opacity(0.12)
        }
    }

    private var foregroundColor: Color {
        guard isEnabled else { return AppColors.textTertiary }
        switch variant {
        case .primary:     return .white
        case .secondary:   return AppColors.brandPrimary
        case .ghost:       return AppColors.brandPrimary
        case .destructive: return AppColors.statusError
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary:   return AppColors.borderDefault
        case .ghost:       return AppColors.borderDefault
        case .destructive: return AppColors.statusError.opacity(0.4)
        default:           return .clear
        }
    }

    private var borderWidth: CGFloat {
        switch variant {
        case .secondary, .ghost, .destructive: return 1
        default: return 0
        }
    }

    private var shadowColor: Color {
        guard isEnabled else { return .clear }
        switch variant {
        case .primary: return AppColors.brandPrimary.opacity(0.35)
        default:       return .clear
        }
    }
}

// MARK: - SpringScaleButtonStyle

public struct SpringScaleButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.90 : 1.0)
            .animation(
                .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0),
                value: configuration.isPressed
            )
    }
}

// MARK: - Backwards Compatibility Alias

@available(*, deprecated, renamed: "AppButton")
public typealias PrimaryButton = AppButton
