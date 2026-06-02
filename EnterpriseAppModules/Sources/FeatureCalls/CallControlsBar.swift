import SwiftUI
import DesignSystem
import SharedModels

/// Bottom control bar for the in-call screen: mic, camera, screen-share,
/// host menu, and hang up.
public struct CallControlsBar: View {
    @ObservedObject var store: CallSessionStore
    public let isHost: Bool
    public let onShowHostControls: () -> Void
    public let onHangUp: () -> Void

    public init(store: CallSessionStore, isHost: Bool, onShowHostControls: @escaping () -> Void, onHangUp: @escaping () -> Void) {
        self.store = store
        self.isHost = isHost
        self.onShowHostControls = onShowHostControls
        self.onHangUp = onHangUp
    }

    public var body: some View {
        HStack(spacing: AppSpacing.lg) {
            circle(
                icon: store.managerState.localAudioMuted ? "mic.slash.fill" : "mic.fill",
                bg: store.managerState.localAudioMuted ? Color.red : Color.gray.opacity(0.6)
            ) {
                Task { await store.toggleAudioMute() }
            }
            circle(
                icon: store.managerState.localVideoMuted ? "video.slash.fill" : "video.fill",
                bg: store.managerState.localVideoMuted ? Color.red : Color.gray.opacity(0.6)
            ) {
                Task { await store.toggleVideoMute() }
            }
            circle(
                icon: store.managerState.isScreenSharing ? "rectangle.on.rectangle.fill" : "rectangle.on.rectangle",
                bg: store.managerState.isScreenSharing ? AppColors.brandPrimary : Color.gray.opacity(0.6)
            ) {
                Task { await store.toggleScreenShare() }
            }
            if isHost {
                circle(icon: "person.3.fill", bg: Color.gray.opacity(0.6)) {
                    onShowHostControls()
                }
            }
            Button(action: onHangUp) {
                Image(systemName: "phone.down.fill")
                    .appFont(AppTypography.title3)
                    .frame(width: 56, height: 56)
                    .foregroundColor(.white)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.85))
    }

    private func circle(icon: String, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .appFont(AppTypography.title3)
                .frame(width: 56, height: 56)
                .foregroundColor(.white)
                .background(bg)
                .clipShape(Circle())
        }
    }
}
