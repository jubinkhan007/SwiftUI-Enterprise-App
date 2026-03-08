import SwiftUI
import AppData
import DesignSystem

public struct SyncCenterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var syncManager: SyncEngineManager

    public init(syncManager: SyncEngineManager) {
        self.syncManager = syncManager
    }

    public var body: some View {
        NavigationStack {
            List {
                statusSection
                attentionSection
                pendingSection
            }
            .navigationTitle("Sync Center")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sync Now") { syncManager.syncNow() }
                        .disabled(syncManager.pendingOperations.isEmpty)
                }
            }
            .task {
                await syncManager.refresh()
            }
        }
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        Section("Status") {
            HStack {
                Text(statusText)
                Spacer()
                lastSyncedLabel
            }
            pendingCountLabel
            attentionCountLabel
        }
    }

    @ViewBuilder
    private var lastSyncedLabel: some View {
        if let last = syncManager.lastSyncedAt {
            Text(Self.relativeTime(from: last))
                .foregroundStyle(.secondary)
        } else {
            Text("Never")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var pendingCountLabel: some View {
        if !syncManager.pendingOperations.isEmpty {
            Text("Pending: \(syncManager.pendingOperations.count)")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var attentionCountLabel: some View {
        if !syncManager.attentionOperations.isEmpty {
            Text("Needs attention: \(syncManager.attentionOperations.count)")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Attention Section

    @ViewBuilder
    private var attentionSection: some View {
        if !syncManager.attentionOperations.isEmpty {
            Section("Needs Attention") {
                ForEach(syncManager.attentionOperations, id: \.id) { op in
                    AttentionOperationRow(op: op, syncManager: syncManager)
                }
            }
        }
    }

    // MARK: - Pending Section

    @ViewBuilder
    private var pendingSection: some View {
        if !syncManager.pendingOperations.isEmpty {
            Section("Pending") {
                ForEach(syncManager.pendingOperations, id: \.id) { op in
                    PendingOperationRow(op: op)
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusText: String {
        switch syncManager.state {
        case .online: return "Online"
        case .offline: return "Offline"
        case .syncing(let count): return "Syncing (\(count))"
        case .attentionNeeded: return "Attention Needed"
        }
    }

    private static func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Extracted Row Views

private struct AttentionOperationRow: View {
    let op: LocalSyncOperation
    let syncManager: SyncEngineManager

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("\(op.operationRawValue) \(op.entityTypeRawValue)")
                .appFont(AppTypography.body.weight(.semibold))
            errorLabel
            actionButtons
        }
        .padding(.vertical, AppSpacing.xs)
    }

    @ViewBuilder
    private var errorLabel: some View {
        if let err = op.lastError, !err.isEmpty {
            Text(err)
                .foregroundStyle(.secondary)
                .appFont(AppTypography.caption1)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            if op.remoteSnapshotJSON != nil {
                Button("Use Theirs") {
                    Task { await syncManager.resolveConflictUseTheirs(op) }
                }
                Button("Keep Mine") {
                    Task { await syncManager.resolveConflictKeepMine(op) }
                }
            } else {
                Button("Retry") {
                    Task { await syncManager.retry(op) }
                }
                Button("Discard", role: .destructive) {
                    Task { await syncManager.discard(op) }
                }
            }
        }
    }
}

private struct PendingOperationRow: View {
    let op: LocalSyncOperation

    var body: some View {
        HStack {
            Text("\(op.operationRawValue) \(op.entityTypeRawValue)")
            Spacer()
            Text(String(op.entityId.uuidString.prefix(8)))
                .foregroundStyle(.secondary)
                .monospaced()
        }
    }
}
