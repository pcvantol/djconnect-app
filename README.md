# DJConnect App

Native Apple client foundation for DJConnect.

This repository contains a native iOS/macOS DJConnect client scaffold that talks
to the Home Assistant `djconnect` custom integration. Home Assistant stays the
trusted backend for pairing, DJConnect bearer-token lifecycle, Spotify OAuth,
playback commands, Assist/STT/TTS, and native HA entities.

The app owns native UI, local app state, optional local voice recording, and
optional playback of returned DJ response audio. It must not store Spotify,
Home Assistant, Sonos, OpenAI, or other backend credentials. The only app-owned
credential is the DJConnect client bearer token issued by the integration.

## Documentation

- [docs/HANDOFF.md](docs/HANDOFF.md): original product and integration handoff.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): repository architecture and target responsibilities.
- [docs/ARCHITECTURE_DECISIONS.md](docs/ARCHITECTURE_DECISIONS.md): key decisions and rationale.
- [docs/API_CONTRACT.md](docs/API_CONTRACT.md): Home Assistant endpoint contract.
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): local development, generation, build, and test commands.
- [docs/RELEASE.md](docs/RELEASE.md): signing, TestFlight, notarization, and live HA validation checklist.
- [docs/SYNC_PROMPTS.md](docs/SYNC_PROMPTS.md): copy/paste prompts for syncing the app and Home Assistant repos.
- [docs/TODO.md](docs/TODO.md): open work, known issues, and next implementation steps.
- [PRIVACY.md](PRIVACY.md): security, privacy, and diagnostics redaction rules.
- [CHANGELOG.md](CHANGELOG.md): notable project changes.

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
entrypoints.

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
{"command":"set_output","value":"<device id or name>"}
{"command":"start_playlist","value":"spotify:playlist:...","play":true}
{"command":"start_liked_proxy","play":true}
```

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
accepts that code and returns a DJConnect bearer token plus HA local/remote URL
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

## Version Contract

DJConnect clients and the Home Assistant integration must share the same
`major.minor` protocol version. Patch versions may differ.

If Home Assistant returns HTTP `426` with `error: "version_mismatch"`, the app
must keep pairing and token state, show an update-required state, and pause
command/voice retries until the app or integration is updated.

## Security

Never log bearer tokens, Home Assistant tokens, Spotify refresh tokens, OAuth
client secrets, WiFi passwords, or temporary TTS/audio URLs. See
[PRIVACY.md](PRIVACY.md) for diagnostic redaction rules.
