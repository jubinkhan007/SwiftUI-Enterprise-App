import SwiftUI
import SharedModels
import DesignSystem

/// Self-service "Security & Sessions" sheet.
/// Shows every active login for the signed-in user and lets them revoke any of them.
public struct SecuritySessionsView: View {
    @StateObject private var viewModel: SecuritySessionsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var toast: ToastMessage?

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
                            Text("These devices are currently signed in to your account. Revoke any session you don't recognise.")
                                .appFont(AppTypography.caption1)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
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
        HStack(spacing: AppSpacing.md) {
            Image(systemName: session.deviceSymbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppColors.brandPrimary)
                .frame(width: 36, height: 36)
                .background(AppColors.brandPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.clientLabel)
                    .appFont(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)
                Text(session.ipAddress.isEmpty ? "Unknown IP" : session.ipAddress)
                    .appFont(AppTypography.caption1)
                    .foregroundColor(AppColors.textSecondary)
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

