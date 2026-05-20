import SwiftUI
import SharedModels
import DesignSystem

/// Shown after the user calls /join on a meeting with `requiresWaitingRoom=true`.
/// Auto-transitions to InMeetingView when the host emits `meeting.participant_admitted`
/// (handled by MeetingSessionStore observing realtime events → refetches → joinState flips).
public struct WaitingRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: MeetingSessionStore

    @State private var navigateInside = false

    public var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ProgressView().scaleEffect(1.4)
            Text("Waiting for host…")
                .appFont(AppTypography.title3)
                .foregroundColor(AppColors.textPrimary)
            Text("The host will let you in shortly.")
                .appFont(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Button(role: .destructive) {
                Task {
                    await session.leave()
                    dismiss()
                }
            } label: {
                Text("Leave waiting room")
                    .appFont(AppTypography.buttonLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(AppColors.backgroundPrimary)
        .navigationTitle("Lobby")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationDestination(isPresented: $navigateInside) {
            InMeetingView(session: session)
        }
        .onChange(of: session.meeting?.myParticipant?.joinState) { _, newState in
            if newState == .inMeeting { navigateInside = true }
            if newState == .denied { dismiss() }
        }
    }
}
