import SwiftUI
import DesignSystem
import SharedModels

/// Full-screen in-call experience. Composes participant grid (or screen-share
/// presenter when active) + controls bar + host menu sheet.
public struct InCallView: View {
    @StateObject var store: CallSessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var showHostControls = false
    @State private var showSystemBroadcastPicker = false

    public let currentUserId: UUID

    public init(store: CallSessionStore, currentUserId: UUID) {
        self._store = StateObject(wrappedValue: store)
        self.currentUserId = currentUserId
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            CallControlsBar(
                store: store,
                isHost: isHost,
                onShowHostControls: { showHostControls = true },
                onHangUp: {
                    Task {
                        if isHost {
                            await store.endCall()
                        } else {
                            await store.leaveCall()
                        }
                        dismiss()
                    }
                }
            )
        }
        .background(Color.black)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .sheet(isPresented: $showHostControls) {
            if let session = store.session {
                CallHostControlsSheet(store: store, session: session)
            }
        }
        .sheet(isPresented: $showSystemBroadcastPicker) {
            ScreenShareSystemPicker()
                .presentationDetents([.medium])
        }
    }

    // MARK: - Layout

    private var header: some View {
        HStack(spacing: AppSpacing.sm) {
            connectionPill
            Spacer()
            Text(headerTitle)
                .appFont(AppTypography.subheadline)
                .foregroundColor(.white)
            Spacer()
            Button {
                showSystemBroadcastPicker = true
            } label: {
                Image(systemName: "rectangle.dashed.badge.record")
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.black)
    }

    private var connectionPill: some View {
        let (label, color): (String, Color) = {
            switch store.managerState.connectionState {
            case .idle: return ("Idle", .gray)
            case .connecting: return ("Connecting…", .orange)
            case .connected: return ("Connected", .green)
            case .reconnecting: return ("Reconnecting…", .orange)
            case .disconnected: return ("Disconnected", .red)
            case .failed: return ("Failed", .red)
            }
        }()
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .appFont(AppTypography.caption2)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    private var headerTitle: String {
        store.session.flatMap { session in
            "\(session.participants.count) on the call"
        } ?? "Call"
    }

    @ViewBuilder
    private var content: some View {
        if let presenter = screenSharePresenter {
            ScreenSharePresenterView(presenter: presenter)
        } else if store.managerState.remoteParticipants.isEmpty {
            stubPlaceholder
        } else {
            CallParticipantGrid(
                participants: store.managerState.remoteParticipants,
                activeSpeakerUserId: store.managerState.activeSpeakerUserId
            )
        }
    }

    private var stubPlaceholder: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "video.fill")
                .appFont(AppTypography.largeTitle)
                .foregroundColor(.white.opacity(0.4))
            Text("MEDIA AREA")
                .appFont(AppTypography.overline)
                .foregroundColor(.white.opacity(0.5))
            Text("Waiting for participants — real audio/video lands when the LiveKit SDK is linked.")
                .appFont(AppTypography.caption1)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
        }
    }

    private var screenSharePresenter: RemoteCallParticipant? {
        store.managerState.remoteParticipants.first { $0.isScreenSharing }
    }

    private var isHost: Bool {
        store.session?.hostId == currentUserId
    }
}
