import SwiftUI

// MARK: - Avatar Size

public enum AvatarSize {
    case small
    case medium
    case large
    case custom(CGFloat)

    public var dimension: CGFloat {
        switch self {
        case .small:          return 32
        case .medium:         return 44
        case .large:          return 64
        case .custom(let d):  return d
        }
    }

    var font: Font {
        switch self {
        case .small:          return AppTypography.caption1
        case .medium:         return AppTypography.subheadline
        case .large:          return AppTypography.title3
        case .custom(let d):  return .system(size: d * 0.35, weight: .semibold, design: .rounded)
        }
    }
}

// MARK: - AppAvatar

public struct AppAvatar: View {
    let name: String
    let size: AvatarSize

    public init(name: String, size: AvatarSize = .medium) {
        self.name = name
        self.size = size
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap(\.first)).uppercased()
    }

    /// Deterministic gradient derived from the name's hash
    private var gradientColors: [Color] {
        let hash = abs(name.hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = (hue1 + 0.15).truncatingRemainder(dividingBy: 1.0)
        return [
            Color(hue: hue1, saturation: 0.65, brightness: 0.75),
            Color(hue: hue2, saturation: 0.70, brightness: 0.65)
        ]
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initials)
                .font(size.font)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(Circle())
    }
}
