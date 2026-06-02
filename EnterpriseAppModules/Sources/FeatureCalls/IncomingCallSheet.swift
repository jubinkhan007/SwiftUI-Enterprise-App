import SwiftUI
import DesignSystem
import SharedModels

/// Modal presented when a `call.incoming` notification arrives or a realtime
/// `call.initiated` event fires for a call the current user is a participant of.
public struct IncomingCallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var store: CallSessionStore
    let callerDisplayName: String
    let onAccepted: () -> Void

    public init(store: CallSessionStore, callerDisplayName: String, onAccepted: @escaping () -> Void) {
        self._store = StateObject(wrappedValue: store)
        self.callerDisplayName = callerDisplayName
        self.onAccepted = onAccepted
    }

    public var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            avatar
            VStack(spacing: 6) {
                Text(callerDisplayName)
                    .appFont(AppTypography.title2)
                    .foregroundColor(.white)
                Text("Incoming call…")
                    .appFont(AppTypography.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            controls
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color.indigo, Color.black], startPoint: .top, endPoint: .bottom))
        .task { await store.refresh() }
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.15)).frame(width: 120, height: 120)
            Text(initials)
                .appFont(AppTypography.title1)
                .foregroundColor(.white)
        }
    }

    private var initials: String {
        let parts = callerDisplayName.split(separator: " ")
        let head = parts.first?.first.map(String.init) ?? "?"
        let tail = parts.dropFirst().first?.first.map(String.init) ?? ""
        return "\(head)\(tail)".uppercased()
    }

    private var controls: some View {
        HStack(spacing: AppSpacing.xxl) {
            Button {
                Task {
                    await store.declineIncoming()
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
            Button {
                Task {
                    await store.acceptIncoming()
                    onAccepted()
                    dismiss()
                }
            } label: {
                Image(systemName: "phone.fill")
                    .appFont(AppTypography.title3)
                    .frame(width: 72, height: 72)
                    .foregroundColor(.white)
                    .background(Color.green)
                    .clipShape(Circle())
            }
        }
    }
}
