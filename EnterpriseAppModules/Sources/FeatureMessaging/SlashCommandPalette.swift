import SwiftUI
import DesignSystem

/// Overlay rendered above ChatInputBar when the user types `/`.
/// Filters the built-in command catalog and dispatches the picked spec
/// back to the parent via the `onPick` closure.
public struct SlashCommandPalette: View {
    let filter: String
    let onPick: (SlashCommandSpec) -> Void

    public init(filter: String, onPick: @escaping (SlashCommandSpec) -> Void) {
        self.filter = filter
        self.onPick = onPick
    }

    public var body: some View {
        let matches = SlashCommandRegistry.shared.matches(for: filter)
        VStack(alignment: .leading, spacing: 0) {
            if matches.isEmpty {
                Text("No matching commands.")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(AppSpacing.md)
            } else {
                ForEach(matches.prefix(7)) { spec in
                    Button {
                        onPick(spec)
                    } label: {
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            Text("/\(spec.name)")
                                .appFont(AppTypography.body)
                                .foregroundColor(AppColors.brandPrimary)
                                .frame(width: 90, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(spec.summary)
                                    .appFont(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textPrimary)
                                Text(spec.usage)
                                    .appFont(AppTypography.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceElevated)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppColors.borderDefault),
            alignment: .top
        )
    }
}
