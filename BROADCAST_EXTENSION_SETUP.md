# Broadcast Upload Extension — Xcode Setup

The `BroadcastExtension/` directory contains the source for a system-wide screen-share extension (ReplayKit's `RPBroadcastSampleHandler`). Because adding a new Xcode target via direct `project.pbxproj` edits is fragile (it pulls in entitlements, signing, embed phases, App Groups…), this is the **only** part of Phase 4-B that needs manual Xcode UI steps.

## One-time Xcode setup

1. **Add the target**: In Xcode, `File → New → Target… → Broadcast Upload Extension`.
   - Product Name: `EnterpriseAppScreenShare`
   - Bundle ID: `com.enterprise.EnterpriseApp.ScreenShare`
   - Language: Swift
   - Embed in Application: `EnterpriseApp`
   - Click **Finish**, decline the "activate scheme" prompt.

2. **Replace the generated files** with the ones already in this repo:
   - Delete the auto-generated `SampleHandler.swift` and `Info.plist` Xcode created.
   - In the file inspector, drag in `BroadcastExtension/SampleHandler.swift` and `BroadcastExtension/SharedFramePipe/SharedFramePipe.swift`, ensuring they're added to the new extension target (not the main app).
   - Set the extension target's `Info.plist` to `BroadcastExtension/Info.plist`.

3. **App Group** (the IPC channel):
   - Select the **main app target** → Signing & Capabilities → `+ Capability` → **App Groups**.
   - Add `group.com.enterprise.EnterpriseApp.screenshare`.
   - Repeat the same for the **extension target**; both must share the group.
   - The default group id is what `BroadcastExtension/Info.plist` references via `BROADCAST_APP_GROUP`. If you choose a different id, update both Info.plists.

4. **Host app discovery of the extension**:
   - Open the **main app target** → Build Settings → Custom iOS Target Properties.
   - Add a new key `BROADCAST_EXTENSION_BUNDLE_ID` with value `com.enterprise.EnterpriseApp.ScreenShare` (matches the extension bundle id).
   - `ScreenShareSystemPicker` reads this and binds the `RPSystemBroadcastPickerView.preferredExtension` so iOS preselects your extension in the system picker.

5. **Host app entitlements** (only needed once):
   - Background Modes → tick **Audio, AirPlay, and Picture in Picture** and **Voice over IP**.
   - Push Notifications (for incoming-call VoIP pushes).

## What the scaffold gives you

- **`SampleHandler`** — receives video / audioApp / audioMic sample buffers from iOS at ~30Hz.
- **`SharedFramePipe`** — writes a tiny state plist (`isStarted` / `isPaused` / `frameCount`) into the App Group container so the host app knows screen-share is live.
- **Not yet wired**: the actual `CVPixelBuffer → SFU video track` push. When you adopt the LiveKit SDK, swap `SharedFramePipe` for [livekit-broadcast-extension](https://github.com/livekit-examples/swift-broadcast-extension)'s `LKBroadcastBuffer`, which uses an `IOSurface` for zero-copy delivery to the host app's `LocalParticipant.setScreenShare(enabled:)`.

## Verifying the extension works

After the manual Xcode setup:

```bash
xcodebuild -project EnterpriseApp.xcodeproj -scheme EnterpriseApp -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Then on a real device (the iOS Simulator can't capture the screen):

1. Open a call in the app.
2. Tap the screen-share button in the call header → the system broadcast picker should appear, with `EnterpriseApp Screen Share` pre-selected.
3. Tap **Start Broadcast** → iOS will show a red status bar.
4. Backend logs: `call.participant_state` event with `isScreenSharing=true`.
5. App Group state file: `~/Library/Group Containers/group.com.enterprise.EnterpriseApp.screenshare/broadcast.state.plist` should contain `isStarted=true`.

If the picker doesn't appear, check that the extension target is signed with the same Apple Development team and that the App Group is enabled on both targets.
