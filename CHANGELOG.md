# Changelog

All notable changes to DJConnect App are documented here.

## Unreleased

### Changed

- Aligned iOS/macOS app-client pairing, status, command, and voice requests
  with the Home Assistant contract by using `device_id` as the only over-the-
  wire app identity and removing `client_id` headers/payload fields.
- Persisted `ha_local_url`, optional `ha_remote_url`, active HA URL, and
  language metadata returned by pairing; status now reports HA URL metadata.
- Status, command, and voice requests now switch to `ha_remote_url` after a
  local Home Assistant network failure when pairing returned a remote URL.
- Expanded macOS functional parity with iOS by adding refresh behavior and HA
  URL visibility in shared settings.
- Fixed macOS/iOS pairing polling so a Home Assistant HTTP 401 code mismatch
  stops the wait loop and tells the user to re-enter the visible app code.
- Added a local Bonjour-advertised `/api/device/*` Web API for HA -> Apple app
  traffic, including info, pairing-info, pair, command, DJ response, and forget.
- Local API now prefers a reachable LAN IPv4 URL over a best-effort `.local`
  hostname so Home Assistant can call the app directly.
- Local pairing-info now returns typed JSON and local pair failures are logged
  with the exact reject reason for Home Assistant repair diagnostics.

## 3.1.0 - 2026-06-10

### Added

- Added a complete native iOS/macOS Xcode project with shared `DJConnectCore`
  and `DJConnectUI` modules, app targets, generated app icons, Keychain token
  storage, and Swift Package/Xcode test coverage.
- Added Home Assistant pairing for Apple app clients with app-generated codes,
  canonical `device_id` identity, bearer-token storage, stale auth handling,
  version mismatch handling, and reset/recovery flows.
- Added native playback controls for play/pause, previous, next, volume,
  shuffle, repeat, output selection, queue loading, playlists, and liked proxy
  through `/api/djconnect/command`.
- Added Push-to-Talk recording with mono PCM WAV upload to
  `/api/djconnect/voice`.
- Added native iOS/macOS UI for setup status, now playing, playback controls,
  queue/playlists, DJ response, settings, language switching, log level, and
  diagnostics.
- Added app logging with log-level filtering, OSLog output, in-app diagnostics,
  stable log row ids, and redacted diagnostics export copy support.
- Added Local Network, Bonjour, local HTTP transport, and Microphone usage
  declarations for Apple platforms.
- Added README, handoff, API contract, architecture, architecture decisions,
  sync prompts, TODO/issues, privacy, release signing, TestFlight,
  notarization, and live HA validation documentation.
- Added tests for status, command, pairing, voice requests, backend
  unavailable, version mismatch, backend collection decoding, and diagnostics
  redaction.

### Changed

- Set app/protocol version to `3.1.0`.
- Kept the Apple app on HA-owned backend routes and removed the local
  `/api/device/*` app endpoint because those routes are reserved for ESP
  hardware clients.
- Improved pairing polling so temporary Home Assistant 401 responses keep the
  app waiting while reset pairing stops cleanly and rotates local identity.
- Improved stale pairing, missing integration-route, backend unavailable, and
  update-required UI states without clearing the Keychain token automatically.
- Expanded `.gitignore` with SwiftPM, Xcode, macOS, Fastlane, CocoaPods, and
  Carthage generated output rules.

### Verified

- `swift test`
- `xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build`
- `xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -destination generic/platform=iOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build`
