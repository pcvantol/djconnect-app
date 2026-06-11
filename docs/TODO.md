# Todo And Known Issues

This document tracks open implementation work and known project gaps.

## High Priority

- Confirm the Home Assistant integration accepts app pairing payloads with
  `device_id`, `client_type`, `device_name`, `pair_code`, `pairing_code`, and
  `pairing_token`.
- Add a Home Assistant UI/deep-link path for accepting app-generated pairing
  codes.
- Validate live backend devices, queue, playlists, liked proxy, and voice flows
  against a real Home Assistant `djconnect` setup.

## Playback

- Add retry throttling and user-facing recovery copy for `backend_unavailable`.
- Expand command/status integration tests with URLProtocol-backed response
  fixtures.

## Voice/PTT

- Optionally play returned WAV/MP3 response audio without logging `audio_url`.

## iOS

- Tune app icon presentation before release if App Store review or platform
  guidelines require changes.
- Tune iPhone and iPad layouts with real device/simulator screenshots.
- Decide whether lock screen/live activity support belongs in the first release.
- Decide whether Shortcuts integration should map to DJConnect commands.

## macOS

- Decide whether to add a menu bar controller.
- Add media key support only if it maps cleanly to DJConnect commands.
- Tune window sizing, sidebar defaults, and settings layout.

## Testing

- Extend the initial `DJConnectIOSUITests` target with a real or recorded Home
  Assistant pairing and network flow fixture.
- Add URLProtocol-backed async tests for network error and malformed response
  handling.
- Add focused app-model tests for permission status mapping once platform
  authorization APIs are wrapped behind injectable adapters.
- Add focused app-model tests for pairing retry state and stale authenticated
  auth recovery.
- Add more diagnostics export tests for `audio_url`, `Authorization`, and
  arbitrary token-like JSON fields.

## Release/Build

- Configure Apple developer team and signing.
- Add privacy manifests if required by release tooling.
- Decide on CI provider and add build/test workflow.
- Configure TestFlight and notarized macOS release packaging.

## Known Issues

- Pairing depends on the HA integration accepting app-generated pairing codes
  and exposing `POST /api/djconnect/pair`.
- Live queue, playlist, output selection, liked proxy, and voice/PTT are wired
  in the Apple app, but still need validation against the matching HA backend.
- The app icon now follows the shared DJConnect brand asset from
  `pcvantol/djconnect`.
- `DJConnectCoreTests` currently run through Swift Package tests; Xcode test
  integration should be expanded as the app targets mature.
- `xcodebuild` may print simulator/cache warnings in the sandboxed Codex
  environment even when builds succeed.
