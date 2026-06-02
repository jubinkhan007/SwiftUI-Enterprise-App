import SwiftUI
import DesignSystem
import SharedModels

/// Host-only sheet: lock/unlock room, mute/eject remote participants,
/// promote/demote presenters.
public struct CallHostControlsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: CallSessionStore
    let session: CallSessionDTO

    public init(store: CallSessionStore, session: CallSessionDTO) {
        self.store = store
        self.session = session
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Room") {
                    Toggle("Lock room (block new joiners)", isOn: Binding(
                        get: { session.isLocked },
                        set: { newValue in
                            Task {
                                await store.adminAction(newValue ? .lockRoom : .unlockRoom)
                            }
                        }
                    ))
                }

                Section("Participants") {
                    ForEach(session.participants) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(p.displayName).appFont(AppTypography.body)
                                if p.role == .host { Text("HOST").appFont(AppTypography.overline).foregroundColor(.purple) }
                                else if p.role == .presenter { Text("PRESENTER").appFont(AppTypography.overline).foregroundColor(.blue) }
                                Spacer()
                                if p.isAudioMuted {
                                    Image(systemName: "mic.slash.fill").foregroundColor(.red)
                                }
                                if p.isScreenSharing {
                                    Image(systemName: "rectangle.on.rectangle.fill").foregroundColor(AppColors.brandPrimary)
                                }
                            }
                            if p.role != .host {
                                HStack {
                                    Button("Mute mic") {
                                        Task { await store.adminAction(.muteRemoteAudio, targetParticipantId: p.id) }
                                    }
                                    .appFont(AppTypography.caption1)
                                    Button("Mute cam") {
                                        Task { await store.adminAction(.muteRemoteVideo, targetParticipantId: p.id) }
                                    }
                                    .appFont(AppTypography.caption1)
                                    if p.isScreenSharing {
                                        Button("Stop share") {
                                            Task { await store.adminAction(.stopScreenShare, targetParticipantId: p.id) }
                                        }
                                        .appFont(AppTypography.caption1)
                                    }
                                    Spacer()
                                    if p.role == .presenter {
                                        Button("Demote") {
                                            Task { await store.adminAction(.demoteFromPresenter, targetParticipantId: p.id) }
                                        }
                                        .appFont(AppTypography.caption1)
                                    } else {
                                        Button("Promote") {
                                            Task { await store.adminAction(.promoteToPresenter, targetParticipantId: p.id) }
                                        }
                                        .appFont(AppTypography.caption1)
                                    }
                                    Button("Eject", role: .destructive) {
                                        Task { await store.adminAction(.eject, targetParticipantId: p.id) }
                                    }
                                    .appFont(AppTypography.caption1)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Host controls")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
