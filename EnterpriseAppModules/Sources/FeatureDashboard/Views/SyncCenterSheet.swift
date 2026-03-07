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
                Section("Status") {
                    HStack {
                        Text(statusText)
                        Spacer()
                        if let last = syncManager.lastSyncedAt {
                            Text(Self.relativeTime(from: last))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Never")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !syncManager.pendingOperations.isEmpty {
                        Text("Pending: \(syncManager.pendingOperations.count)")
                            .foregroundStyle(.secondary)
                    }
                    if !syncManager.attentionOperations.isEmpty {
                        Text("Needs attention: \(syncManager.attentionOperations.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                if !syncManager.attentionOperations.isEmpty {
                    Section("Needs Attention") {
                        ForEach(syncManager.attentionOperations, id: \.id) { op in
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("\(op.operationRawValue) \(op.entityTypeRawValue)")
                                    .appFont(AppTypography.bodySemibold)
                                if let err = op.lastError, !err.isEmpty {
                                    Text(err)
                                        .foregroundStyle(.secondary)
                                        .appFont(AppTypography.caption)
                                }

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
                            .padding(.vertical, AppSpacing.xs)
                        }
                    }
                }

                if !syncManager.pendingOperations.isEmpty {
                    Section("Pending") {
                        ForEach(syncManager.pendingOperations, id: \.id) { op in
                            HStack {
                                Text("\(op.operationRawValue) \(op.entityTypeRawValue)")
                                Spacer()
                                Text(op.entityId.uuidString.prefix(8))
                                    .foregroundStyle(.secondary)
                                    .monospaced()
                            }
                        }
                    }
                }
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
