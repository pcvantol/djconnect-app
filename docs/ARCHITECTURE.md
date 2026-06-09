# Architecture

DJConnect App is a native Apple client for the Home Assistant `djconnect`
integration. The app is not an ESP32 emulator; it is a first-class app client
identified by `client_type`.

## Trust Boundary

Home Assistant owns:

- pairing and DJConnect bearer-token lifecycle;
- Spotify OAuth and future playback backend credentials;
- playback commands;
- Assist/STT/TTS;
- native Home Assistant entities.

The Apple app owns:

- native iOS/macOS UI;
- local app state;
- local Keychain storage for only the DJConnect bearer token;
- local audio recording for push-to-talk, when implemented;
- optional playback of returned DJ response audio.

The app must never store Spotify, Sonos, Home Assistant long-lived access
tokens, OpenAI, or playback backend credentials.

## Targets

`DJConnectCore`

The UI-free integration contract layer. It builds authenticated requests,
serializes status/command/voice payloads, decodes playback and voice responses,
classifies backend errors, and abstracts token storage.

`DJConnectUI`

Shared SwiftUI screens for iOS and macOS. This module depends on
`DJConnectCore`, but the HTTP client does not depend on SwiftUI.

`DJConnectIOS`

Native iOS app target. It hosts the shared SwiftUI root view in an iOS app
scene.

`DJConnectMac`

Native macOS app target. It hosts the shared SwiftUI root view in a macOS app
scene and exposes a native settings scene.

## State Handling

Pairing/auth failures are intentionally conservative:

- `backend_unavailable`: keep pairing and token, show playback backend state.
- HTTP `426` / `version_mismatch`: keep pairing and token, show update required.
- HTTP `401`/`403`: mark pairing stale, keep token until user reset.
- HTTP `404`: show integration/setup recovery, keep token until user reset.

Only explicit user pairing reset should clear Keychain token state.

## Project Generation

`project.yml` is the XcodeGen source of truth. Regenerate the Xcode project
with:

```sh
xcodegen generate
```

The generated `DJConnectApp.xcodeproj` is committed so the repo opens directly
in Xcode.
