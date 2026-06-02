import Foundation
#if canImport(AVKit) && canImport(UIKit)
import AVKit
import UIKit
#endif

/// Picture-in-Picture controller for the active call. When the app moves to
/// background, the active speaker's video track is bound to an
/// `AVPictureInPictureController` so the call stays visible in a floating
/// window.
///
/// Setup required (caller side, see CallKit-and-PiP-setup.md):
///   1. Enable "Background Modes" capability and check "Audio, AirPlay, and
///      Picture in Picture" + "Voice over IP".
///   2. Configure AVAudioSession to .playAndRecord, mode .voiceChat, before
///      starting PiP.
///   3. Call `prepare(layer:)` with the live video preview layer once the SFU
///      delivers a frame; PiP requires a non-empty AVSampleBufferDisplayLayer
///      or AVPlayerLayer.
@MainActor
public final class PiPController: NSObject {
    public static let shared = PiPController()

    public private(set) var isAvailable: Bool = false
    public private(set) var isActive: Bool = false

    #if canImport(AVKit) && canImport(UIKit)
    private var controller: AVPictureInPictureController?

    public func prepare(layer: AVPictureInPictureController.ContentSource) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            isAvailable = false
            return
        }
        let c = AVPictureInPictureController(contentSource: layer)
        c.delegate = self
        controller = c
        isAvailable = true
    }

    public func start() {
        controller?.startPictureInPicture()
    }

    public func stop() {
        controller?.stopPictureInPicture()
    }
    #else
    public func start() {}
    public func stop() {}
    #endif
}

#if canImport(AVKit) && canImport(UIKit)
extension PiPController: AVPictureInPictureControllerDelegate {
    nonisolated public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in self?.isActive = true }
    }

    nonisolated public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        Task { @MainActor [weak self] in self?.isActive = false }
    }
}
#endif
