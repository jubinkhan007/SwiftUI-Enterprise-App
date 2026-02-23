import SwiftUI

// MARK: - EmptyStateView

public struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    let ctaTitle: String?
    let ctaAction: (() -> Void)?

    @State private var appeared = false

    public init(
        icon: String,
        title: String,
        description: String,
        ctaTitle: String? = nil,
        ctaAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.ctaTitle = ctaTitle
        self.ctaAction = ctaAction
    }

    public var body: some View {
        VStack(spacing: AppSpacing.xl) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(AppColors.brandPrimary.opacity(0.10))
                    .frame(width: 104, height: 104)

                Circle()
                    .fill(AppColors.brandPrimary.opacity(0.06))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AppColors.brandGradient)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            // Text
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            .offset(y: appeared ? 0 : 12)
            .opacity(appeared ? 1 : 0)

            // CTA
            if let ctaTitle, let ctaAction {
                AppButton(ctaTitle, variant: .primary, action: ctaAction)
                    .padding(.horizontal, AppSpacing.xxl)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .padding(AppSpacing.xl)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}
