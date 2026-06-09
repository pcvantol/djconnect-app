# Todo And Known Issues

This document tracks open implementation work and known project gaps.

## High Priority

- Confirm the Home Assistant `POST /api/djconnect/pair` response shape against
  the custom integration.
- Confirm the HA integration's pending response shape while the app is waiting
  for code acceptance.
- Add a Home Assistant UI/deep-link path for accepting app-generated pairing
  codes.
- Wire `DJConnectClient` into `DJConnectAppModel` for real status and command
  calls.
- Replace preview/sample playback state with live backend state.
- Add diagnostics export with required redaction rules.

## Playback

- Implement play/pause, next, previous, volume, shuffle, and repeat commands.
- Implement output selection using the backend `devices` command.
- Implement queue loading using the backend `queue` command.
- Implement playlists and liked proxy start flows.
- Add retry throttling for `backend_unavailable`.
- Add UI states for stale pairing, missing integration route, and version
  mismatch.

## Voice/PTT

- Add microphone permission strings and platform permission handling.
- Implement mono PCM WAV recording.
- Upload WAV audio to `/api/djconnect/voice`.
- Display returned `text`/`dj_text`.
- Optionally play returned WAV/MP3 response audio without logging `audio_url`.

## iOS

- Tune the generated app icon before release if a final brand mark becomes
  available.
- Tune iPhone and iPad layouts with real device/simulator screenshots.
- Decide whether lock screen/live activity support belongs in the first release.
- Decide whether Shortcuts integration should map to DJConnect commands.

## macOS

- Decide whether to add a menu bar controller.
- Add media key support only if it maps cleanly to DJConnect commands.
- Tune window sizing, sidebar defaults, and settings layout.

## Testing

- Add URLProtocol-backed async tests for `DJConnectClient` response handling.
- Add tests for 401, 403, 404, network errors, and malformed responses.
- Add tests that token stores never expose tokens through diagnostics.
- Add UI tests after real pairing and network state flows exist.

## Release/Build

- Configure Apple developer team and signing.
- Add app icons and privacy manifests if required by release tooling.
- Decide on CI provider and add build/test workflow.
- Decide on TestFlight/notarization/release packaging.

## Known Issues

- Pairing depends on the HA integration accepting app-generated pairing codes
  and exposing `POST /api/djconnect/pair`.
- The current playback UI is a scaffold and only pairing/status are wired.
- The app icon is a generated placeholder brand mark and may need final design
  polish before release.
- `DJConnectCoreTests` currently run through Swift Package tests; Xcode test
  integration should be expanded as the app targets mature.
- `xcodebuild` may print simulator/cache warnings in the sandboxed Codex
  environment even when builds succeed.
