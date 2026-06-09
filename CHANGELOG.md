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
- Made the in-app language picker switch visible UI text between Dutch and
  English, and persist the selected language.
- Added the missing Error option to the Log Level picker.
- Translated the empty playback output label in Dutch.
- Added Local Network, Home Assistant Bonjour service, and local HTTP transport
  declarations to the iOS/macOS app plists for local Home Assistant access.
- Made Home Assistant URL entry accept bare local addresses like
  `192.168.1.10:8123` and debounce pairing retries while editing.
- Added app logging with log-level filtering, OSLog output, and an in-app
  diagnostics log for pairing, status refresh, commands, and network errors.
- Added a local Bonjour-advertised app device API for Home Assistant to call
  `/api/device/pairing-info`, `/api/device/pair`, `/api/device/command`, and
  `/api/device/dj_response` during two-way pairing and status updates.
- Sent both `pair_code` and `pairing_token` during app-initiated pairing and
  posted status immediately after Home Assistant pairs through the local API.
- Stopped repeated pairing polling when Home Assistant rejects the current
  pairing code, and show guidance to generate/use a fresh code.
- Made Reset Pairing stop at a clean reset instead of immediately retrying with
  a potentially stale Home Assistant code.

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
