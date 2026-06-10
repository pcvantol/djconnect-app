# Development

## Requirements

- Xcode 26 or newer.
- Swift 6.
- XcodeGen, available as `xcodegen`.

## Generate Xcode Project

`project.yml` is the source of truth for the Xcode project.

```sh
xcodegen generate
```

Open:

```text
DJConnectApp.xcodeproj
```

## Build

macOS:

```sh
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
```

iOS:

```sh
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -destination generic/platform=iOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
```

The CLI build disables signing for local verification. Configure
`DEVELOPMENT_TEAM` in Xcode or `project.yml` before running on devices.

## Pairing The macOS App

1. Open `DJConnectApp.xcodeproj` in Xcode.
2. Select the `DJConnectMac` scheme.
3. Run the app.
4. Open Settings.
5. Enter the Home Assistant base URL, for example
   `http://homeassistant.local:8123`.
6. Copy the app-generated Pairing Code into the Home Assistant `djconnect`
   integration setup/pairing flow.
7. Leave the app open. It waits automatically until Home Assistant accepts the
   code and returns a DJConnect bearer token.

The app polls `POST /api/djconnect/pair`, stores the returned DJConnect bearer
token in Keychain, and validates the pairing by posting to
`/api/djconnect/status`. The pairing request sends the app code as
`pair_code`, `pairing_code`, and `pairing_token` for compatibility with current
Home Assistant integration builds.

For iOS Simulator testing, use the polling flow above. Do not treat simulator
mDNS/Bonjour reachability as authoritative. On real devices and macOS, the app
also advertises `_djconnect._tcp` and hosts local `/api/device/*` endpoints for
Home Assistant -> app callbacks while the app is active/reachable.

Reset Pairing clears the DJConnect Keychain token, generates a new app code,
and creates a fresh local `device_id` for a new DJConnect app client setup.

## Test

Swift Package tests:

```sh
swift test
```

Xcode project test scheme:

```sh
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO test
```

## Repository Rules

- Keep HTTP and protocol code in `DJConnectCore`.
- Keep SwiftUI views in `DJConnectUI`.
- Keep app lifecycle code in `Apps/DJConnectIOS` and `Apps/DJConnectMac`.
- Do not log bearer tokens, Home Assistant tokens, Spotify secrets, or temporary
  TTS/audio URLs.
- Do not clear pairing/token state automatically on backend unavailable,
  version mismatch, authenticated 401/403, or 404.
