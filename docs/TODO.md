# Todo And Known Issues

This document tracks open implementation work and known project gaps.

## High Priority

- Confirm the Home Assistant integration accepts app pairing payloads with
  `device_id`, temporary `client_id`, `pair_code`, `pairing_code`, and
  `pairing_token`.
- Add a Home Assistant UI/deep-link path for accepting app-generated pairing
  codes.
- Replace remaining preview/sample queue and playlist state with live backend
  state.
- Add diagnostics export with required redaction rules.

## Playback

- Implement output selection using the backend `devices` command.
- Implement queue loading using the backend `queue` command.
- Implement playlists and liked proxy start flows.
- Add retry throttling for `backend_unavailable`.
- Expand command/status integration tests with URLProtocol-backed response
  fixtures.

## Voice/PTT

- Add microphone permission strings and platform permission handling.
- Implement mono PCM WAV recording.
- Upload WAV audio to `/api/djconnect/voice`.
- Display returned `text`/`dj_text`.
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

- Add URLProtocol-backed async tests for command, status, voice, network error,
  and malformed response handling.
- Add focused app-model tests for pairing retry state and stale authenticated
  auth recovery.
- Add tests that token stores never expose tokens through diagnostics.
- Add UI tests after real pairing and network state flows exist.

## Release/Build

- Configure Apple developer team and signing.
- Add privacy manifests if required by release tooling.
- Decide on CI provider and add build/test workflow.
- Decide on TestFlight/notarization/release packaging.

## Known Issues

- Pairing depends on the HA integration accepting app-generated pairing codes
  and exposing `POST /api/djconnect/pair`.
- Queue, playlist, output selection, and voice/PTT UI are still scaffolded.
- The app icon now follows the shared DJConnect brand asset from
  `pcvantol/djconnect`.
- `DJConnectCoreTests` currently run through Swift Package tests; Xcode test
  integration should be expanded as the app targets mature.
- `xcodebuild` may print simulator/cache warnings in the sandboxed Codex
  environment even when builds succeed.
