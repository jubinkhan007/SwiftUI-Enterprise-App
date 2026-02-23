import SwiftUI

public struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var isLoading: Bool = false

    public init(title: String, isEnabled: Bool = true, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(AppTypography.buttonLabel)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isEnabled {
                        AppColors.brandGradient
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
            )
            .foregroundColor(isEnabled ? .white : .gray)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: isEnabled ? AppColors.primary.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!isEnabled || isLoading)
        .buttonStyle(SpringScaleButtonStyle())
    }
}

// Micro-animation for standard buttons
public struct SpringScaleButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}
