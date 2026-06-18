# Todo And Known Issues

This document tracks app-local known project gaps. The canonical product
roadmap lives in `pcvantol/djconnect/PRODUCT_ROADMAP.md`; if roadmap changes
originate here, update `pcvantol/djconnect` separately. Concrete backlog items
with acceptance criteria live in [ISSUES.md](ISSUES.md).

## High Priority

- Validate live backend devices, queue, playlists, liked proxy, and voice flows
  against a real Home Assistant `djconnect` setup.
- Validate HA entity creation and status sync for iOS, iPadOS, and macOS app
  clients after pairing.
- Validate the blocking pairing sheet and Demo Mode on physical iPhone, iPad,
  and Mac before App Store/TestFlight review.
- Keep the Apple app and Home Assistant integration on the same `major.minor`
  protocol line; app `3.1.x` requires HA `3.1.x`.
- Work through the high-priority local issues in [ISSUES.md](ISSUES.md),
  especially refresh latency, network fixtures, and physical-device validation.

## Playback

- Add retry throttling and user-facing recovery copy for `backend_unavailable`.
- Parallelize collection refreshes and centralize refresh debouncing.
- Expand command/status integration tests with URLProtocol-backed response
  fixtures.

## Voice/PTT

- Optionally play returned WAV/MP3 response audio without logging `audio_url`.
- Add response-audio size bounds or temporary-file playback for larger clips.

## iOS

- Tune app icon presentation before release if App Store review or platform
  guidelines require changes.
- Tune iPhone and iPad layouts with real device/simulator screenshots.
- Re-check that every primary iPhone/iPad screen uses the DJConnect gradient
  canvas and that compact permission rows stay readable with Dynamic Type.
- Decide whether lock screen/live activity support belongs in the first release.
- Decide whether Shortcuts integration should map to DJConnect commands.

## macOS

- Decide whether to add a menu bar controller.
- Add media key support only if it maps cleanly to DJConnect commands.
- Tune window sizing, sidebar defaults, and settings layout.

## Testing

- Extend the initial `DJConnectIOSUITests` target with a real or recorded Home
  Assistant pairing and network flow fixture.
- Add UI tests for compact permission rows, Demo Mode microphone response, and
  hardware-keyboard game input where XCTest can cover those surfaces reliably.
- Add URLProtocol-backed async tests for network error and malformed response
  handling.
- Add focused app-model tests for permission status mapping once platform
  authorization APIs are wrapped behind injectable adapters.
- Add focused app-model tests for pairing retry state and stale authenticated
  auth recovery.
- Add more diagnostics export tests for `audio_url`, `Authorization`, and
  arbitrary token-like JSON fields.
- Add security hardening tests for local API request-size limits and Keychain
  accessibility attributes.
- Add performance regression checks for refresh coalescing and repeated artwork
  URLs.

## Release/Build

- Configure Apple developer team and signing.
- Add privacy manifests if required by release tooling.
- Configure required reviewers and secrets for the protected `testflight-beta`
  GitHub Environment, plus notarized macOS release packaging.
- Keep English and Dutch What's New release notes aligned with the latest
  GitHub release and only add new work to an `Unreleased` changelog section
  after tags are published.
- Restore a green public unsigned release for `3.1.33` or the next patch so
  `ios/vX.Y.Z` and `macos/vX.Y.Z` diagnostic artifact releases are published
  again; `3.1.33` static What's New files are already live on `djconnect.dev`.

## Known Issues

- Live queue, playlist, output selection, liked proxy, and voice/PTT are wired
  in the Apple app, but still need validation against the matching HA backend.
- The app icon now follows the shared DJConnect brand asset from
  `pcvantol/djconnect`.
- The unpaired app now has Demo Mode for UI inspection, but Demo Mode does not
  validate HA pairing, HA entity creation, Spotify OAuth, or voice round trips.
- `DJConnectCoreTests` currently run through Swift Package tests; Xcode test
  integration should be expanded as the app targets mature.
- `xcodebuild` may print simulator/cache warnings in the sandboxed Codex
  environment even when builds succeed.
