import SwiftUI

// MARK: - Card Elevation

public enum AppCardElevation {
    case low
    case medium
    case high

    var shadowRadius: CGFloat {
        switch self {
        case .low:    return 4
        case .medium: return 12
        case .high:   return 24
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .low:    return 2
        case .medium: return 6
        case .high:   return 12
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .low:    return 0.08
        case .medium: return 0.14
        case .high:   return 0.22
        }
    }
}

// MARK: - AppCard

/// Glassmorphism card using `.ultraThinMaterial` with optional border glow.
public struct AppCard<Content: View>: View {
    let content: Content
    let elevation: AppCardElevation
    let hasBorderGlow: Bool
    let cornerRadius: CGFloat

    public init(
        elevation: AppCardElevation = .medium,
        hasBorderGlow: Bool = false,
        cornerRadius: CGFloat = AppRadius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.elevation = elevation
        self.hasBorderGlow = hasBorderGlow
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        hasBorderGlow
                            ? AppColors.accent.opacity(0.55)
                            : AppColors.borderDefault,
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

// MARK: - Sectioned Card

/// Card with optional header, content body, and footer slots.
public struct AppSectionedCard<CardHeader: View, CardBody: View, CardFooter: View>: View {
    let cardHeader: CardHeader?
    let cardBody: CardBody
    let cardFooter: CardFooter?
    let elevation: AppCardElevation
    let hasBorderGlow: Bool

    public init(
        elevation: AppCardElevation = .medium,
        hasBorderGlow: Bool = false,
        @ViewBuilder header: () -> CardHeader,
        @ViewBuilder body: () -> CardBody,
        @ViewBuilder footer: () -> CardFooter
    ) {
        self.elevation = elevation
        self.hasBorderGlow = hasBorderGlow
        self.cardHeader = header()
        self.cardBody = body()
        self.cardFooter = footer()
    }

    public var body: some View {
        AppCard(elevation: elevation, hasBorderGlow: hasBorderGlow) {
            VStack(spacing: 0) {
                if let cardHeader {
                    cardHeader
                        .padding(AppSpacing.lg)
                    Divider().overlay(AppColors.borderSubtle)
                }
                cardBody
                    .padding(AppSpacing.lg)
                if let cardFooter {
                    Divider().overlay(AppColors.borderSubtle)
                    cardFooter
                        .padding(AppSpacing.lg)
                }
            }
        }
    }
}
