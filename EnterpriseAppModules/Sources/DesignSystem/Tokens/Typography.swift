import SwiftUI

public enum AppTypography {
    public static let titleLarge = Font.system(size: 34, weight: .bold, design: .rounded)
    public static let titleMedium = Font.system(size: 28, weight: .bold, design: .rounded)
    public static let titleSmall = Font.system(size: 22, weight: .semibold, design: .rounded)

    public static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    public static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    public static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)
    
    public static let buttonLabel = Font.system(size: 17, weight: .semibold, design: .rounded)
}
