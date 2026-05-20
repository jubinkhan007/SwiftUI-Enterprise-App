import SwiftUI
import SharedModels
import DesignSystem

/// In-meeting screen. The "media area" is a labeled placeholder — sub-phase 4-B
/// replaces it with the Agora/LiveKit video stage. The chat sidebar reuses the
/// auto-created per-meeting conversation via `meetingChatConversationId`.
public struct InMeetingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var session: MeetingSessionStore

    @State private var micOn = true
    @State private var camOn = false
    @State private var showHostControls = false
    @State private var showChatSheet = false

    public var body: some View {
        VStack(spacing: 0) {
            mediaArea
            controlBar
        }
        .background(Color.black)
        .navigationTitle(session.meeting?.title ?? "Meeting")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if isHostOrCoHost {
                        Button("Host controls") { showHostControls = true }
                    }
                    if session.ticket?.chatConversationId != nil {
                        Button("Open chat") { showChatSheet = true }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showHostControls) {
            if let meeting = session.meeting {
                NavigationStack {
                    HostControlsPanel(session: session, meeting: meeting)
                }
            }
        }
        .sheet(isPresented: $showChatSheet) {
            NavigationStack {
                Text("In-meeting chat — uses ChatView wired to chatConversationId in 4-A polish.")
                    .padding()
                    .navigationTitle("Chat")
            }
        }
        .task { await session.refresh() }
    }

    private var mediaArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.black)
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "video.fill")
                    .appFont(AppTypography.largeTitle)
                    .foregroundColor(.white.opacity(0.4))
                Text("MEDIA AREA")
                    .appFont(AppTypography.overline)
                    .foregroundColor(.white.opacity(0.5))
                Text("Live audio/video wires in during sub-phase 4-B")
                    .appFont(AppTypography.caption1)
                    .foregroundColor(.white.opacity(0.6))
                if let meeting = session.meeting {
                    let inMeeting = meeting.participants.filter { $0.joinState == .inMeeting }
                    Text("\(inMeeting.count) in the room")
                        .appFont(AppTypography.caption1)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, AppSpacing.md)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controlBar: some View {
        HStack(spacing: AppSpacing.xl) {
            circleControl(icon: micOn ? "mic.fill" : "mic.slash.fill", bg: micOn ? Color.gray.opacity(0.6) : Color.red) {
                micOn.toggle()
            }
            circleControl(icon: camOn ? "video.fill" : "video.slash.fill", bg: camOn ? Color.gray.opacity(0.6) : Color.red) {
                camOn.toggle()
            }
            if session.ticket?.chatConversationId != nil {
                circleControl(icon: "bubble.right.fill", bg: Color.gray.opacity(0.6)) {
                    showChatSheet = true
                }
            }
            Button {
                Task { await session.leave(); dismiss() }
            } label: {
                Image(systemName: "phone.down.fill")
                    .appFont(AppTypography.title3)
                    .frame(width: 56, height: 56)
                    .foregroundColor(.white)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }

    private func circleControl(icon: String, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .appFont(AppTypography.title3)
                .frame(width: 56, height: 56)
                .foregroundColor(.white)
                .background(bg)
                .clipShape(Circle())
        }
    }

    private var isHostOrCoHost: Bool {
        guard let mine = session.meeting?.myParticipant else { return false }
        return mine.role == .host || mine.role == .coHost
    }
}
