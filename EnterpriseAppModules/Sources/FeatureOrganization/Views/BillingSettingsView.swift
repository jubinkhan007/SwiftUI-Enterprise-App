import SwiftUI
import SharedModels
import DesignSystem
import AppNetwork

/// Billing and Subscription management screen for workspaces.
/// Provides Stripe Checkout upgrade flow, Customer Portal management,
/// quota progress indicators, and plan tier comparisons.
public struct BillingSettingsView: View {
    @StateObject private var viewModel: BillingSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    public init(orgId: UUID) {
        self._viewModel = StateObject(wrappedValue: BillingSettingsViewModel(orgId: orgId))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Error message
                        if let error = viewModel.errorMessage {
                            errorMessageView(error)
                        }

                        // Current Subscription Summary Card
                        currentPlanCard

                        // Pricing Plans Header
                        VStack(spacing: AppSpacing.xxs) {
                            Text("Available Plans")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.textPrimary)
                            Text("Scale your team seamlessly with flexible monthly billing")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppSpacing.sm)

                        // Tier Cards
                        tierCardsSection

                        // Features Matrix Section
                        featuresMatrixSection

                        // Security & Billing Info Footer
                        securityFooterSection
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.lg)
                }
            }
            .navigationTitle("Subscription & Billing")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await viewModel.loadBillingInfo()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(AppColors.brandPrimary)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadBillingInfo()
            }
        }
    }

    // MARK: - Current Plan Card

    private var currentPlanCard: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: AppSpacing.xs) {
                        Text("Current Plan")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.textSecondary)

                        Text(viewModel.currentTier.uppercased())
                            .font(AppTypography.caption1.weight(.bold))
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 2)
                            .background(tierBadgeColor.opacity(0.15))
                            .foregroundColor(tierBadgeColor)
                            .clipShape(Capsule())
                    }

                    Text(viewModel.isPro ? "Pro Subscription" : (viewModel.isEnterprise ? "Enterprise Workspace" : "Free Starter Plan"))
                        .font(AppTypography.title2.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.brandPrimary)
            }

            Divider()
                .overlay(AppColors.borderSubtle)

            // Quota Gauge
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("Team Member Seats")
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Text(viewModel.isPro || viewModel.isEnterprise ? "\(viewModel.memberCount) used (Unlimited)" : "\(viewModel.memberCount) / 5 seats used")
                        .font(AppTypography.caption1.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.backgroundSecondary)
                            .frame(height: 8)

                        Capsule()
                            .fill(viewModel.memberQuotaFraction >= 1.0 && !viewModel.isPro ? AppColors.statusWarning : AppColors.brandPrimary)
                            .frame(width: max(geo.size.width * CGFloat(viewModel.memberQuotaFraction), 8), height: 8)
                    }
                }
                .frame(height: 8)
            }

            // Action Buttons
            HStack(spacing: AppSpacing.sm) {
                if viewModel.isPro || viewModel.isEnterprise {
                    Button {
                        Task {
                            if let url = await viewModel.manageSubscription() {
                                openURL(url)
                            }
                        }
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            if viewModel.isRedirecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.up.right.square")
                            }
                            Text("Manage via Stripe Portal")
                        }
                        .font(AppTypography.callout.weight(.semibold))
                        .foregroundColor(AppColors.brandPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.brandPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    }
                    .disabled(viewModel.isRedirecting)
                } else {
                    Button {
                        Task {
                            if let url = await viewModel.upgradeToPro() {
                                openURL(url)
                            }
                        }
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            if viewModel.isRedirecting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text("Upgrade to Pro ($19/mo)")
                        }
                        .font(AppTypography.callout.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    }
                    .disabled(viewModel.isRedirecting)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.backgroundSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(AppColors.borderDefault, lineWidth: 1)
        )
    }

    // MARK: - Tier Cards Section

    private var tierCardsSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Free Tier
            planCardView(
                title: "Free",
                price: "$0",
                period: "forever",
                badge: nil,
                isHighlighted: false,
                isCurrent: viewModel.isFree,
                features: [
                    "Up to 5 team members",
                    "3 active workspaces & projects",
                    "5 GB encrypted cloud storage",
                    "Task boards & list views",
                    "Community support"
                ],
                buttonTitle: viewModel.isFree ? "Current Plan" : "Downgrade",
                buttonEnabled: false,
                action: {}
            )

            // Pro Tier
            planCardView(
                title: "Pro",
                price: "$19",
                period: "per org / month",
                badge: "MOST POPULAR",
                isHighlighted: true,
                isCurrent: viewModel.isPro && !viewModel.isEnterprise,
                features: [
                    "Unlimited team members",
                    "Unlimited projects & boards",
                    "100 GB encrypted storage",
                    "Agile Sprints, Epics & Kanban",
                    "Video conferencing & screen share",
                    "Priority 24/7 technical support"
                ],
                buttonTitle: viewModel.isPro && !viewModel.isEnterprise ? "Manage in Stripe" : "Upgrade to Pro ($19/mo)",
                buttonEnabled: true,
                action: {
                    Task {
                        if viewModel.isPro {
                            if let url = await viewModel.manageSubscription() {
                                openURL(url)
                            }
                        } else {
                            if let url = await viewModel.upgradeToPro() {
                                openURL(url)
                            }
                        }
                    }
                }
            )

            // Enterprise Tier
            planCardView(
                title: "Enterprise",
                price: "$99",
                period: "per org / month",
                badge: "ENTERPRISE",
                isHighlighted: false,
                isCurrent: viewModel.isEnterprise,
                features: [
                    "Everything in Pro included",
                    "Custom SAML / Okta SSO integration",
                    "Full audit log compliance & export",
                    "99.99% guaranteed uptime SLA",
                    "Dedicated Customer Success Manager",
                    "Custom invoicing & billing terms"
                ],
                buttonTitle: "Contact Sales",
                buttonEnabled: true,
                action: {
                    if let url = URL(string: "mailto:sales@taskflow.example.com?subject=Enterprise%20Plan%20Inquiry") {
                        openURL(url)
                    }
                }
            )
        }
    }

    private func planCardView(
        title: String,
        price: String,
        period: String,
        badge: String?,
        isHighlighted: Bool,
        isCurrent: Bool,
        features: [String],
        buttonTitle: String,
        buttonEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(title)
                            .font(AppTypography.title3.weight(.bold))
                            .foregroundColor(AppColors.textPrimary)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 3)
                                .background(AppColors.brandPrimary.opacity(0.18))
                                .foregroundColor(AppColors.brandPrimary)
                                .clipShape(Capsule())
                        }

                        if isCurrent {
                            Text("ACTIVE")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 3)
                                .background(AppColors.statusSuccess.opacity(0.18))
                                .foregroundColor(AppColors.statusSuccess)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(price)
                            .font(AppTypography.largeTitle.weight(.heavy))
                            .foregroundColor(AppColors.textPrimary)

                        Text("/ " + period)
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()
            }

            Divider()
                .overlay(AppColors.borderSubtle)

            // Features List
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(features, id: \.self) { feat in
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isHighlighted ? AppColors.brandPrimary : AppColors.statusSuccess)

                        Text(feat)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            .padding(.vertical, AppSpacing.xxs)

            // Button
            Button {
                action()
            } label: {
                HStack {
                    if viewModel.isRedirecting && isHighlighted {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(buttonTitle)
                }
                .font(AppTypography.callout.weight(.bold))
                .foregroundColor(isHighlighted ? .white : (isCurrent ? AppColors.textTertiary : AppColors.brandPrimary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    isHighlighted
                        ? AppColors.brandPrimary
                        : (isCurrent ? AppColors.backgroundSecondary : AppColors.brandPrimary.opacity(0.12))
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            }
            .disabled(!buttonEnabled || viewModel.isRedirecting)
        }
        .padding(AppSpacing.md)
        .background(
            isHighlighted
                ? AppColors.brandPrimary.opacity(0.04)
                : AppColors.backgroundSecondary.opacity(0.4)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(
                    isHighlighted ? AppColors.brandPrimary : AppColors.borderDefault,
                    lineWidth: isHighlighted ? 1.8 : 1
                )
        )
    }

    // MARK: - Features Matrix Section

    private var featuresMatrixSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Feature Comparison")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: 0) {
                featureRow(name: "Team Members", free: "5", pro: "Unlimited", enterprise: "Unlimited")
                Divider().overlay(AppColors.borderSubtle)
                featureRow(name: "Encrypted Storage", free: "5 GB", pro: "100 GB", enterprise: "Unlimited")
                Divider().overlay(AppColors.borderSubtle)
                featureRow(name: "Agile Sprints & Epics", free: "—", pro: "Included", enterprise: "Included")
                Divider().overlay(AppColors.borderSubtle)
                featureRow(name: "Video & Screen Sharing", free: "—", pro: "Included", enterprise: "Included")
                Divider().overlay(AppColors.borderSubtle)
                featureRow(name: "SAML / Okta SSO", free: "—", pro: "—", enterprise: "Included")
                Divider().overlay(AppColors.borderSubtle)
                featureRow(name: "Audit Logging Export", free: "—", pro: "—", enterprise: "Included")
            }
            .background(AppColors.backgroundSecondary.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(AppColors.borderDefault, lineWidth: 1)
            )
        }
        .padding(.top, AppSpacing.sm)
    }

    private func featureRow(name: String, free: String, pro: String, enterprise: String) -> some View {
        HStack {
            Text(name)
                .font(AppTypography.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(free)
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 55, alignment: .center)

            Text(pro)
                .font(AppTypography.caption1.weight(.semibold))
                .foregroundColor(AppColors.brandPrimary)
                .frame(width: 65, alignment: .center)

            Text(enterprise)
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 65, alignment: .center)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Security Footer

    private var securityFooterSection: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(AppColors.statusSuccess)
                .font(.system(size: 20))

            Text("All transactions are securely handled by Stripe with 256-bit SSL encryption. Cancel or modify anytime.")
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var tierBadgeColor: Color {
        if viewModel.isEnterprise {
            return AppColors.statusWarning
        } else if viewModel.isPro {
            return AppColors.brandPrimary
        } else {
            return AppColors.textSecondary
        }
    }

    private func errorMessageView(_ msg: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.statusWarning)
            Text(msg)
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.statusError)
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.statusError.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }
}
