import SwiftUI

// MARK: - .appCard()

public struct AppCardModifier: ViewModifier {
    let elevation: AppCardElevation
    let borderGlow: Bool

    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(
                        borderGlow ? AppColors.accent.opacity(0.55) : AppColors.borderDefault,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: .black.opacity(elevation.shadowOpacity),
                radius: elevation.shadowRadius,
                x: 0,
                y: elevation.shadowY
            )
    }
}

// MARK: - .shimmer()

public struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let gw = geo.size.width * 0.5
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.12), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: gw)
                    .offset(x: phase * (geo.size.width + gw) - gw)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - .fadeSlideIn()

public struct FadeSlideInModifier: ViewModifier {
    let delay: Double
    let offset: CGFloat
    @State private var appeared = false

    public func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : offset)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(delay)) {
                    appeared = true
                }
            }
    }
}

// MARK: - .glowBorder()

public struct GlowBorderModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    @State private var pulsing = false

    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(color.opacity(pulsing ? 0.80 : 0.30), lineWidth: 1.5)
                    .shadow(color: color.opacity(pulsing ? 0.55 : 0.15), radius: radius)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

// MARK: - View Extensions

public extension View {

    /// Apply glassmorphism card styling (background + border + shadow).
    func appCard(
        elevation: AppCardElevation = .medium,
        borderGlow: Bool = false
    ) -> some View {
        modifier(AppCardModifier(elevation: elevation, borderGlow: borderGlow))
    }

    /// Animated shimmer pass — use on skeleton placeholders.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    /// Spring entrance: fades + slides up from `offset` points below.
    func fadeSlideIn(delay: Double = 0, offset: CGFloat = 16) -> some View {
        modifier(FadeSlideInModifier(delay: delay, offset: offset))
    }

    /// Animated pulsing border glow.
    func glowBorder(
        color: Color = AppColors.accent,
        radius: CGFloat = 8
    ) -> some View {
        modifier(GlowBorderModifier(color: color, radius: radius))
    }
}
