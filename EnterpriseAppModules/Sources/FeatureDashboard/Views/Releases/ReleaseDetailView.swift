import SwiftUI
import SharedModels
import DesignSystem
import AppNetwork

struct ReleaseDetailView: View {
    let release: ReleaseDTO

    @State private var progress: ReleaseProgressDTO? = nil
    @State private var issues: [TaskItemDTO] = []
    @State private var isLoading = false
    @State private var error: Error?

    @State private var releaseNotesMarkdown: String = ""
    @State private var showNotesPreview = false
    @State private var showShareSheet = false
    @State private var toast: ToastMessage? = nil

    private let apiClient: APIClientProtocol = APIClient()
    private let apiConfiguration: APIConfiguration = .localVapor

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary.ignoresSafeArea()

            if isLoading && progress == nil {
                ProgressView().padding()
            } else if let error, progress == nil {
                VStack(spacing: 12) {
                    Text("Couldn’t load release.")
                        .appFont(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text(error.localizedDescription)
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await refresh() } }
                        .appFont(AppTypography.headline)
                        .foregroundColor(AppColors.brandPrimary)
                }
                .padding()
            } else {
                List {
                    overviewSection
                    progressSection
                    issuesSection
                    notesSection
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(release.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
        .sheet(isPresented: $showNotesPreview) {
            NavigationStack {
                ZStack {
                    AppColors.backgroundPrimary.ignoresSafeArea()
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Release Notes (Markdown)")
                            .appFont(AppTypography.headline)
                            .foregroundColor(AppColors.textPrimary)
                        TextEditor(text: $releaseNotesMarkdown)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(AppSpacing.sm)
                            .background(AppColors.surfacePrimary)
                            .cornerRadius(AppRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(AppColors.borderDefault, lineWidth: 1)
                            )
                    }
                    .padding()
                }
                .navigationTitle("Release Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showNotesPreview = false }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Share") { showShareSheet = true }
                            .foregroundColor(AppColors.brandPrimary)
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(activityItems: [releaseNotesMarkdown])
                }
            }
        }
        .toast($toast)
    }

    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if let date = release.releaseDate {
                    Text("Planned: \(date.formatted(date: .abbreviated, time: .omitted))")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }
                if release.status == .released, let releasedAt = release.releasedAt {
                    Text("Released: \(releasedAt.formatted(date: .abbreviated, time: .shortened))")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                }
                if let desc = release.description, !desc.isEmpty {
                    Text(desc)
                        .appFont(AppTypography.body)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("Overview")
        }
    }

    private var progressSection: some View {
        Section {
            if let p = progress {
                let issuesProgress = p.totalIssues > 0 ? Double(p.doneIssues) / Double(p.totalIssues) : 0
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: issuesProgress) {
                        HStack {
                            Text("\(p.doneIssues)/\(p.totalIssues) issues")
                            Spacer()
                            Text("\(p.donePoints)/\(max(p.totalPoints, 0)) pts")
                        }
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.textSecondary)
                    }
                    .tint(AppColors.brandPrimary)

                    HStack(spacing: 12) {
                        Text("Remaining: \(p.remainingIssues)")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Bugs: \(p.bugCount)")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.textSecondary)
                        if p.criticalBugCount > 0 {
                            Text("Critical: \(p.criticalBugCount)")
                                .appFont(AppTypography.caption2)
                                .foregroundColor(AppColors.statusError)
                        }
                    }
                }
                .padding(.vertical, 6)
            } else {
                Text("Loading…")
                    .foregroundColor(AppColors.textTertiary)
            }
        } header: {
            Text("Progress")
        }
    }

    private var issuesSection: some View {
        Section {
            if issues.isEmpty {
                Text("No issues linked to this release yet.")
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(issues) { t in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            if let key = t.issueKey {
                                Text(key)
                                    .appFont(AppTypography.caption1)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            Text(t.title)
                                .appFont(AppTypography.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                        }
                        Text(t.status.displayName)
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        } header: {
            Text("Issues")
        }
    }

    private var notesSection: some View {
        Section {
            Button {
                releaseNotesMarkdown = buildReleaseNotesMarkdown(release: release, progress: progress, issues: issues)
                showNotesPreview = true
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Generate Release Notes")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColors.textTertiary)
                }
                .appFont(AppTypography.subheadline)
                .foregroundColor(AppColors.brandPrimary)
            }
            .disabled(issues.isEmpty)

            if issues.isEmpty {
                Text("Link issues to this release (Affected Version) to generate notes.")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
        } header: {
            Text("Release Notes")
        }
    }

    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            async let p: ReleaseProgressDTO? = try fetchProgress()
            async let i: [TaskItemDTO] = try fetchIssues()
            let (progress, issues) = try await (p, i)
            self.progress = progress
            self.issues = issues
        } catch {
            self.error = error
        }
    }

    private func fetchProgress() async throws -> ReleaseProgressDTO? {
        let endpoint = ReleaseEndpoint.progress(releaseId: release.id, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<ReleaseProgressDTO>.self)
        return response.data
    }

    private func fetchIssues() async throws -> [TaskItemDTO] {
        let endpoint = ReleaseEndpoint.issues(releaseId: release.id, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[TaskItemDTO]>.self)
        return response.data ?? []
    }

    private func buildReleaseNotesMarkdown(release: ReleaseDTO, progress: ReleaseProgressDTO?, issues: [TaskItemDTO]) -> String {
        var lines: [String] = []

        lines.append("# Release Notes — \(release.name)")
        if let date = release.releaseDate {
            lines.append("")
            lines.append("_Planned: \(date.formatted(date: .long, time: .omitted))_")
        }
        if release.status == .released, let releasedAt = release.releasedAt {
            lines.append("")
            lines.append("_Released: \(releasedAt.formatted(date: .long, time: .shortened))_")
        }

        if let progress {
            lines.append("")
            lines.append("## Summary")
            lines.append("- Issues: \(progress.doneIssues)/\(progress.totalIssues) done")
            lines.append("- Points: \(progress.donePoints)/\(progress.totalPoints) done")
            lines.append("- Bugs: \(progress.bugCount) (critical: \(progress.criticalBugCount))")
        }

        let done = issues.filter { $0.status == .done }
        let remaining = issues.filter { $0.status != .done }

        func bullet(_ task: TaskItemDTO) -> String {
            let key = task.issueKey.map { "\($0) — " } ?? ""
            return "- \(key)\(task.title)"
        }

        if !done.isEmpty {
            lines.append("")
            lines.append("## Completed")
            for t in done { lines.append(bullet(t)) }
        }
        if !remaining.isEmpty {
            lines.append("")
            lines.append("## In Progress / Remaining")
            for t in remaining { lines.append(bullet(t)) }
        }

        return lines.joined(separator: "\n")
    }
}
