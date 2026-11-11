import SwiftUI
import SharedModels
import DesignSystem
import AppNetwork

public struct ReleaseManagementView: View {
    @StateObject private var viewModel: ReleaseManagementViewModel
    @State private var showCreateSheet = false

    public init(projectId: UUID) {
        _viewModel = StateObject(wrappedValue: ReleaseManagementViewModel(projectId: projectId))
    }

    public var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if viewModel.isLoading && viewModel.releases.isEmpty {
                ProgressView().padding()
            } else if let error = viewModel.error, viewModel.releases.isEmpty {
                VStack(spacing: 12) {
                    Text("Couldn’t load releases.")
                        .appFont(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text(error.localizedDescription)
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await viewModel.refresh() } }
                        .appFont(AppTypography.headline)
                        .foregroundColor(AppColors.brandPrimary)
                }
                .padding()
            } else {
                List {
                    Section {
                        Picker("Status", selection: $viewModel.statusFilter) {
                            Text("All (\(viewModel.releases.count))").tag(ReleaseStatus?.none)
                            ForEach(ReleaseStatus.allCases, id: \.self) { status in
                                Text("\(status.rawValue.capitalized)").tag(ReleaseStatus?.some(status))
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        if viewModel.filteredReleases.isEmpty {
                            Text("No releases found.")
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            ForEach(viewModel.filteredReleases) { release in
                                NavigationLink {
                                    ReleaseDetailView(release: release, onChanged: {
                                        Task { await viewModel.refresh() }
                                    })
                                } label: {
                                    ReleaseRow(
                                        release: release,
                                        progress: viewModel.progressByReleaseId[release.id]
                                    )
                                }
                                .contextMenu {
                                    if release.status == .unreleased {
                                        Button {
                                            Task { try? await viewModel.finalizeRelease(releaseId: release.id, lock: true) }
                                        } label: {
                                            Label("Ship & Lock Version", systemImage: "paperplane.fill")
                                        }
                                    }
                                    Button {
                                        Task {
                                            try? await viewModel.updateRelease(
                                                releaseId: release.id,
                                                payload: UpdateReleaseRequest(isLocked: !release.isLocked)
                                            )
                                        }
                                    } label: {
                                        Label(release.isLocked ? "Unlock Scope" : "Lock Scope", systemImage: release.isLocked ? "lock.open" : "lock.fill")
                                    }
                                    if release.status != .archived {
                                        Button(role: .destructive) {
                                            Task {
                                                try? await viewModel.updateRelease(
                                                    releaseId: release.id,
                                                    payload: UpdateReleaseRequest(status: .archived)
                                                )
                                            }
                                        } label: {
                                            Label("Archive Release", systemImage: "archivebox")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Releases")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Label("New Release", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateReleaseSheet(viewModel: viewModel)
        }
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }
}

private struct CreateReleaseSheet: View {
    @ObservedObject var viewModel: ReleaseManagementViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var descriptionText: String = ""
    @State private var hasTargetDate: Bool = true
    @State private var releaseDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Version Details") {
                    TextField("Version Name (e.g. v2.4.0)", text: $name)
                    TextField("Release Goals & Scope", text: $descriptionText, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Schedule") {
                    Toggle("Set Target Release Date", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Target Date", selection: $releaseDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("New Release")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Creating…" : "Create") {
                        isSubmitting = true
                        Task {
                            try? await viewModel.createRelease(
                                name: name,
                                description: descriptionText.isEmpty ? nil : descriptionText,
                                releaseDate: hasTargetDate ? releaseDate : nil
                            )
                            isSubmitting = false
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
    }
}

private struct ReleaseRow: View {
    let release: ReleaseDTO
    let progress: ReleaseProgressDTO?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(release.name)
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(release.status.rawValue.capitalized)
                    .appFont(AppTypography.caption2)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            if let progress {
                let issuesProgress = progress.totalIssues > 0 ? Double(progress.doneIssues) / Double(progress.totalIssues) : 0
                ProgressView(value: issuesProgress) {
                    HStack {
                        Text("\(progress.doneIssues)/\(progress.totalIssues) issues")
                        Spacer()
                        Text("\(progress.donePoints)/\(max(progress.totalPoints, 0)) pts")
                    }
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textSecondary)
                }
                .tint(AppColors.brandPrimary)

                HStack(spacing: 12) {
                    if progress.criticalBugCount > 0 {
                        Text("Critical bugs: \(progress.criticalBugCount)")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.statusError)
                    } else if progress.bugCount > 0 {
                        Text("Bugs: \(progress.bugCount)")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if release.isLocked {
                        Text("Locked")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            } else {
                Text("Loading progress…")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch release.status {
        case .unreleased: return AppColors.brandPrimary
        case .released: return AppColors.statusSuccess
        case .archived: return AppColors.textTertiary
        }
    }
}
