import CoreMedia
import Foundation

/// Minimal IPC pipe between the Broadcast Upload Extension and the host app.
///
/// Strategy: store the latest video frame (as a `CVPixelBuffer` serialized to a
/// shared file) and a small state plist in the App Group container. The host
/// app polls the file at ~30Hz; this is intentionally simple — production
/// systems typically use `IOSurface` or a Mach port for zero-copy delivery.
///
/// Why no `IOSurface`: keeps the scaffold readable; once LiveKit is wired,
/// swap this class out for `LKBroadcastBuffer` (from `livekit-broadcast-extension`).
public final class SharedFramePipe {
    public let appGroup: String
    private let containerURL: URL?
    private let stateURL: URL?
    private let frameURL: URL?

    public init(appGroup: String) {
        self.appGroup = appGroup
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        self.containerURL = container
        self.stateURL = container?.appendingPathComponent("broadcast.state.plist")
        self.frameURL = container?.appendingPathComponent("broadcast.frame.bin")
    }

    public func markStarted(_ started: Bool = true) {
        writeState(["isStarted": started, "isPaused": false, "updatedAt": Date()])
    }

    public func markPaused(_ paused: Bool) {
        var current = readState()
        current["isPaused"] = paused
        current["updatedAt"] = Date()
        writeState(current)
    }

    public func push(videoSampleBuffer sampleBuffer: CMSampleBuffer) {
        // For the scaffold we only record state + a frame counter — replace
        // with `CVPixelBuffer` → ARGB plane copy when integrating LiveKit's
        // custom video source. Writing every frame to disk is wasteful and
        // intentionally left as a future swap.
        var state = readState()
        let count = (state["frameCount"] as? Int) ?? 0
        state["frameCount"] = count + 1
        state["updatedAt"] = Date()
        writeState(state)
    }

    public func push(audioSampleBuffer sampleBuffer: CMSampleBuffer, isApp: Bool) {
        // No-op in the scaffold.
    }

    // MARK: - State helpers

    private func readState() -> [String: Any] {
        guard let url = stateURL,
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return [:] }
        return plist
    }

    private func writeState(_ state: [String: Any]) {
        guard let url = stateURL else { return }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: state, format: .binary, options: 0) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
