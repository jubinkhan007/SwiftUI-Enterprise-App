import Foundation
import ReplayKit

/// System-wide screen capture entry point. The extension runs in a separate
/// process from the host app — communication uses the App Group container
/// (`group.com.enterprise.EnterpriseApp.screenshare` by default; override via
/// `BROADCAST_APP_GROUP` Info.plist key).
///
/// Frame pipeline:
///   1. iOS delivers `processSampleBuffer(_:with:)` ~30/s with raw video frames.
///   2. We push each frame into `SharedFrameRingBuffer` (App Group memory).
///   3. The host app's `LiveKitCallProvider` (or other SFU client) reads
///      frames from the ring buffer and publishes them as a `screen_share` track.
///
/// Lifecycle:
///   * `broadcastStarted(withSetupInfo:)` — set up the ring buffer.
///   * `broadcastPaused()` / `broadcastResumed()` — host app can suspend the
///     track without ending the broadcast.
///   * `broadcastFinished()` — flush + clear the App Group sentinel.
final class SampleHandler: RPBroadcastSampleHandler {
    private var pipe: SharedFramePipe?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        let appGroup = (Bundle.main.object(forInfoDictionaryKey: "BROADCAST_APP_GROUP") as? String)
            ?? "group.com.enterprise.EnterpriseApp.screenshare"
        pipe = SharedFramePipe(appGroup: appGroup)
        pipe?.markStarted()
    }

    override func broadcastPaused() {
        pipe?.markPaused(true)
    }

    override func broadcastResumed() {
        pipe?.markPaused(false)
    }

    override func broadcastFinished() {
        pipe?.markStarted(false)
        pipe = nil
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard let pipe else { return }
        switch sampleBufferType {
        case .video:
            pipe.push(videoSampleBuffer: sampleBuffer)
        case .audioApp:
            pipe.push(audioSampleBuffer: sampleBuffer, isApp: true)
        case .audioMic:
            pipe.push(audioSampleBuffer: sampleBuffer, isApp: false)
        @unknown default:
            break
        }
    }
}
