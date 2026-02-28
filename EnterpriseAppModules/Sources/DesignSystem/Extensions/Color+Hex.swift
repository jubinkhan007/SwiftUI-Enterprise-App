import SwiftUI

public extension Color {
    /// Initializes a `Color` from a hex string like `"#RRGGBB"` or `"RRGGBB"`.
    /// If alpha is omitted, it is assumed to be `FF`.
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if cleaned.count == 6 { cleaned = "FF" + cleaned }
        guard cleaned.count == 8, let int = UInt64(cleaned, radix: 16) else { return nil }

        let a = Double((int & 0xFF000000) >> 24) / 255.0
        let r = Double((int & 0x00FF0000) >> 16) / 255.0
        let g = Double((int & 0x0000FF00) >> 8) / 255.0
        let b = Double(int & 0x000000FF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
