# DJConnect App

Native Apple client foundation for DJConnect.

This repository contains a native iOS/macOS DJConnect client scaffold that talks
to the Home Assistant `djconnect` custom integration. Home Assistant stays the
trusted backend for pairing, DJConnect bearer-token lifecycle, Spotify OAuth,
playback commands, Assist/STT/TTS, and native HA entities.

The app owns native UI, local app state, optional local voice recording, and
optional playback of returned DJ response audio. It must not store Spotify,
Home Assistant, Sonos, OpenAI, or other backend credentials. The only app-owned
credential is the DJConnect device bearer token issued by the integration.

## Documentation

- [docs/HANDOFF.md](docs/HANDOFF.md): original product and integration handoff.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): repository architecture and target responsibilities.
- [docs/ARCHITECTURE_DECISIONS.md](docs/ARCHITECTURE_DECISIONS.md): key decisions and rationale.
- [docs/API_CONTRACT.md](docs/API_CONTRACT.md): Home Assistant endpoint contract.
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): local development, generation, build, and test commands.
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

All status and command payloads include `client_id`, `client_type`, and
`firmware`. During route compatibility with current Home Assistant builds, the
same stable app id is also sent as `device_id`. The `firmware` value remains
the protocol compatibility version, even for app clients.

Pairing is posted to:

```http
POST /api/djconnect/pair
```

The app sends `client_id`, `client_name`, `client_type`, `firmware`,
`app_version`, `platform`, temporary `device_id`/`device_name` compatibility
fields, and an app-generated `pairing_token`. The app keeps waiting until Home
Assistant accepts that code and returns `device_token`, then stores the token in
Keychain. The iOS/macOS app does not expose or use ESP-local `/api/device/*`
routes.

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
