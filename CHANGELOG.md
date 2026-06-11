# Changelog

All notable changes to DJConnect App are documented here.

## Unreleased

### Added

- Added private GitHub Actions CI for Swift tests and unsigned iOS/macOS build
  checks.
- Added a local signed/notarized macOS release helper that uploads zip and
  checksum assets to the public `pcvantol/djconnect-app-releases` repository.

### Changed

- Protected newly saved DJConnect bearer tokens with Keychain user-presence
  access control, enabling Touch ID on supported Macs and Face ID/Touch ID on
  supported iOS devices with platform password fallback.
- Removed duplicate welcome-screen title/subtitle below the DJConnect banner.
- Localized the welcome-screen Home Assistant setup line in Dutch.
- Changed the welcome-screen setup link to `https://djconnect.pages.dev/start`.
- Added a macOS-only quit option to the blocking pairing sheet.
- Moved the pairing code above the Client API url on the pairing sheet.
- Added a Keychain access recovery sheet when token access is denied.
- Cached a successfully unlocked Keychain token in memory for the app session
  to avoid repeated system prompts.
- Suppressed the possible-crash prompt while running under a debugger, reducing
  false positives after stopping from Xcode.
- Demo Mode now shows the DJConnect app icon as fallback Now Playing artwork.
- Wakeword remains disabled in Demo Mode to avoid starting real Speech/audio
  capture from sample state.

### Documentation

- Updated README, development, release, handoff, architecture, sync prompts,
  TODO, and issues documentation for the 3.1.7 pairing sheet, Demo Mode,
  Client API url stability, About website, Xcode 26.5 verification, and
  security-hardening backlog.

## 3.1.7 - 2026-06-11

### Added

- Added a blocking pairing sheet for unpaired clients with the DJConnect banner,
  copyable Client API url, copyable pairing code, and pairing status/progress.
- Added a post-pairing success state with a large green checkmark and a
  prominent "Let's Start!" action before releasing the main UI.
- Added a demo mode from the pairing sheet so App Store review/auditing can
  inspect playback, queue, playlists, output, and voice UI without a live Home
  Assistant backend.
- Added the DJConnect website `https://djconnect.pages.dev` to the About page.

### Changed

- Set app/protocol version to `3.1.7`.
- Delayed the wakeword activation prompt until after the user closes the
  pairing success sheet.

## 3.1.6 - 2026-06-11

### Added

- Added one-time first-install onboarding with DJConnect branding, setup link
  to `pcvantol/djconnect`, and a Spotify Premium requirement notice.
- Added user-mediated crash reporting after suspected unclean exits: users can
  copy redacted diagnostics or open a prefilled GitHub issue. The app never
  uploads logs automatically.
- Added Home Assistant integration version gating: app `3.1.x` accepts HA
  `3.1.x` only (`>=3.1.0`, `<3.2.0`) and disables playback/output/queue/
  playlist/liked/voice controls while Settings and pairing reset remain
  available.
- Added Settings permission status/preflight UI for Microphone, Speech
  Recognition, and Local Network.
- Added foreground wakeword support with a configurable wake phrase, defaulting
  to "Hey DJ", using Apple Speech while the app is open. Wakeword is
  session-only, does not auto-start after launch, and is disabled on iOS
  Simulator because simulator speech/audio capture is unstable.
- Added a post-pairing wakeword activation prompt when wakeword is still off,
  with explicit activate and not-now actions.
- Added local playback for returned DJ response audio URLs when local response
  audio is enabled.
- Added a local backlog in `docs/ISSUES.md` with priorities and acceptance
  criteria for performance, testing, release validation, and platform polish.

### Changed

- Set app/protocol version to `3.1.6`.
- Consolidated README, handoff, sync prompts, release notes, architecture docs,
  TODO, and issues documentation around onboarding, Spotify Premium, crash
  reporting, version gating, permissions, release validation, and performance
  follow-ups.
- Tightened app-client identity and pairing behavior for iOS/macOS: use
  `device_id` plus `client_type`, keep app-generated pairing codes stable
  during mismatch recovery, persist `ha_local_url`, and keep cloud URLs out of
  app-to-HA runtime traffic.
- Kept the Client API url used during pairing stable until explicit pairing
  reset so Home Assistant can continue calling the same local app endpoint
  after restarts.
- Expanded the local `/api/device/*` Apple app API for Home Assistant -> app
  traffic, including info, pairing-info, pair, command, DJ response, and forget
  routes.
- Improved Now Playing, Queue, Playlists, Settings, Logs, and About UI across
  iOS, iPadOS, and macOS, including iPad launch/hero layout, app banner usage,
  copyable pairing/API details, clearer Dutch labels, better log naming, and
  macOS sizing/icon behavior.
- Reworked playback UX: output selection lives on Now Playing, playlist flows
  have their own page, liked songs use the same row style, shuffle/repeat use
  consistent icon buttons, and transport icons now use previous-track/
  next-track semantics.
- Improved refresh behavior for startup, pairing completion, manual refresh,
  play/pause/next/previous, queue item selection, volume commits, and voice
  responses so Now Playing, album art, output, queue, playlists, and progress
  recover more reliably after Home Assistant/Spotify settle.
- Updated queue handling to the Home Assistant `queue.items` contract with
  context preservation, album-art aliases, duplicate-row-safe SwiftUI
  identities, `play_context_at` playback, and Spotify offset safeguards for
  contexts that do not support offsets.
- Improved voice/PTT behavior with true press-to-hold recording, listening/
  processing states, friendly STT/OAuth error mapping, JSON server-message
  extraction, and relative audio URL resolution against the HA local URL.
- Improved diagnostics/logging by redacting server error bodies, keeping
  technical voice/backend details in logs instead of UI, shortening log level
  labels to `INF`, `DBG`, `WRN`, and `ERR`, and keeping logs pinned to the
  newest entry.
- Refined app architecture/documentation around permission boundaries,
  user-mediated crash reporting, current version contract, release cleanup, and
  future performance work.

### Fixed

- Fixed iPadOS simulator microphone permission crashes by using the iOS 17+
  recording-permission API and returning permission callbacks to the MainActor.
- Fixed manual refresh clearing album art when sparse status payloads were
  returned by loading rich Now Playing snapshots first.
- Fixed queue item playback attempts that used unsupported HA commands by
  switching to supported context-based playback.
- Fixed Now Playing album art layout so artwork remains square and cannot push
  title/artist text off screen.
- Fixed volume slider state when top-level playback volume is missing by using
  active playback-device volume.
- Fixed raw JSON and technical backend errors appearing in the DJ announcement
  card by extracting friendly messages and logging the technical details.

## 3.1.4 - 2026-06-11

### Added

- Added an initial `DJConnectIOSUITests` target with deterministic
  `--uitesting` launch mode, isolated defaults, in-memory token storage, mock
  Home Assistant URL seeding, and coverage for primary iOS navigation and
  Settings URL wiring.
- Added iOS release/signing documentation covering Apple Developer Program
  requirements, bundle identifiers, signing team setup, device testing,
  archives, and TestFlight upload prerequisites.

### Changed

- Set app/protocol version to `3.1.4`.
- Persisted Speech Recognition usage descriptions in `project.yml` so wakeword
  permissions survive Xcode project regeneration.
- Increased the default and minimum macOS main window size so the sidebar/menu
  layout has more room by default.

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
