import SwiftUI

// MARK: - Shimmer Skeleton

/// Drop-in placeholder for loading content. Use as a background for any shape.
public struct ShimmerView: View {
    let cornerRadius: CGFloat
    @State private var phase: CGFloat = 0

    public init(cornerRadius: CGFloat = AppRadius.medium) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppColors.surfaceElevated)
            .overlay(
                GeometryReader { geo in
                    let w = geo.size.width
                    let gw = w * 0.45
                    LinearGradient(
                        colors: [.clear, AppColors.textPrimary.opacity(0.06), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: gw)
                    .offset(x: phase * (w + gw) - gw)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Pulsing Dots

public struct PulsingDotsView: View {
    let color: Color
    let dotSize: CGFloat
    @State private var animating = false

    public init(color: Color = AppColors.brandPrimary, dotSize: CGFloat = 10) {
        self.color = color
        self.dotSize = dotSize
    }

    public var body: some View {
        HStack(spacing: dotSize * 0.8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.18),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - Spinner Overlay

/// Full-screen overlay with blur backdrop and centered spinner.
public struct SpinnerOverlayView: View {
    let message: String?

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.40).ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(AppColors.brandPrimary)

                if let message {
                    Text(message)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .padding(AppSpacing.xxl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        }
    }
}

// MARK: - Loading Overlay Modifier

public struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool
    let message: String?

    public func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
            if isLoading {
                SpinnerOverlayView(message: message)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLoading)
    }
}

public extension View {
    func loadingOverlay(_ isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
    }
}
