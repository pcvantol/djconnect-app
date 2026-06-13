# DJConnect App

DJConnect. Muziekbediening met karakter.

This repository contains a native iOS/macOS DJConnect client scaffold that talks
to the Home Assistant `djconnect` custom integration. Home Assistant stays the
trusted backend for pairing, DJConnect bearer-token lifecycle, Spotify OAuth,
playback commands, Assist/STT/TTS, and native HA entities.

The app owns native UI, local app state, local bonus games, optional local voice
recording, and optional playback of returned DJ response audio. It must not
store Spotify, Home Assistant, Sonos, OpenAI, or other backend credentials. The
only app-owned credential is the DJConnect client bearer token issued by the
integration.

Website: [https://djconnect.pages.dev](https://djconnect.pages.dev)

## Documentation

- [docs/HANDOFF.md](docs/HANDOFF.md): original product and integration handoff.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): repository architecture and target responsibilities.
- [docs/ARCHITECTURE_DECISIONS.md](docs/ARCHITECTURE_DECISIONS.md): key decisions and rationale.
- [docs/API_CONTRACT.md](docs/API_CONTRACT.md): Home Assistant endpoint contract.
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): local development, generation, build, and test commands.
- [docs/RELEASE.md](docs/RELEASE.md): signing, TestFlight, notarization, and live HA validation checklist.
- [SYNC_PROMPTS.md](SYNC_PROMPTS.md): canonical copy/paste prompts for syncing the app, Home Assistant, and ESP repos.
- [docs/TODO.md](docs/TODO.md): open work, known issues, and next implementation steps.
- [docs/ISSUES.md](docs/ISSUES.md): concrete local backlog with priorities and acceptance criteria.
- [PRIVACY.md](PRIVACY.md): security, privacy, and diagnostics redaction rules.
- [CHANGELOG.md](CHANGELOG.md): notable project changes.

## First Run Requirements

On first launch the app shows a one-time DJConnect welcome screen with the
Home Assistant setup link:

- [https://djconnect.pages.dev/start](https://djconnect.pages.dev/start)

DJConnect playback requires a configured Home Assistant `djconnect`
integration and a Spotify Premium account. The app does not ask for Spotify
credentials; Spotify OAuth stays owned by Home Assistant.

If the app is not paired yet, the main runtime UI is blocked by a pairing
sheet. That sheet shows the DJConnect banner, copyable Client API url,
copyable app-generated pairing code, and live pairing status. After Home
Assistant completes pairing, the sheet shows a success state with a green
checkmark and a `Let's Start!` action before the runtime UI is released.

For App Store review and local UI inspection, the pairing sheet also exposes
Demo Mode. Demo Mode fills Now Playing, queue, playlists, and DJ announcement
UI with local sample data without contacting Home Assistant.
It is session-only, resets on app restart, and is not a replacement for live
backend validation. Pressing the microphone in Demo Mode shows and speaks a
local sample DJ announcement so App Store review can inspect the voice response
experience without a Home Assistant backend.

The app also includes local Games with Paddle Rally, Meteor Run, Sky Dash, and
Maze Chase, mirroring the ESP client bonus games. Games are local-only, store
highscores in app-local
preferences, and do not call Home Assistant or create HA entities. Games lazy
start behind a tap-to-play overlay, and leaving the Games screen resets them
back to that idle state. When a game surface has keyboard focus, arrow keys and
space are consumed by the game and must not trigger app navigation.

Debug and UI stress runs can launch with `--monkey-testing`. This starts a
non-destructive local Demo Mode, hides first-run/pairing blockers, avoids local
API/backend traffic, and is safe for random navigation/tap monkey tests.

Fresh installs default the Home Assistant URL field to
`http://homeassistant.local:8123`. Users can replace it with an IP-based local
URL when multicast DNS is unavailable.

## Package Shape

```text
DJConnectApp.xcodeproj
project.yml
Apps/
  DJConnectIOS/
  DJConnectMac/
docs/
Sources/
  DJConnectCore/
    DJConnectClient.swift
    DJConnectErrors.swift
    DJConnectKeychain.swift
    DJConnectModels.swift
Tests/
  DJConnectCoreTests/
```

`DJConnectCore` is intentionally UI-free. It handles:

- stable client identity payloads with `client_type` set to `ios` or `macos`;
- authenticated Home Assistant requests;
- status, command, and raw WAV voice request serialization;
- playback and voice response decoding;
- error classification for auth stale, backend unavailable, version mismatch,
  missing routes, and network failures;
- token storage through a small abstraction ready for Keychain-backed apps.

`DJConnectUI` contains the shared native SwiftUI screens used by both Apple app
targets. `Apps/DJConnectIOS` and `Apps/DJConnectMac` contain the platform app
entrypoints. The shared UI uses the same DJConnect blue/purple gradient canvas
on iOS, iPadOS, and macOS, while platform surfaces keep native table/list
behavior where that is the expected Apple idiom.

## Xcode

Open [DJConnectApp.xcodeproj](DJConnectApp.xcodeproj) in Xcode.

Schemes:

- `DJConnectIOS`: native iOS app target.
- `DJConnectMac`: native macOS app target.

The project is generated from [project.yml](project.yml) with XcodeGen:

```sh
xcodegen generate
```

Build checks used for this scaffold:

```sh
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -destination generic/platform=iOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
```

The latest verification was performed with Xcode 26.5 (`17F42`) against
macOS 26.5 and iPhoneOS 26.5 SDKs, with code signing disabled for local build
checks.

Private GitHub Actions CI runs Swift tests plus unsigned iOS/macOS build
checks. Public macOS binaries are produced locally with Developer ID signing
and notarization, then uploaded to
[pcvantol/djconnect-app-releases](https://github.com/pcvantol/djconnect-app-releases).
Use the one-time and per-release App Store/macOS checklist in
[docs/RELEASE.md](docs/RELEASE.md) before publishing signed builds.

## Swift Package

The reusable core and UI modules also compile as a Swift Package:

```sh
swift test
```

## Integration Contract

Status is posted to:

```http
POST /api/djconnect/status
```

Playback commands are posted to:

```http
POST /api/djconnect/command
```

Voice/PTT WAV audio, when implemented by an app target, is posted to:

```http
POST /api/djconnect/voice
Content-Type: audio/wav
```

The native app also uses command proxy flows for backend devices, queue,
playlists, liked songs, and output selection:

```http
POST /api/djconnect/command
{"command":"devices"}
{"command":"queue"}
{"command":"playlists"}
{"command":"seek_relative","value":15000}
{"command":"seek_relative","value":-15000}
{"command":"set_output","value":"<device id or name>"}
{"command":"start_playlist","value":"spotify:playlist:...","play":true}
{"command":"play_context_at","value":{"context_uri":"spotify:playlist:...","offset_uri":"spotify:track:..."},"play":true}
{"command":"start_liked_proxy","play":true}
```

Queue item playback includes `offset_uri` only for Spotify contexts that support
offsets, such as playlist, album and show contexts. Artist contexts are sent
without `offset_uri` to avoid Spotify API offset errors.

The iOS/macOS app can expose seek controls for the current track. It sends
`command:"seek_relative"` with `value` in milliseconds. Positive values seek
forward, negative values seek backward. This is an Apple-app-only UI affordance;
ESP clients may omit it.

The output selector shows a local `Geen`/`None` option followed by real backend
devices returned by Home Assistant. The app does not add local `iPhone
standaard` or `Mac standaard` choices. Selecting `Geen` blocks playback-start
commands until the user chooses a real backend output.

Foreground wakeword support is available from Settings. When enabled for the
current app session, the app uses Apple Speech while the app is open to listen
for the configured wake phrase (`Hey DJ` by default), then records a short WAV
voice request through the normal `/api/djconnect/voice` flow. The app does not
run an always-on background wakeword listener and does not auto-start wakeword
listening after launch. Wakeword listening is disabled on iOS Simulator because
simulator speech/audio capture is unstable; test it on a real iPhone or iPad.

Queue requests include `limit:100`. Responses may use `queue.items` plus
`queue.context`, flat `queue` arrays, or flat `items` for compatibility. The
app also accepts top-level `context_uri` and `contextUri` and supports album-art
aliases `album_image_url`, `media_image_url`, `image_url`, and
`entity_picture`. Home Assistant should return real queue items only, without
padding repeated copies of the current track.

Command responses are transport success first and playback-state second.
`success:true` with `playback.has_playback:false` is a valid empty playback
snapshot, not an error; playback fields such as progress, duration, volume,
track metadata, context and artwork URLs may be `null`.

All status and command payloads include `device_id`, `client_type`, and
`firmware`. The `firmware` value remains the protocol compatibility version,
even for app clients.

Pairing is posted to:

```http
POST /api/djconnect/pair
```

The app sends `device_id`, `device_name`, `client_type`, `firmware`,
`app_version`, `platform`, and the app-generated code as `pair_code`,
`pairing_code`, and `pairing_token`. The app keeps polling until Home Assistant
accepts that code and returns a DJConnect bearer token plus the HA local URL
metadata. The current preferred response field is `device_token`; `bearer_token`
and `token` are accepted for compatibility.

The iOS/macOS app also hosts a Bonjour-advertised local Web API for
Home Assistant -> app traffic:

```http
GET /api/device/info
GET /api/device/pairing-info
POST /api/device/pair
POST /api/device/command
POST /api/device/dj_response
POST /api/device/forget
```

Protected local endpoints require `Authorization: Bearer <device_token>`.
The Apple app does not implement ESP-only reboot or OTA routes.

The user-facing name for this local endpoint is `Client API url`. The URL shown
during pairing is pinned after successful pairing and remains stable in app
storage until the user explicitly resets pairing.

## Version Contract

DJConnect clients and the Home Assistant integration must share the same
`major.minor` protocol version. Patch versions may differ.

If Home Assistant returns HTTP `426` with `error: "version_mismatch"`, the app
must keep pairing and token state, show an update-required state, and pause
command/voice retries until the app or integration is updated.

Successful status and command responses may also include `ha_version` or
`ha_major_minor`. App `3.1.x` requires HA integration `3.1.x` and disables
playback, queue, playlist, output, liked, and voice controls when the runtime
contract is outside that range. Settings and pairing reset remain available.

## Diagnostics And Crash Reports

Diagnostics are user-mediated. The app redacts tokens and does not upload logs
automatically. If the previous session appears to have ended uncleanly, the
next launch offers to copy redacted logs or open a prefilled GitHub issue in
`pcvantol/djconnect` for manual submission.

The app also keeps a local redacted rolling diagnostic logfile in Application
Support at `DJConnect/Logs/djconnect.log`. It is loaded back into the Logs
screen on restart, capped at 500 lines and 128 KB, and cleared when the user
clears logs in the app.

DEBUG logs include user actions, navigation/recovery flows, Home Assistant API
calls, and local Client API calls. API log lines include HTTP status codes and
must not include bearer tokens, pairing codes, Authorization headers, or raw
secret-bearing bodies.

On iOS, returning from the Home screen or another app schedules a full playback
refresh so Now Playing state catches up with changes made outside DJConnect.

## Security

Never log bearer tokens, Home Assistant tokens, Spotify refresh tokens, OAuth
client secrets, WiFi passwords, or temporary TTS/audio URLs. See
[PRIVACY.md](PRIVACY.md) for diagnostic redaction rules.
