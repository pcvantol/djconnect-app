# Issues

This document tracks concrete follow-up issues that are not yet represented as
GitHub Issues. Use it as the local backlog until items are promoted to GitHub.

## Performance And Responsiveness

### ISS-001: Parallelize Refresh Collections

Priority: high

Manual refresh and startup refresh currently load devices, queue, and playlists
sequentially. Fetch these collections in parallel and keep the current
`isRefreshing` guard so the UI remains predictable.

Acceptance:

- `devices`, `queue`, and `playlists` can refresh concurrently.
- A failed collection does not prevent already successful collections from
  updating.
- Logs still show which collection failed.

### ISS-002: Centralize Refresh Debouncing

Priority: high

Several actions trigger command execution followed by delayed status refreshes.
Create a shared refresh scheduler so play/pause, next/previous, queue item
selection, voice completion, and volume changes coalesce into one near-term
Now Playing refresh.

Acceptance:

- Repeated playback commands do not stack multiple delayed refresh tasks.
- Now Playing still updates immediately after successful playback commands.
- Queue item selection clears its spinner after the scheduled refresh finishes.

### ISS-003: Bound DJ Response Audio Loading

Priority: medium

DJ response audio is loaded fully into memory before playback. Keep this safe
for short TTS clips by enforcing a maximum response size or downloading larger
responses to a temporary file.

Acceptance:

- Short response audio still plays normally.
- Oversized audio responses fail gracefully with a user-friendly log message.
- Temporary audio files are cleaned up.

## Architecture And Maintainability

### ISS-004: Split DJConnectAppModel Into Services

Priority: medium

`DJConnectAppModel` owns pairing, playback, voice, wakeword, permissions,
diagnostics and refresh orchestration. Split the
largest responsibilities into focused services while keeping `DJConnectCore`
UI-free.

Suggested services:

- `PairingCoordinator`
- `PlaybackCoordinator`
- `VoiceCoordinator`
- `PermissionCoordinator`
- `RefreshScheduler`

Acceptance:

- `DJConnectAppModel` remains the observable UI state owner.
- Network/audio orchestration can run outside the main actor where practical.
- Existing Swift tests remain green.

### ISS-005: Stabilize Queue Row Identity

Priority: medium

Spotify queues can contain repeated tracks, so URI-only row identity can create
duplicate SwiftUI IDs. Use a stable display identity that combines URI and
index, or another backend-provided unique queue id when available.

Acceptance:

- Duplicate tracks in queue no longer produce SwiftUI duplicate-ID warnings.
- Tapping a duplicate queue item sends the intended row index/context.

## Testing

### ISS-007: Add Network Fixture Tests

Priority: high

Add URLProtocol-backed tests for status, command, queue, playlists, voice
errors, version mismatch, backend unavailable, and malformed responses.

Acceptance:

- Tests cover HTTP status codes and response body mappings.
- Tests verify tokens and secrets are not logged or exposed in user-facing
  diagnostics.

### ISS-008: Add XCUITests For Pairing And Runtime Flows

Priority: medium

The initial UI test target exists, but end-to-end pairing and network flows
need a mock Home Assistant server or a live test Home Assistant environment.

Acceptance:

- UI tests cover first-run welcome, local Home Assistant URL/code entry,
  Watch/iPhone companion pairing status, Demo Mode entry/exit, successful
  pairing, version mismatch, stale auth, compact permission rows, Demo Mode
  microphone response, `App opnieuw koppelen`, Ask DJ error sanitizing, and the
  local Games menu.
- Tests can run deterministically without a production Home Assistant instance.

### ISS-014: Add Hardware Keyboard UI Coverage For Games

Priority: medium

Games now consume arrow keys and space while the game surface has focus. Add
coverage where XCTest/automation can reliably send hardware-keyboard events on
macOS or iPad simulator.

Acceptance:

- Arrow keys move/control the focused game.
- Space triggers the game action where supported.
- Keyboard input does not switch app tabs/pages while the game has focus.

## Security Hardening

### ISS-011: Validate App-Storage Token Reset UX

Priority: medium

DJConnect bearer tokens now live in app-private storage instead of Keychain.
Validate that pairing, relaunch, reset, and stale-auth recovery behave
predictably on supported Macs, iPhones, iPads, and Apple Watch.

Acceptance:

- Pairing never triggers a Keychain access prompt.
- App relaunch keeps the stored DJConnect token and stays paired.
- `App opnieuw koppelen` clears the locally stored token and opens the pairing
  sheet.
- Stale auth and backend errors do not clear the token until explicit reset.

### ISS-012: Bound Incoming Payload Size

Priority: high

Home Assistant responses, iPhone-mediated Watch proxy payloads, and local
diagnostics imports should reject oversized payloads to avoid unnecessary memory
growth from malformed traffic or fixtures.

Acceptance:

- HTTP response bodies and Watch proxy payloads have a maximum size.
- Oversized payloads receive a clear user-facing failure without token loss.
- Normal pairing, command, Ask DJ history, voice, and push registration flows
  still pass.

### ISS-013: Centralize Runtime Log Redaction

Priority: medium

Diagnostics export redacts sensitive values, but runtime logging should also
sanitize messages before they are appended to in-app logs or emitted through
OSLog.

Acceptance:

- Token-like JSON keys, authorization headers, query tokens, and temporary
  audio URLs are redacted before in-app log storage.
- Existing user-facing diagnostic exports remain redacted.
- Tests cover nested JSON and non-string token fields.

## Release And Platform Polish

### ISS-009: Validate On Physical Devices

Priority: high

Validate iOS, iPadOS, and macOS behavior on physical hardware with a matching
Home Assistant integration.

Acceptance:

- Local Network, Microphone, and Speech Recognition prompts are verified.
- Permission rows remain compact and readable on iPhone with normal and larger
  Dynamic Type settings.
- The shared DJConnect gradient canvas is visible behind every primary iOS/
  iPadOS screen.
- Queue/playlists/output/liked/voice flows are verified against real HA.
- HA entity creation and status sync are verified for all app client types.

### ISS-010: Decide Platform Extras

Priority: low

Decide whether macOS menu bar/media keys, iOS lock screen/live activities, and
Shortcuts support belong in the first public release.

Acceptance:

- Each platform extra has an explicit ship/defer decision.
- Deferred items are documented with rationale.
