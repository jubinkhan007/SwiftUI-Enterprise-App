import SwiftUI

// MARK: - Toast Type

public enum ToastType {
    case success, error, info, warning

    public var color: Color {
        switch self {
        case .success: return AppColors.statusSuccess
        case .error:   return AppColors.statusError
        case .info:    return AppColors.statusInfo
        case .warning: return AppColors.statusWarning
        }
    }

    public var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - ToastMessage

public struct ToastMessage: Identifiable, Equatable {
    public let id = UUID()
    public let type: ToastType
    public let title: String
    public let message: String?
    public let duration: TimeInterval

    public init(
        type: ToastType,
        title: String,
        message: String? = nil,
        duration: TimeInterval = 3.0
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
    }

    public static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ToastView

public struct ToastView: View {
    let toast: ToastMessage

    public init(_ toast: ToastMessage) {
        self.toast = toast
    }

    public var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: toast.type.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(toast.type.color)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(toast.title)
                    .font(AppTypography.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)

                if let message = toast.message {
                    Text(message)
                        .font(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(AppSpacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(toast.type.color.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 8)
        .padding(.horizontal, AppSpacing.lg)
    }
}

// MARK: - Toast Modifier

public struct ToastContainerModifier: ViewModifier {
    @Binding var toast: ToastMessage?
    @State private var isShowing = false

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let currentToast = toast, isShowing {
                    ToastView(currentToast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, AppSpacing.lg)
                        .zIndex(1000)
                }
            }
            .onChange(of: toast) { _, newToast in
                if newToast != nil {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isShowing = true
                    }
                    let duration = newToast?.duration ?? 3.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isShowing = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            toast = nil
                        }
                    }
                }
            }
    }
}

public extension View {
    func toast(_ toast: Binding<ToastMessage?>) -> some View {
        modifier(ToastContainerModifier(toast: toast))
    }
}
