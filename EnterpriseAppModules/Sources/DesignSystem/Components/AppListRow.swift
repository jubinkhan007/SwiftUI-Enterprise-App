import SwiftUI

// MARK: - List Row Accessory

public enum AppListRowAccessory {
    case chevron
    case toggle(Binding<Bool>)
    case badge(String)
    case none
}

// MARK: - AppListRow

public struct AppListRow: View {
    let icon: String?
    let iconColor: Color
    let title: String
    let subtitle: String?
    let accessory: AppListRowAccessory
    let action: (() -> Void)?

    public init(
        icon: String? = nil,
        iconColor: Color = AppColors.brandPrimary,
        title: String,
        subtitle: String? = nil,
        accessory: AppListRowAccessory = .chevron,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
        self.action = action
    }

    public var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: AppSpacing.lg) {
                // Leading icon badge
                if let icon {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                            .fill(iconColor.opacity(0.14))
                            .frame(width: 36, height: 36)

                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                }

                // Title + subtitle
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                // Trailing accessory
                accessoryView
            }
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(SpringScaleButtonStyle())
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(AppTypography.caption1.weight(.semibold))
                .foregroundColor(AppColors.textTertiary)

        case .toggle(let binding):
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(AppColors.brandPrimary)

        case .badge(let text):
            StatusBadge(.neutral, label: text)

        case .none:
            EmptyView()
        }
    }
}
