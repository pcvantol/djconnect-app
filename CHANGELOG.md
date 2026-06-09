# Changelog

All notable changes to DJConnect App are documented here.

## Unreleased

### Added

- Added native Xcode project `DJConnectApp.xcodeproj` generated from
  `project.yml`.
- Added iOS app target `DJConnectIOS`.
- Added macOS app target `DJConnectMac`.
- Added shared SwiftUI module `DJConnectUI` for setup/status, now playing,
  playback controls, queue, playlists, DJ response, and settings screens.
- Added shared core module `DJConnectCore` for Home Assistant request building,
  models, error classification, and token storage abstractions.
- Added Keychain-backed and in-memory DJConnect token stores.
- Added unit tests for status, command, voice, version mismatch, and backend
  unavailable behavior.
- Added privacy and diagnostics documentation.
- Added handoff, architecture, API contract, and development documentation.
- Added architecture decision record and todo/issues documentation.
- Implemented macOS/iOS app-generated pairing code flow against
  `POST /api/djconnect/pair` with Keychain device-token storage and status
  validation.
- Added official DJConnect app icon assets from `pcvantol/djconnect` for macOS
  and iOS.
- Replaced the manual Pair button with automatic waiting for Home Assistant to
  accept the app-generated pairing code.
- Wired native playback controls to `POST /api/djconnect/command` for
  play/pause, previous, next, volume, shuffle, and repeat.
- Added a richer native iOS now-playing interface with pairing status, album
  artwork, playback controls, volume, repeat/shuffle, and DJ response panels.

### Changed

- Set app/protocol scaffold version examples to `3.0.0`.
- Improved stale pairing and missing integration-route UI states without
  clearing the Keychain token automatically.
- Expanded `.gitignore` with SwiftPM, Xcode, macOS, Fastlane, CocoaPods, and
  Carthage generated output rules.
- Expanded README with Xcode, Swift Package, documentation, and integration
  contract sections.

### Verified

- `swift test`
- `xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -destination generic/platform=iOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build`
