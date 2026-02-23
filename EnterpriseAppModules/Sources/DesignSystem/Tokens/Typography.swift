import SwiftUI

// MARK: - AppTypography

public enum AppTypography {

    // MARK: Display / Headings — SF Pro Rounded
    public static let largeTitle  = Font.system(size: 34, weight: .bold,     design: .rounded)
    public static let title1      = Font.system(size: 28, weight: .bold,     design: .rounded)
    public static let title2      = Font.system(size: 22, weight: .semibold, design: .rounded)
    public static let title3      = Font.system(size: 20, weight: .semibold, design: .rounded)
    public static let headline    = Font.system(size: 17, weight: .semibold, design: .rounded)

    // MARK: Body / Content — SF Pro
    public static let body        = Font.system(size: 17, weight: .regular,  design: .default)
    public static let callout     = Font.system(size: 16, weight: .regular,  design: .default)
    public static let subheadline = Font.system(size: 15, weight: .regular,  design: .default)
    public static let footnote    = Font.system(size: 13, weight: .regular,  design: .default)
    public static let caption1    = Font.system(size: 12, weight: .regular,  design: .default)
    public static let caption2    = Font.system(size: 11, weight: .regular,  design: .default)

    // MARK: Special-purpose
    public static let buttonLabel      = Font.system(size: 17, weight: .semibold, design: .rounded)
    public static let buttonLabelSmall = Font.system(size: 15, weight: .semibold, design: .rounded)
    public static let overline         = Font.system(size: 11, weight: .semibold, design: .default)
    public static let mono             = Font.system(size: 14, weight: .regular,  design: .monospaced)
}

// MARK: - View + Text Helpers

public extension View {
    func appFont(_ font: Font) -> some View {
        self.font(font)
    }
}

public extension Text {
    func appFont(_ font: Font) -> Text {
        self.font(font)
    }
}
