import SwiftUI
import DesignSystem
import SharedModels

/// Shown while we wait for the callee to accept. Transitions to InCallView
/// once the realtime `call.active` event flips the store's session status.
public struct OutgoingCallView: View {
    @ObservedObject var store: CallSessionStore
    let calleeDisplayName: String
    @Environment(\.dismiss) private var dismiss

    public init(store: CallSessionStore, calleeDisplayName: String) {
        self.store = store
        self.calleeDisplayName = calleeDisplayName
    }

    public var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(Color.white.opacity(0.15)).frame(width: 140, height: 140)
                Text(initials)
                    .appFont(AppTypography.title1)
                    .foregroundColor(.white)
            }
            Text(calleeDisplayName)
                .appFont(AppTypography.title2)
                .foregroundColor(.white)
            Text(statusLine)
                .appFont(AppTypography.subheadline)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Button {
                Task {
                    await store.endCall()
                    dismiss()
                }
            } label: {
                Image(systemName: "phone.down.fill")
                    .appFont(AppTypography.title3)
                    .frame(width: 72, height: 72)
                    .foregroundColor(.white)
                    .background(Color.red)
                    .clipShape(Circle())
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color.indigo, Color.black], startPoint: .top, endPoint: .bottom))
    }

    private var statusLine: String {
        switch store.session?.status {
        case .initiated: return "Ringing…"
        case .active: return "Connected"
        case .ended: return "Call ended"
        case .cancelled: return "Cancelled"
        case nil: return "Connecting…"
        }
    }

    private var initials: String {
        let parts = calleeDisplayName.split(separator: " ")
        let head = parts.first?.first.map(String.init) ?? "?"
        let tail = parts.dropFirst().first?.first.map(String.init) ?? ""
        return "\(head)\(tail)".uppercased()
    }
}
