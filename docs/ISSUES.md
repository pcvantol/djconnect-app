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
local API coordination, diagnostics, and refresh orchestration. Split the
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

- UI tests cover first-run welcome, settings URL entry, app-generated pairing
  code, Client adres copy, Demo Mode entry/exit, successful pairing, version
  mismatch, stale auth, compact permission rows, Demo Mode microphone response,
  and the local Games menu.
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

### ISS-011: Validate Keychain Biometry UX On Devices

Priority: medium

New DJConnect bearer token writes use Keychain user-presence access control.
Validate the actual prompts and fallback behavior on supported Macs, iPhones,
and iPads.

Acceptance:

- macOS shows Touch ID where available and password fallback otherwise.
- iOS shows Face ID/Touch ID where available and passcode fallback otherwise.
- Denying Keychain access shows the app-level recovery sheet and retrying opens
  the platform prompt again.
- A successful unlock does not repeatedly prompt during the same app session.

### ISS-012: Bound Local API Request Size

Priority: high

The local Client API should reject oversized headers and request bodies to
avoid unnecessary memory growth from malformed LAN traffic.

Acceptance:

- Local API request headers have a maximum size.
- Local API request bodies have a maximum size.
- Oversized requests receive a clear `413` or equivalent failure response.
- Normal pairing, command, DJ response, and forget requests still pass.

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
