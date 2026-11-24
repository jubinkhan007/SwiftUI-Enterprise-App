import SwiftUI
import SharedModels
import DesignSystem

/// Self-service "Security & Sessions" sheet.
/// Shows every active login for the signed-in user and lets them revoke any of them.
public struct SecuritySessionsView: View {
    @StateObject private var viewModel: SecuritySessionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var toast: ToastMessage?
    @State private var showRevokeOthersConfirm = false

    public init() {
        self._viewModel = StateObject(wrappedValue: SecuritySessionsViewModel())
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                content
            }
            .navigationTitle("Security & Sessions")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .confirmationDialog(
                "Revoke this session?",
                isPresented: Binding(
                    get: { viewModel.sessionPendingRevoke != nil },
                    set: { if !$0 { viewModel.sessionPendingRevoke = nil } }
                ),
                titleVisibility: .visible,
                presenting: viewModel.sessionPendingRevoke
            ) { session in
                Button("Revoke Session", role: .destructive) {
                    Task {
                        if await viewModel.revoke(session) {
                            toast = ToastMessage(type: .success, title: "Session revoked", message: "\(session.clientLabel) has been signed out.")
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { session in
                Text("\(session.clientLabel) (\(session.ipAddress)) will be signed out and must log in again. If this is the device you're using now, you'll be signed out too.")
            }
            .confirmationDialog(
                "Sign out all other devices?",
                isPresented: $showRevokeOthersConfirm,
                titleVisibility: .visible
            ) {
                Button("Revoke All Other Sessions", role: .destructive) {
                    Task {
                        let count = await viewModel.revokeAllOtherSessions()
                        if count > 0 {
                            toast = ToastMessage(type: .success, title: "Other devices signed out", message: "Revoked \(count) other active session\(count == 1 ? "" : "s").")
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every active login except your current session will be terminated immediately.")
            }
            .toast($toast)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.sessions.isEmpty {
            ProgressView()
                .tint(AppColors.brandPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.brandPrimary)
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Active sessions")
                                .appFont(AppTypography.headline)
                                .foregroundColor(AppColors.textPrimary)
                            Text("These devices are currently signed in to your account across \(max(1, viewModel.distinctIPCount)) IP address\(viewModel.distinctIPCount == 1 ? "" : "es"). Revoke any session you don't recognise.")
                                .appFont(AppTypography.caption1)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)

                    if viewModel.anomalousSessionsCount > 0 {
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(AppColors.statusWarning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Security Anomaly Alert")
                                    .appFont(AppTypography.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.statusWarning)
                                Text("\(viewModel.anomalousSessionsCount) session\(viewModel.anomalousSessionsCount == 1 ? "" : "s") flagged for unusual IP, automated client, or age >30 days.")
                                    .appFont(AppTypography.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if viewModel.sessions.count > 1 {
                        Button(role: .destructive) {
                            showRevokeOthersConfirm = true
                        } label: {
                            HStack {
                                if viewModel.isRevokingOthers {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "person.badge.minus")
                                }
                                Text("Sign Out All Other Devices (\(viewModel.sessions.count - 1))")
                                    .appFont(AppTypography.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(viewModel.isRevokingOthers)
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.statusError)
                    }
                }

                Section("\(viewModel.sessions.count) active") {
                    if viewModel.sessions.isEmpty {
                        Text("No active sessions found.")
                            .appFont(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        ForEach(viewModel.sessions) { session in
                            sessionRow(session)
                        }
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .scrollContentBackground(.hidden)
        }
    }

    private func sessionRow(_ session: UserSessionDTO) -> some View {
        let anomalies = viewModel.anomalyReasons(for: session)
        let isPrimary = session.id == viewModel.primarySessionId

        return HStack(spacing: AppSpacing.md) {
            Image(systemName: session.deviceSymbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(anomalies.isEmpty ? AppColors.brandPrimary : AppColors.statusWarning)
                .frame(width: 36, height: 36)
                .background((anomalies.isEmpty ? AppColors.brandPrimary : AppColors.statusWarning).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.clientLabel)
                        .appFont(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    if isPrimary {
                        Text("CURRENT")
                            .appFont(AppTypography.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.statusSuccess.opacity(0.15))
                            .foregroundColor(AppColors.statusSuccess)
                            .cornerRadius(4)
                    }
                }
                Text(session.ipAddress.isEmpty ? "Unknown IP" : session.ipAddress)
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textSecondary)

                if !anomalies.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(anomalies, id: \.self) { flag in
                            Text(flag)
                                .appFont(AppTypography.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.statusWarning.opacity(0.16))
                                .foregroundColor(AppColors.statusWarning)
                                .cornerRadius(4)
                        }
                    }
                }

                if let created = session.createdAt {
                    Text("Signed in \(created.formatted(.relative(presentation: .named)))")
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
                Text("Expires \(session.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()

            if viewModel.revokingIds.contains(session.id) {
                ProgressView()
            } else {
                Button {
                    viewModel.sessionPendingRevoke = session
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(AppColors.statusError)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Revoke session on \(session.clientLabel)")
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.sessionPendingRevoke = session
            } label: {
                Label("Revoke", systemImage: "xmark.circle")
            }
        }
    }
}

