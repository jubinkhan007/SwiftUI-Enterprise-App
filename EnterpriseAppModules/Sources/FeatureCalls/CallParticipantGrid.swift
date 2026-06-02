import SwiftUI
import DesignSystem
import SharedModels

/// Adaptive grid of in-call participants. Tiles fall back to a colored avatar
/// when video is off (the real LiveKit SDK would render the video track here).
public struct CallParticipantGrid: View {
    public let participants: [RemoteCallParticipant]
    public let activeSpeakerUserId: UUID?

    public init(participants: [RemoteCallParticipant], activeSpeakerUserId: UUID?) {
        self.participants = participants
        self.activeSpeakerUserId = activeSpeakerUserId
    }

    public var body: some View {
        GeometryReader { geo in
            let columns = participants.count <= 1 ? 1 : (participants.count <= 4 ? 2 : 3)
            let layout = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: columns)
            ScrollView {
                LazyVGrid(columns: layout, spacing: AppSpacing.xs) {
                    ForEach(participants) { p in
                        ParticipantTile(participant: p, isActiveSpeaker: p.id == activeSpeakerUserId)
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    }
                }
                .padding(AppSpacing.xs)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct ParticipantTile: View {
    let participant: RemoteCallParticipant
    let isActiveSpeaker: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            tileBackground
            badges
                .padding(AppSpacing.xs)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActiveSpeaker ? Color.green : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var tileBackground: some View {
        if participant.isVideoMuted {
            ZStack {
                LinearGradient(colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.5)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(initials)
                    .appFont(AppTypography.title3)
                    .foregroundColor(.white)
            }
        } else {
            // Real LiveKit / Agora SDKs render a SwiftUI-wrapped UIView for the
            // remote track here. Placeholder shows a dim camera frame.
            ZStack {
                Color.black
                Image(systemName: "video.fill")
                    .appFont(AppTypography.title3)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var badges: some View {
        HStack(spacing: 4) {
            Text(participant.displayName)
                .appFont(AppTypography.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.black.opacity(0.55))
                .cornerRadius(4)
            if participant.isAudioMuted {
                Image(systemName: "mic.slash.fill")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(4)
            }
            if participant.isScreenSharing {
                Image(systemName: "rectangle.on.rectangle")
                    .appFont(AppTypography.caption2)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black.opacity(0.55))
                    .cornerRadius(4)
            }
            Spacer()
        }
    }

    private var initials: String {
        let parts = participant.displayName.split(separator: " ")
        let head = parts.first?.first.map(String.init) ?? "?"
        let tail = parts.dropFirst().first?.first.map(String.init) ?? ""
        return "\(head)\(tail)".uppercased()
    }
}
