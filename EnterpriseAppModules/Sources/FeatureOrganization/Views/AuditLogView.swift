import SwiftUI
import SharedModels
import DesignSystem

/// Organization Audit Log viewer for Owners and Admins.
/// Supports category filtering, full-text search, and live WebSocket streaming.
public struct AuditLogView: View {
    @StateObject private var viewModel: AuditLogViewModel
    @Environment(\.dismiss) private var dismiss

    public init(orgId: UUID) {
        self._viewModel = StateObject(wrappedValue: AuditLogViewModel(orgId: orgId))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundPrimary.ignoresSafeArea()
                content
            }
            .navigationTitle("Audit Log")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $viewModel.searchText, prompt: "Filter by action, actor, or details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            categoryFilterBar

            if viewModel.isLoading && viewModel.logs.isEmpty {
                ProgressView()
                    .tint(AppColors.brandPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        HStack(spacing: AppSpacing.sm) {
                            Circle()
                                .fill(AppColors.statusSuccess)
                                .frame(width: 8, height: 8)
                            Text("Live stream active — new security & governance events appear automatically.")
                                .appFont(AppTypography.caption1)
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            if !viewModel.liveEventIds.isEmpty {
                                Text("+\(viewModel.liveEventIds.count) live")
                                    .appFont(AppTypography.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppColors.statusSuccess.opacity(0.15))
                                    .foregroundColor(AppColors.statusSuccess)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .appFont(AppTypography.caption1)
                                .foregroundColor(AppColors.statusError)
                        }
                    }

                    Section("\(viewModel.filteredLogs.count) entries") {
                        if viewModel.filteredLogs.isEmpty {
                            Text("No matching audit entries.")
                                .appFont(AppTypography.body)
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            ForEach(viewModel.filteredLogs) { entry in
                                auditRow(entry)
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
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(AuditCategory.allCases) { category in
                    let isSelected = viewModel.selectedCategory == category
                    Button {
                        viewModel.selectedCategory = category
                    } label: {
                        Text(category.rawValue)
                            .appFont(AppTypography.caption1)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 6)
                            .background(isSelected ? AppColors.brandPrimary : AppColors.surfaceElevated)
                            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColors.surfacePrimary)
    }

    private func auditRow(_ entry: AuditLogDTO) -> some View {
        let color = actionColor(for: entry.action)
        let isLive = viewModel.liveEventIds.contains(entry.id)

        return HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: entry.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.action)
                        .appFont(AppTypography.caption1)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.14))
                        .foregroundColor(color)
                        .clipShape(Capsule())

                    if isLive {
                        Text("LIVE")
                            .appFont(AppTypography.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.statusSuccess.opacity(0.18))
                            .foregroundColor(AppColors.statusSuccess)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if let created = entry.createdAt {
                        Text(created.formatted(.relative(presentation: .named)))
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                if let details = entry.details, !details.isEmpty {
                    Text(details)
                        .appFont(AppTypography.subheadline)
                        .foregroundColor(AppColors.textPrimary)
                }

                HStack(spacing: 6) {
                    Text(entry.userEmail.isEmpty ? "system" : entry.userEmail)
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                    Text("·")
                        .foregroundColor(AppColors.textTertiary)
                    Text(entry.resourceType + (entry.resourceId.map { " #\($0.uuidString.prefix(8))" } ?? ""))
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func actionColor(for action: String) -> Color {
        let a = action.lowercased()
        if a.contains("delete") || a.contains("remove") || a.contains("revoke") || a.contains("suspend") {
            return AppColors.statusError
        }
        if a.contains("lock") || a.contains("archive") || a.contains("purge") {
            return AppColors.statusWarning
        }
        if a.contains("create") || a.contains("invite") || a.contains("accept") {
            return AppColors.statusSuccess
        }
        return AppColors.brandPrimary
    }
}

