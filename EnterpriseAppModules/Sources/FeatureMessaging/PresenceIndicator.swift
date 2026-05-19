import SwiftUI
import SharedModels
import DesignSystem

/// Small colored dot reflecting a user's presence state.
public struct PresenceIndicator: View {
    public let state: PresenceState
    public var size: CGFloat = 10

    public init(state: PresenceState, size: CGFloat = 10) {
        self.state = state
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle().stroke(AppColors.backgroundPrimary, lineWidth: 1)
            )
            .accessibilityLabel(label)
    }

    private var color: Color {
        switch state {
        case .online: return .green
        case .away: return .orange
        case .offline: return Color.gray.opacity(0.6)
        }
    }

    private var label: String {
        switch state {
        case .online: return "Online"
        case .away: return "Away"
        case .offline: return "Offline"
        }
    }
}

/// Compact "emoji · text" inline display of a custom status.
public struct CustomStatusBadge: View {
    public let presence: UserPresenceDTO

    public init(presence: UserPresenceDTO) {
        self.presence = presence
    }

    public var body: some View {
        if presence.customStatusEmoji != nil || presence.customStatusText != nil {
            HStack(spacing: 4) {
                if let emoji = presence.customStatusEmoji {
                    Text(emoji)
                }
                if let text = presence.customStatusText {
                    Text(text)
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
        } else {
            EmptyView()
        }
    }
}
