import SwiftUI
#if canImport(ReplayKit)
import ReplayKit
#endif

/// Wraps `RPSystemBroadcastPickerView` so the host can start a system-wide
/// screen share from inside the call UI. The picker presents iOS's broadcast
/// destinations sheet; the actual frames are captured by the Broadcast Upload
/// Extension (see `BROADCAST_EXTENSION_SETUP.md`).
///
/// `preferredExtension` should be the bundle id of the broadcast extension,
/// supplied via the `BROADCAST_EXTENSION_BUNDLE_ID` Info.plist key (set in
/// the host target's INFOPLIST_KEY_* build settings).
public struct ScreenShareSystemPicker: View {
    public init() {}

    public var body: some View {
        #if os(iOS) && canImport(ReplayKit)
        VStack(spacing: 16) {
            Text("Start screen sharing")
                .font(.headline)
            Text("Tap the broadcast button below, then choose your destination.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            BroadcastPickerRepresentable()
                .frame(width: 80, height: 80)
            Spacer(minLength: 0)
        }
        .padding()
        #else
        Text("Screen share is only available on iOS.")
            .padding()
        #endif
    }
}

#if os(iOS) && canImport(ReplayKit)
import UIKit

private struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let view = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        if let bundleId = Bundle.main.object(forInfoDictionaryKey: "BROADCAST_EXTENSION_BUNDLE_ID") as? String,
           !bundleId.isEmpty {
            view.preferredExtension = bundleId
        }
        view.showsMicrophoneButton = true
        return view
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
#endif
