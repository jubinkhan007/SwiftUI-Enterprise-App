import SwiftUI

// MARK: - Badge Variant

public enum BadgeVariant {
    case success
    case warning
    case error
    case info
    case neutral
    case custom(color: Color, label: String)

    public var color: Color {
        switch self {
        case .success:              return AppColors.statusSuccess
        case .warning:              return AppColors.statusWarning
        case .error:                return AppColors.statusError
        case .info:                 return AppColors.statusInfo
        case .neutral:              return AppColors.textTertiary
        case .custom(let c, _):     return c
        }
    }

    public var defaultLabel: String {
        switch self {
        case .success:              return "Success"
        case .warning:              return "Warning"
        case .error:                return "Error"
        case .info:                 return "Info"
        case .neutral:              return "Neutral"
        case .custom(_, let l):     return l
        }
    }
}

// MARK: - StatusBadge

public struct StatusBadge: View {
    let variant: BadgeVariant
    let label: String?

    @State private var appeared = false

    public init(_ variant: BadgeVariant, label: String? = nil) {
        self.variant = variant
        self.label = label
    }

    private var displayLabel: String { label ?? variant.defaultLabel }

    public var body: some View {
        Text(displayLabel)
            .font(AppTypography.caption1.weight(.semibold))
            .foregroundColor(variant.color)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(variant.color.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(variant.color.opacity(0.30), lineWidth: 1))
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    appeared = true
                }
            }
    }
}
