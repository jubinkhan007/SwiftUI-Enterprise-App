import SwiftUI

public enum AppBannerStyle: Sendable {
    case info
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .info: return AppColors.statusInfo
        case .success: return AppColors.statusSuccess
        case .warning: return AppColors.statusWarning
        case .error: return AppColors.statusError
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

public struct AppBanner: View {
    let message: String
    let style: AppBannerStyle

    public init(message: String, style: AppBannerStyle) {
        self.message = message
        self.style = style
    }

    public var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: style.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(style.color)

            Text(message)
                .font(AppTypography.callout)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.lg)
        .background(style.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(style.color.opacity(0.25), lineWidth: 1)
        )
    }
}

public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.buttonLabel)
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.lg)
            .foregroundColor(.white)
            .background(AppColors.brandGradient)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.buttonLabel)
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.lg)
            .foregroundColor(AppColors.brandPrimary)
            .background(AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(AppColors.borderDefault, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

