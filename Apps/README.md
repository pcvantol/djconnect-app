# DJConnect Native App Entrypoints

This folder contains the SwiftUI `@main` entrypoints for the native app targets:

- `DJConnectIOS/DJConnectIOSApp.swift`
- `DJConnectMac/DJConnectMacApp.swift`
- `DJConnectWatch/DJConnectWatchApp.swift`

iOS and macOS use the shared `DJConnectUI` package product, which keeps UI
screens separate from the `DJConnectCore` HTTP/client contract. watchOS uses a
compact standalone SwiftUI surface backed directly by `DJConnectCore`.

Ask DJ is the rich Apple-side chat/PTT experience across iOS, macOS, and
watchOS. Do not add a separate Now Playing DJ request surface; voice and text DJ
requests belong in Ask DJ.

## Native App Integration Notes

- iOS home-screen quick actions and widgets route through the shared
  `DJConnectHomeScreenAction` / `djconnect://` navigation path. Keep shortcut
  item types, widget URLs and root-view tab handling in sync when adding a new
  destination.
- The iOS QR pairing scanner is the only pre-pairing permission flow. Show the
  camera explanation sheet before requesting camera access; microphone, speech
  recognition and other app permissions are requested later from inside the app
  after pairing.
- iOS must keep `NSCameraUsageDescription` in both `Apps/DJConnectIOS/Info.plist`
  and `project.yml`, because the QR scanner uses `AVCaptureDevice` directly.
- Demo mode still writes widget snapshots for Now Playing, Queue, Playlists,
  Track Insight and Ask DJ so widgets can refresh without a Home Assistant
  backend.
- Music DNA navigation uses the outline `heart` icon on iOS, macOS, and
  watchOS. Filled hearts are reserved for favorite/save-track actions.
- Now Playing output selection on iOS and macOS should stay inline and
  Watch-like: rows for `Geen`/`None` plus real backend outputs, with no
  separate drill-in page for the ordinary selection flow.
- Track Insight and VibeCast visualizers are expected to animate smoothly while
  playback is active; avoid periodic one-second timers for in-app visual scenes.
