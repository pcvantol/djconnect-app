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
- the shared DJConnect blue/purple gradient canvas on iOS, iPadOS, and macOS;
- local app state;
- local bonus games with app-local highscores;
- local Keychain storage for only the DJConnect bearer token;
- a pinned Client API url after successful pairing, kept stable until explicit
  pairing reset;
- local audio recording for push-to-talk, when implemented;
- optional playback of returned DJ response audio.
- user-facing permission status and preflight requests for Microphone and
  Speech Recognition.
- one-time first-run onboarding that points setup to Home Assistant and notes
  the Spotify Premium requirement.
- local Demo Mode state for App Store review and UI inspection without a live
  backend.

The app must never store Spotify, Sonos, Home Assistant long-lived access
tokens, OpenAI, or playback backend credentials.

## Targets

`DJConnectCore`

The UI-free integration contract layer. It builds authenticated requests,
serializes status/command/voice payloads, decodes playback and voice responses,
classifies backend errors, and abstracts token storage.

`DJConnectUI`

Shared SwiftUI screens for iOS and macOS. This module depends on
`DJConnectCore`, but the HTTP client does not depend on SwiftUI. Platform
permission state lives here because it directly controls voice/wakeword UX and
requires Apple UI frameworks.

`DJConnectIOS`

Native iOS app target. It hosts the shared SwiftUI root view in an iOS app
scene.

`DJConnectMac`

Native macOS app target. It hosts the shared SwiftUI root view in a macOS app
scene and exposes a native settings scene.

## State Handling

Pairing/auth failures are intentionally conservative:

- `backend_unavailable`: keep pairing and token, show playback backend state.
- HTTP `426` / `version_mismatch`, or successful responses with incompatible
  `ha_version`: keep pairing and token, show that the HA integration must be
  updated, and disable runtime playback/voice controls.
- HTTP `401`/`403` on authenticated routes: mark pairing stale, keep token until
  user reset.
- HTTP `401`/`403` during unauthenticated pairing polling: stop polling, keep
  the current app-generated code visible, and ask the user to enter that same
  code in Home Assistant.
- HTTP `404`: show integration/setup recovery, keep token until user reset.

Only explicit user pairing reset should clear Keychain token state.

When no bearer token exists, the UI shows a blocking pairing sheet instead of
enabling playback. Pairing success is acknowledged with a dedicated success
state before the main runtime UI is released. Demo Mode is the only unpaired
path that unlocks runtime screens; it uses local sample data and must not
contact Home Assistant. Demo Mode is session-only and is cleared on app
restart, explicit pairing reset, or when the user stops Demo Mode from
Settings. Stopping Demo Mode and resetting pairing both return the UI to Now
Playing with the blocking pairing sheet on top.

Fresh installs seed the Home Assistant URL field with
`http://homeassistant.local:8123`. Once pairing succeeds, runtime traffic uses
the `ha_local_url` returned by Home Assistant instead of this editable setup
default.

## Local Client API

The app hosts a small local HTTP API for Home Assistant -> app traffic while
the app is active. User-facing text calls this endpoint `Client API url`.

The Client API url shown during pairing is pinned after successful pairing and
stored locally so Home Assistant does not lose the callback target when the app
refreshes its listener. It changes only when the user resets pairing or the app
installation state is reset.

## Logging

Debug logging is designed for support without leaking secrets. The app logs
user actions and navigation/recovery flows at DEBUG level, including refresh,
transport controls, queue/playlist starts, output changes, Demo Mode entry/
exit, pairing reset, wakeword prompt decisions, and voice/PTT actions.

Home Assistant API calls and local Client API calls log method/path plus HTTP
status code. Logs must not include bearer tokens, pairing codes, Authorization
headers, Spotify/Home Assistant credentials, passwords, or raw request/response
bodies that may contain secrets.

## Local Games

The Games menu is intentionally outside the Home Assistant protocol. Pong,
Asteroids, and Fly run fully inside SwiftUI, store highscores in app-local
preferences, and do not use `DJConnectCore`, bearer tokens, Client API routes,
or HA command/status endpoints. When focused, the game surface consumes arrow
keys and space so keyboard input controls the game instead of app navigation.
This keeps the Apple app aligned with the ESP bonus games while preserving the
integration trust boundary.

## Project Generation

`project.yml` is the XcodeGen source of truth. Regenerate the Xcode project
with:

```sh
xcodegen generate
```

The generated `DJConnectApp.xcodeproj` is committed so the repo opens directly
in Xcode.
