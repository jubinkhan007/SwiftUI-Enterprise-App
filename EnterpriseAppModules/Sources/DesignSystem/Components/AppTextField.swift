import SwiftUI

// MARK: - Validation State

public enum TextFieldValidationState: Equatable {
    case normal
    case error(String)
    case success

    var stateIndex: Int {
        switch self {
        case .normal:  return 0
        case .success: return 1
        case .error:   return 2
        }
    }
}

// MARK: - AppTextField

public struct AppTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    let validationState: TextFieldValidationState
    let isSecure: Bool

    @FocusState private var isFocused: Bool
    @State private var isSecureVisible = false

    public init(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        validationState: TextFieldValidationState = .normal,
        isSecure: Bool = false
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.validationState = validationState
        self.isSecure = isSecure
    }

    private var isFloating: Bool { isFocused || !text.isEmpty }

    private var accentColor: Color {
        switch validationState {
        case .normal:  return isFocused ? AppColors.brandPrimary : AppColors.borderDefault
        case .error:   return AppColors.statusError
        case .success: return AppColors.statusSuccess
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ZStack(alignment: .leading) {
                // Floating label
                Text(label)
                    .font(isFloating ? AppTypography.caption1 : AppTypography.body)
                    .foregroundColor(isFloating ? accentColor : AppColors.textTertiary)
                    .offset(y: isFloating ? -22 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFloating)

                // Input
                HStack {
                    Group {
                        if isSecure && !isSecureVisible {
                            SecureField(isFloating ? placeholder : "", text: $text)
                        } else {
                            TextField(isFloating ? placeholder : "", text: $text)
                        }
                    }
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                    .focused($isFocused)
                    .padding(.top, AppSpacing.lg)

                    if isSecure {
                        Button {
                            isSecureVisible.toggle()
                        } label: {
                            Image(systemName: isSecureVisible ? "eye.slash" : "eye")
                                .foregroundColor(AppColors.textSecondary)
                                .font(AppTypography.callout)
                        }
                        .padding(.top, AppSpacing.lg)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(accentColor, lineWidth: isFocused ? 2 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            )

            // Validation message
            Group {
                switch validationState {
                case .error(let message):
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(message)
                    }
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.statusError)
                    .transition(.move(edge: .top).combined(with: .opacity))

                case .success:
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Looks good!")
                    }
                    .font(AppTypography.caption1)
                    .foregroundColor(AppColors.statusSuccess)
                    .transition(.move(edge: .top).combined(with: .opacity))

                case .normal:
                    EmptyView()
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: validationState.stateIndex)
        }
    }
}
