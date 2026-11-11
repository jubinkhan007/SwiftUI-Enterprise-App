import SwiftUI
import SharedModels
import DesignSystem
import AppNetwork

struct ReleaseDetailView: View {
    let release: ReleaseDTO
    var onChanged: (() -> Void)? = nil

    @State private var currentRelease: ReleaseDTO
    @State private var progress: ReleaseProgressDTO? = nil
    @State private var issues: [TaskItemDTO] = []
    @State private var changelog: ReleaseChangelogDTO? = nil
    @State private var isLoading = false
    @State private var error: Error?

    @State private var releaseNotesMarkdown: String = ""
    @State private var showNotesPreview = false
    @State private var showShareSheet = false
    @State private var showShipConfirmation = false
    @State private var lockOnShip = true
    @State private var toast: ToastMessage? = nil

    private let apiClient: APIClientProtocol = APIClient()
    private let apiConfiguration: APIConfiguration = .current

    init(release: ReleaseDTO, onChanged: (() -> Void)? = nil) {
        self.release = release
        self.onChanged = onChanged
        _currentRelease = State(initialValue: release)
    }

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
                    readinessGateSection
                    overviewSection
                    progressSection
                    releaseActionsSection
                    issuesSection
                    notesSection
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(currentRelease.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task { await refresh() }
        .refreshable { await refresh() }
        .confirmationDialog("Ship \(currentRelease.name)?", isPresented: $showShipConfirmation, titleVisibility: .visible) {
            Button("Ship & Lock Scope") {
                Task { await finalizeRelease(lock: true) }
            }
            Button("Ship Without Locking") {
                Task { await finalizeRelease(lock: false) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Marking this release as Released stamps the completion timestamp and publishes the changelog.")
        }
        .sheet(isPresented: $showNotesPreview) {
            NavigationStack {
                ZStack {
                    AppColors.backgroundPrimary.ignoresSafeArea()
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack {
                            Text("Release Notes (Markdown)")
                                .appFont(AppTypography.headline)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Button {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = releaseNotesMarkdown
                                #endif
                                toast = ToastMessage(type: .success, title: "Copied", message: "Copied Markdown to clipboard")
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .appFont(AppTypography.caption1)
                            }
                        }
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
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
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

    private var readinessGateSection: some View {
        Section {
            let criticalCount = progress?.criticalBugCount ?? 0
            let blockers = changelog?.blockers ?? (criticalCount > 0 ? ["\(criticalCount) unresolved critical bug(s) in scope."] : [])
            let isReady = blockers.isEmpty

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: isReady ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(isReady ? AppColors.statusSuccess : AppColors.statusError)
                    Text(isReady ? "Deployment Gate: Ready to Ship" : "Deployment Gate: Blocked")
                        .appFont(AppTypography.subheadline)
                        .foregroundColor(isReady ? AppColors.statusSuccess : AppColors.statusError)
                    Spacer()
                    if currentRelease.isLocked {
                        Label("Scope Locked", systemImage: "lock.fill")
                            .appFont(AppTypography.caption2)
                            .foregroundColor(AppColors.statusWarning)
                    }
                }
                if !blockers.isEmpty {
                    ForEach(blockers, id: \.self) { blocker in
                        Text("• \(blocker)")
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.statusError)
                    }
                } else {
                    Text("No open critical bugs or release gate blockers detected.")
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Release Readiness")
        }
    }

    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Status: \(currentRelease.status.rawValue.capitalized)")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.brandPrimary)
                    Spacer()
                    if let date = currentRelease.releaseDate {
                        Text("Planned: \(date.formatted(date: .abbreviated, time: .omitted))")
                            .appFont(AppTypography.caption1)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                if currentRelease.status == .released, let releasedAt = currentRelease.releasedAt {
                    Text("Released: \(releasedAt.formatted(date: .abbreviated, time: .shortened))")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(AppColors.statusSuccess)
                }
                if let desc = currentRelease.description, !desc.isEmpty {
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

    private var releaseActionsSection: some View {
        Section {
            if currentRelease.status == .unreleased {
                Button {
                    showShipConfirmation = true
                } label: {
                    Label("Ship / Finalize Version", systemImage: "paperplane.fill")
                        .foregroundColor(AppColors.statusSuccess)
                }
            }

            Button {
                Task { await toggleLock() }
            } label: {
                Label(
                    currentRelease.isLocked ? "Unlock Release Scope" : "Lock Release Scope",
                    systemImage: currentRelease.isLocked ? "lock.open" : "lock.fill"
                )
                .foregroundColor(AppColors.brandPrimary)
            }
        } header: {
            Text("Version Controls")
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
            if let changelog {
                HStack(spacing: 12) {
                    Label("\(changelog.epics.count) Epics", systemImage: "flag.fill")
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.brandPrimary)
                    Label("\(changelog.stories.count) Stories", systemImage: "sparkles")
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.statusSuccess)
                    Label("\(changelog.bugs.count) Bugs", systemImage: "ladybug.fill")
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.statusError)
                    Label("\(changelog.tasks.count) Tasks", systemImage: "checkmark.circle")
                        .appFont(AppTypography.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.vertical, 2)
            }

            Button {
                releaseNotesMarkdown = changelog?.markdown ?? buildReleaseNotesMarkdown(release: currentRelease, progress: progress, issues: issues)
                showNotesPreview = true
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Generate Categorized Release Notes")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColors.textTertiary)
                }
                .appFont(AppTypography.subheadline)
                .foregroundColor(AppColors.brandPrimary)
            }

            if issues.isEmpty {
                Text("Link issues to this release (Affected Version) to populate issue categories.")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
        } header: {
            Text("Release Notes & Changelog")
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
            async let c: ReleaseChangelogDTO? = try fetchChangelog()
            let (progress, issues, changelog) = try await (p, i, c)
            self.progress = progress
            self.issues = issues
            self.changelog = changelog
        } catch {
            self.error = error
        }
    }

    private func finalizeRelease(lock: Bool) async {
        do {
            let endpoint = ReleaseEndpoint.finalize(releaseId: currentRelease.id, lock: lock, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<ReleaseDTO>.self)
            if let updated = response.data {
                currentRelease = updated
            }
            toast = ToastMessage(type: .success, title: "Shipped", message: "Shipped \(currentRelease.name)")
            onChanged?()
            await refresh()
        } catch {
            toast = ToastMessage(type: .error, title: "Error", message: error.localizedDescription)
        }
    }

    private func toggleLock() async {
        do {
            let payload = UpdateReleaseRequest(isLocked: !currentRelease.isLocked)
            let endpoint = ReleaseEndpoint.update(releaseId: currentRelease.id, payload: payload, configuration: apiConfiguration)
            let response = try await apiClient.request(endpoint, responseType: APIResponse<ReleaseDTO>.self)
            if let updated = response.data {
                currentRelease = updated
            }
            toast = ToastMessage(
                type: .success,
                title: currentRelease.isLocked ? "Locked" : "Unlocked",
                message: currentRelease.isLocked ? "Release scope locked" : "Release scope unlocked"
            )
            onChanged?()
            await refresh()
        } catch {
            toast = ToastMessage(type: .error, title: "Error", message: error.localizedDescription)
        }
    }

    private func fetchProgress() async throws -> ReleaseProgressDTO? {
        let endpoint = ReleaseEndpoint.progress(releaseId: currentRelease.id, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<ReleaseProgressDTO>.self)
        return response.data
    }

    private func fetchIssues() async throws -> [TaskItemDTO] {
        let endpoint = ReleaseEndpoint.issues(releaseId: currentRelease.id, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<[TaskItemDTO]>.self)
        return response.data ?? []
    }

    private func fetchChangelog() async throws -> ReleaseChangelogDTO? {
        let endpoint = ReleaseEndpoint.changelog(releaseId: currentRelease.id, configuration: apiConfiguration)
        let response = try await apiClient.request(endpoint, responseType: APIResponse<ReleaseChangelogDTO>.self)
        return response.data
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
