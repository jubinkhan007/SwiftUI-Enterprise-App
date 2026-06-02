import SwiftUI
import DesignSystem
import SharedModels

/// Shown to viewers when any remote participant is actively screen-sharing.
/// Supports pinch-to-zoom on the placeholder; real SDKs render the screen
/// track inside the `presenterFrame` ZStack.
public struct ScreenSharePresenterView: View {
    public let presenter: RemoteCallParticipant

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    public init(presenter: RemoteCallParticipant) {
        self.presenter = presenter
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.on.rectangle.fill")
                    .foregroundColor(AppColors.brandPrimary)
                Text("\(presenter.displayName) is sharing their screen")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.black.opacity(0.85))

            presenterFrame
                .scaleEffect(scale)
                .gesture(magnification)
                .clipped()
        }
        .background(Color.black)
    }

    private var presenterFrame: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.gray.opacity(0.4)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "display")
                    .appFont(AppTypography.largeTitle)
                    .foregroundColor(.white.opacity(0.5))
                Text("SCREEN SHARE")
                    .appFont(AppTypography.overline)
                    .foregroundColor(.white.opacity(0.6))
                Text("Real screen frames render here once the LiveKit SDK is linked.")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(0.5, min(4.0, lastScale * value))
            }
            .onEnded { _ in
                lastScale = scale
            }
    }
}
