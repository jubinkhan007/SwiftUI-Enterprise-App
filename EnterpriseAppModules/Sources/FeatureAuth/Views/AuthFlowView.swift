import Data
import DesignSystem
import Domain
import Network
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct AuthFlowView: View {
    @StateObject private var authManager: AuthManager

    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""

    @State private var toast: ToastMessage?

    @FocusState private var focus: FocusField?

    public init(authManager: AuthManager) {
        self._authManager = StateObject(wrappedValue: authManager)
    }

    public init(configuration: APIConfiguration = .localVapor) {
        let service = LiveAuthService.mappedErrors(configuration: configuration)
        self._authManager = StateObject(wrappedValue: AuthManager(authService: service))
    }

    public var body: some View {
        ZStack {
            AuthBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    header
                        .padding(.top, AppSpacing.xxxl)
                        .fadeSlideIn(delay: 0.05, offset: 18)

                    modePicker
                        .fadeSlideIn(delay: 0.10, offset: 18)

                    formCard
                        .fadeSlideIn(delay: 0.15, offset: 18)

                    footer
                        .padding(.bottom, AppSpacing.xxxl)
                        .fadeSlideIn(delay: 0.20, offset: 18)
                }
                .padding(.horizontal, AppSpacing.xl)
            }
        }
        .toast($toast)
        .loadingOverlay(authManager.isSubmitting, message: mode == .login ? "Signing in…" : "Creating account…")
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.brandGlowGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: AppColors.brandPrimary.opacity(0.35), radius: 16, x: 0, y: 10)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(spacing: AppSpacing.xs) {
                Text("Enterprise App")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)

                Text("Secure access for modern teams.")
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 0) {
            modePillButton(title: "Sign in", mode: .login)
            modePillButton(title: "Create account", mode: .register)
        }
        .padding(4)
        .background(AppColors.surfaceElevated.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
    }

    private func modePillButton(title: String, mode: AuthMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                self.mode = mode
            }
            hapticLight()
            resetValidationFocus()
        } label: {
            Text(title)
                .font(AppTypography.buttonLabelSmall)
                .foregroundColor(self.mode == mode ? .white : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background {
                    if self.mode == mode {
                        AppColors.brandGradient
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
                            .shadow(color: AppColors.brandPrimary.opacity(0.25), radius: 14, x: 0, y: 8)
                    } else {
                        Color.clear
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Form

    private var formCard: some View {
        AppCard(elevation: .high, hasBorderGlow: true) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text(mode == .login ? "Welcome back" : "Create your account")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)

                VStack(spacing: AppSpacing.lg) {
                    if mode == .register {
                        AppTextField(
                            "Display name",
                            text: $displayName,
                            placeholder: "Jane Doe",
                            validationState: displayNameValidation
                        )
                        .platformTextInputAutocapitalization(.words)
                        .platformAutocorrectionDisabled()
                        .focused($focus, equals: .displayName)
                        .submitLabel(.next)
                        .onSubmit { focus = .email }
                    }

                    AppTextField(
                        "Email",
                        text: $email,
                        placeholder: "name@company.com",
                        validationState: emailValidation
                    )
                    .platformTextInputAutocapitalization(.never)
                    .platformKeyboardType(.emailAddress)
                    .platformAutocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }

                    AppTextField(
                        "Password",
                        text: $password,
                        placeholder: "••••••••",
                        validationState: passwordValidation,
                        isSecure: true
                    )
                    .platformTextInputAutocapitalization(.never)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { submit() }
                }

                AppButton(
                    mode == .login ? "Sign in" : "Create account",
                    variant: .primary,
                    leadingIcon: mode == .login ? "person.fill.checkmark" : "person.fill.badge.plus",
                    isEnabled: canSubmit,
                    isLoading: authManager.isSubmitting
                ) {
                    submit()
                }

                if mode == .login {
                    Button {
                        toast = ToastMessage(
                            type: .info,
                            title: "Password reset",
                            message: "Not implemented yet."
                        )
                    } label: {
                        Text("Forgot password?")
                            .font(AppTypography.caption1)
                            .foregroundColor(AppColors.brandPrimary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, AppSpacing.xs)
                }
            }
            .padding(AppSpacing.xl)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("By continuing, you agree to your organization’s security policies.")
                .font(AppTypography.caption1)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Validation

    private var emailValidation: TextFieldValidationState {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .normal }
        return Validators.isValidEmail(trimmed) ? .success : .error("Enter a valid email.")
    }

    private var passwordValidation: TextFieldValidationState {
        guard !password.isEmpty else { return .normal }
        return Validators.isValidPassword(password) ? .success : .error("Must be 8+ characters.")
    }

    private var displayNameValidation: TextFieldValidationState {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .normal }
        return Validators.isValidDisplayName(trimmed) ? .success : .error("Display name is required.")
    }

    private var canSubmit: Bool {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Validators.isValidEmail(e) else { return false }
        guard Validators.isValidPassword(password) else { return false }
        if mode == .register, !Validators.isValidDisplayName(n) { return false }
        return true
    }

    // MARK: - Actions

    private func submit() {
        guard canSubmit else {
            toast = ToastMessage(type: .warning, title: "Check your details", message: "Please fix the highlighted fields.")
            return
        }
        focus = nil

        Task {
            do {
                switch mode {
                case .login:
                    try await authManager.signIn(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password
                    )
                    toast = ToastMessage(type: .success, title: "Signed in", message: "Welcome back, \(authManager.session?.user.displayName ?? "there").")

                case .register:
                    try await authManager.register(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password,
                        displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    toast = ToastMessage(type: .success, title: "Account created", message: "Welcome, \(authManager.session?.user.displayName ?? "there").")
                }
            } catch let error as AuthError {
                toast = ToastMessage(type: .error, title: "Authentication failed", message: error.localizedDescription)
            } catch {
                toast = ToastMessage(type: .error, title: "Authentication failed", message: String(describing: error))
            }
        }
    }

    private func resetValidationFocus() {
        focus = nil
        password = ""
    }

    private func hapticLight() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

private enum AuthMode {
    case login
    case register
}

private enum FocusField: Hashable {
    case displayName
    case email
    case password
}

private struct AuthBackground: View {
    var body: some View {
        ZStack {
            AppColors.backgroundPrimary

            AppColors.brandGlowGradient
                .opacity(0.18)
                .blur(radius: 40)

            Circle()
                .fill(AppColors.accentGlow)
                .frame(width: 180, height: 180)
                .offset(x: -130, y: -240)
                .blur(radius: 2)

            Circle()
                .fill(AppColors.accentGlow)
                .frame(width: 220, height: 220)
                .offset(x: 140, y: 120)
                .blur(radius: 2)
        }
    }
}

private enum PlatformAutocapitalization {
    case never
    case words
}

private enum PlatformKeyboardType {
    case emailAddress
}

private extension View {
    @ViewBuilder
    func platformTextInputAutocapitalization(_ style: PlatformAutocapitalization) -> some View {
        #if canImport(UIKit)
        switch style {
        case .never:
            self.textInputAutocapitalization(.never)
        case .words:
            self.textInputAutocapitalization(.words)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformKeyboardType(_ type: PlatformKeyboardType) -> some View {
        #if canImport(UIKit)
        switch type {
        case .emailAddress:
            self.keyboardType(.emailAddress)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func platformAutocorrectionDisabled() -> some View {
        #if canImport(UIKit)
        self.autocorrectionDisabled()
        #else
        self
        #endif
    }
}
