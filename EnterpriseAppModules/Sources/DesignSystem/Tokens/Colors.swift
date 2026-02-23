import SwiftUI

public enum AppColors {
    // Brand Colors
    public static let primary = Color("BrandPrimary", bundle: .module)
    public static let accent = Color("BrandAccent", bundle: .module)

    // Backgrounds
    public static let backgroundPrimary = Color("BackgroundPrimary", bundle: .module)
    public static let backgroundSecondary = Color("BackgroundSecondary", bundle: .module)
    
    // Text
    public static let textPrimary = Color("TextPrimary", bundle: .module)
    public static let textSecondary = Color("TextSecondary", bundle: .module)

    // Gradients
    public static let brandGradient = LinearGradient(
        colors: [primary, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
