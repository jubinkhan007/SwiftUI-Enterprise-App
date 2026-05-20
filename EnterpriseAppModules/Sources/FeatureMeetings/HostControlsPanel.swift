import SwiftUI
import SharedModels
import DesignSystem

/// In-meeting host panel: waiting queue (admit/deny), kick, change roles.
public struct HostControlsPanel: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: MeetingSessionStore
    let meeting: MeetingDTO

    public var body: some View {
        List {
            let waiting = meeting.participants.filter { $0.joinState == .waiting }
            if !waiting.isEmpty {
                Section("Waiting room (\(waiting.count))") {
                    ForEach(waiting) { p in
                        HStack {
                            Text(p.displayName)
                            Spacer()
                            Button("Admit") { Task { await session.admit(participantId: p.id) } }
                                .appFont(AppTypography.caption1)
                            Button("Deny") { Task { await session.deny(participantId: p.id) } }
                                .appFont(AppTypography.caption1)
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            Section("All participants") {
                ForEach(meeting.participants) { p in
                    NavigationLink {
                        ParticipantRoleSheet(session: session, participant: p)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(p.displayName)
                                Text(roleLabel(p.role))
                                    .appFont(AppTypography.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            joinStateBadge(p.joinState)
                        }
                    }
                }
            }
        }
        .navigationTitle("Host Controls")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }

    private func roleLabel(_ r: MeetingRole) -> String {
        switch r {
        case .host: return "Host"
        case .coHost: return "Co-host"
        case .presenter: return "Presenter"
        case .attendee: return "Attendee"
        }
    }

    @ViewBuilder
    private func joinStateBadge(_ s: MeetingJoinState) -> some View {
        switch s {
        case .inMeeting: Text("in room").appFont(AppTypography.caption2).foregroundColor(.green)
        case .waiting: Text("waiting").appFont(AppTypography.caption2).foregroundColor(.orange)
        case .left: Text("left").appFont(AppTypography.caption2).foregroundColor(AppColors.textSecondary)
        case .denied: Text("denied").appFont(AppTypography.caption2).foregroundColor(.red)
        case .removed: Text("removed").appFont(AppTypography.caption2).foregroundColor(.red)
        case .notJoined: EmptyView()
        }
    }
}

private struct ParticipantRoleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: MeetingSessionStore
    let participant: MeetingParticipantDTO

    var body: some View {
        Form {
            Section("Role") {
                ForEach([MeetingRole.coHost, .presenter, .attendee, .host], id: \.self) { role in
                    Button {
                        Task {
                            await session.changeRole(participantId: participant.id, to: role)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Text(roleLabel(role)).foregroundColor(AppColors.textPrimary)
                            Spacer()
                            if participant.role == role {
                                Image(systemName: "checkmark").foregroundColor(AppColors.brandPrimary)
                            }
                        }
                    }
                }
            }
            Section {
                Button(role: .destructive) {
                    Task {
                        await session.removeParticipant(participant.id)
                        dismiss()
                    }
                } label: {
                    Text("Remove from meeting")
                }
            }
        }
        .navigationTitle(participant.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func roleLabel(_ r: MeetingRole) -> String {
        switch r {
        case .host: return "Promote to host"
        case .coHost: return "Co-host"
        case .presenter: return "Presenter"
        case .attendee: return "Attendee"
        }
    }
}
