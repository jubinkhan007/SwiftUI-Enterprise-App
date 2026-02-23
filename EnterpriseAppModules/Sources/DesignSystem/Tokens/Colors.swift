import SwiftUI

#if canImport(UIKit)
import UIKit

private func adaptive(
    light: (h: Double, s: Double, b: Double),
    dark: (h: Double, s: Double, b: Double)
) -> Color {
    Color(UIColor { trait in
        let c = trait.userInterfaceStyle == .dark ? dark : light
        return UIColor(hue: c.h, saturation: c.s, brightness: c.b, alpha: 1)
    })
}

private func adaptiveWhite(light: Double, dark: Double, alpha: Double = 1) -> Color {
    Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: dark, alpha: alpha)
            : UIColor(white: light, alpha: alpha)
    })
}

private func adaptiveAlpha(light: Double, dark: Double, isWhite: Bool) -> Color {
    Color(UIColor { trait in
        let a = trait.userInterfaceStyle == .dark ? dark : light
        return isWhite ? UIColor(white: 1, alpha: a) : UIColor(white: 0, alpha: a)
    })
}

#else

private func adaptive(
    light: (h: Double, s: Double, b: Double),
    dark: (h: Double, s: Double, b: Double)
) -> Color {
    Color(hue: dark.h, saturation: dark.s, brightness: dark.b)
}

private func adaptiveWhite(light: Double, dark: Double, alpha: Double = 1) -> Color {
    Color(white: dark, opacity: alpha)
}

private func adaptiveAlpha(light: Double, dark: Double, isWhite: Bool) -> Color {
    isWhite ? Color.white.opacity(dark) : Color.black.opacity(dark)
}

#endif

// MARK: - AppColors

public enum AppColors {

    // MARK: Brand
    /// Deep indigo-violet — primary brand color
    public static let brandPrimary = adaptive(
        light: (h: 0.694, s: 0.80, b: 0.80),
        dark:  (h: 0.694, s: 0.72, b: 0.92)
    )

    public static let brandSecondary = adaptive(
        light: (h: 0.694, s: 0.55, b: 0.65),
        dark:  (h: 0.694, s: 0.50, b: 0.72)
    )

    /// Electric teal — accent highlight
    public static let accent = adaptive(
        light: (h: 0.473, s: 0.90, b: 0.70),
        dark:  (h: 0.473, s: 1.00, b: 0.85)
    )

    // MARK: Background
    public static let backgroundPrimary = adaptive(
        light: (h: 0.0, s: 0.0, b: 1.0),
        dark:  (h: 0.633, s: 0.30, b: 0.07)   // Deep dark navy
    )

    public static let backgroundSecondary = adaptive(
        light: (h: 0.0, s: 0.0, b: 0.96),
        dark:  (h: 0.633, s: 0.25, b: 0.11)
    )

    public static let backgroundTertiary = adaptive(
        light: (h: 0.0, s: 0.0, b: 0.92),
        dark:  (h: 0.633, s: 0.20, b: 0.15)
    )

    // MARK: Surface
    public static let surfacePrimary = adaptive(
        light: (h: 0.0, s: 0.0, b: 1.00),
        dark:  (h: 0.633, s: 0.22, b: 0.13)
    )

    public static let surfaceElevated = adaptive(
        light: (h: 0.0, s: 0.0, b: 0.97),
        dark:  (h: 0.633, s: 0.18, b: 0.18)
    )

    // MARK: Text
    public static let textPrimary   = adaptiveWhite(light: 0.08, dark: 0.95)
    public static let textSecondary = adaptiveWhite(light: 0.35, dark: 0.70)
    public static let textTertiary  = adaptiveWhite(light: 0.55, dark: 0.50)
    public static let textOnBrand   = Color.white

    // MARK: Border
    public static let borderDefault = adaptiveAlpha(light: 0.10, dark: 0.10, isWhite: false)
    public static let borderSubtle  = adaptiveAlpha(light: 0.06, dark: 0.06, isWhite: false)

    // MARK: Status
    public static let statusSuccess = adaptive(
        light: (h: 0.38, s: 0.80, b: 0.55),
        dark:  (h: 0.38, s: 0.75, b: 0.75)
    )

    public static let statusWarning = adaptive(
        light: (h: 0.11, s: 0.90, b: 0.80),
        dark:  (h: 0.11, s: 0.90, b: 0.95)
    )

    public static let statusError = adaptive(
        light: (h: 0.01, s: 0.85, b: 0.75),
        dark:  (h: 0.01, s: 0.80, b: 0.90)
    )

    public static let statusInfo = adaptive(
        light: (h: 0.60, s: 0.75, b: 0.70),
        dark:  (h: 0.60, s: 0.70, b: 0.90)
    )

    // MARK: Gradients
    public static let brandGradient = LinearGradient(
        colors: [brandPrimary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let surfaceGradient = LinearGradient(
        colors: [surfacePrimary, surfaceElevated],
        startPoint: .top,
        endPoint: .bottom
    )

    public static let accentGlow = RadialGradient(
        colors: [accent.opacity(0.30), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 80
    )

    public static let brandGlowGradient = LinearGradient(
        colors: [brandPrimary, brandSecondary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
