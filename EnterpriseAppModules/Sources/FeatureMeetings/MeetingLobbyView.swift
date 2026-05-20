import SwiftUI
import SharedModels
import DesignSystem

/// Pre-join lobby. Placeholder media controls (camera/mic toggles do nothing yet —
/// real AV plugs in during sub-phase 4-B). Transitions to either WaitingRoomView
/// or InMeetingView once `joinMeeting` returns.
public struct MeetingLobbyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: MeetingSessionStore
    let meeting: MeetingDTO

    @State private var micOn = true
    @State private var camOn = false
    @State private var isJoining = false
    @State private var showWaiting = false
    @State private var showInMeeting = false

    public var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                Spacer()
                videoPreview
                Text(meeting.title)
                    .appFont(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("You're about to join the meeting.")
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                deviceControls
                joinButton
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .background(AppColors.backgroundPrimary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showWaiting) {
                WaitingRoomView(session: session)
            }
            .navigationDestination(isPresented: $showInMeeting) {
                InMeetingView(session: session)
            }
        }
    }

    private var videoPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
            if !camOn {
                VStack(spacing: 6) {
                    Image(systemName: "video.slash")
                        .appFont(AppTypography.title1)
                        .foregroundColor(.white.opacity(0.7))
                    Text("Camera off")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(.white.opacity(0.7))
                }
            } else {
                Text("CAMERA PREVIEW · wired in sub-phase 4-B")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    private var deviceControls: some View {
        HStack(spacing: AppSpacing.xl) {
            Button {
                micOn.toggle()
            } label: {
                Image(systemName: micOn ? "mic.fill" : "mic.slash.fill")
                    .appFont(AppTypography.title3)
                    .frame(width: 56, height: 56)
                    .foregroundColor(.white)
                    .background(micOn ? AppColors.brandPrimary : Color.gray)
                    .clipShape(Circle())
            }
            Button {
                camOn.toggle()
            } label: {
                Image(systemName: camOn ? "video.fill" : "video.slash.fill")
                    .appFont(AppTypography.title3)
                    .frame(width: 56, height: 56)
                    .foregroundColor(.white)
                    .background(camOn ? AppColors.brandPrimary : Color.gray)
                    .clipShape(Circle())
            }
        }
    }

    private var joinButton: some View {
        Button {
            Task {
                isJoining = true
                await session.join()
                isJoining = false
                if let ticket = session.ticket {
                    if ticket.joinState == .waiting {
                        showWaiting = true
                    } else if ticket.joinState == .inMeeting {
                        showInMeeting = true
                    }
                }
            }
        } label: {
            HStack {
                if isJoining { ProgressView().tint(.white) }
                Text(isJoining ? "Joining…" : "Join meeting")
                    .appFont(AppTypography.buttonLabel)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.brandPrimary)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isJoining)
    }
}
