# Development

## Requirements

- Xcode 26 or newer. The latest verified local toolchain is Xcode 26.5
  (`17F42`).
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

Private repository CI runs the same unsigned build checks through
`.github/workflows/ci.yml`. It intentionally does not sign, notarize, or upload
release binaries.

## Pairing The macOS App

1. Open `DJConnectApp.xcodeproj` in Xcode.
2. Select the `DJConnectMac` scheme.
3. Run the app.
4. If this is a fresh install, dismiss the one-time welcome screen.
5. The blocking pairing sheet opens automatically while the app is unpaired.
6. Enter or confirm the Home Assistant base URL, for example
   `http://homeassistant.local:8123`.
7. Copy the app-generated Pairing Code into the Home Assistant `djconnect`
   integration setup/pairing flow.
8. Copy the Client API url into Home Assistant when the HA flow asks for it.
9. Leave the app open. It waits automatically until Home Assistant accepts the
   code and returns a DJConnect bearer token.
10. When the green pairing success state appears, choose `Let's Start!`.

The app polls `POST /api/djconnect/pair`, stores the returned DJConnect bearer
token in Keychain, and validates the pairing by posting to
`/api/djconnect/status`. The pairing request sends the app code as
`pair_code`, `pairing_code`, and `pairing_token` for compatibility with current
Home Assistant integration builds.

For iOS Simulator testing, use the polling flow above. Do not treat simulator
mDNS/Bonjour reachability as authoritative. On real devices and macOS, the app
advertises `_djconnect._tcp` only while it is unpaired/pairable and hosts local
`/api/device/*` endpoints for Home Assistant -> app callbacks while the app is
active/reachable. After pairing, the HTTP API remains available while Bonjour
advertising is disabled until explicit pairing reset.

The pairing sheet also offers Demo Mode. Use it only for local UI work or App
Store review/auditing when a real Home Assistant backend is unavailable. Demo
Mode does not validate HA entities, pairing callbacks, Spotify OAuth, or voice
round trips. Demo Mode is session-only; restarting an unpaired app returns to
the pairing sheet. Stopping Demo Mode from Settings returns to Now Playing with
the pairing sheet on top. Pressing the microphone in Demo Mode plays and shows
a local sample DJ announcement for UI review.

Reset Pairing clears the DJConnect Keychain token, generates a new app code,
and creates a fresh local `device_id` for a new DJConnect app client setup.
It also clears Demo Mode, returns to Now Playing, and reopens the pairing
sheet.

## Debug Logging

Set Log Level to Debug in Settings when validating pairing or backend flows.
Expected debug coverage includes user actions, navigation/recovery flows, Home
Assistant API calls, and local Client API calls. API log lines include HTTP
status codes. Do not add logs that include bearer tokens, pairing codes,
Authorization headers, Spotify/Home Assistant credentials, passwords, or raw
secret-bearing request/response bodies.

The Logs screen is backed by in-memory diagnostics plus a redacted rolling file
in Application Support at `DJConnect/Logs/djconnect.log`. The file survives app
restart/crash, is capped at 500 lines and 128 KB, and is deleted when the user
chooses Logs wissen. Use this file for simulator or real-device debugging when
the UI log buffer has been recreated.

## Monkey Test Mode

Use `--monkey-testing` for non-destructive UI stress tests. In Debug builds the
iOS and macOS app start in local Demo Mode, skip first-run/pairing/crash
blocking sheets, do not start the local Client API, and do not call Home
Assistant. This mode is safe for random taps, tab navigation, game entry/exit,
and basic controls, but it is not a backend or pairing validation path.

The current iOS and macOS monkey-smoke tests can be run as short CI-friendly
checks, or repeated for a longer local soak:

```sh
xcodebuild -quiet -project DJConnectApp.xcodeproj -scheme DJConnectIOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .xcode-derived-monkey -only-testing:DJConnectIOSUITests/DJConnectIOSUITests/testMonkeyModeSafeNavigationSmoke test
xcodebuild -quiet -project DJConnectApp.xcodeproj -scheme DJConnectIOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .xcode-derived-monkey -only-testing:DJConnectIOSUITests/DJConnectIOSUITests/testMonkeyModeSafeNavigationSmoke -test-iterations 22 -test-repetition-relaunch-enabled YES test
xcodebuild -quiet -project DJConnectApp.xcodeproj -scheme DJConnectMac -configuration Debug -destination platform=macOS -derivedDataPath .xcode-derived-mac-monkey -only-testing:DJConnectMacUITests/DJConnectMacUITests/testMonkeyModeSafeNavigationSmoke test
xcodebuild -quiet -project DJConnectApp.xcodeproj -scheme DJConnectMac -configuration Debug -destination platform=macOS -derivedDataPath .xcode-derived-mac-monkey -only-testing:DJConnectMacUITests/DJConnectMacUITests/testMonkeyModeSafeNavigationSmoke -test-iterations 17 -test-repetition-relaunch-enabled YES test
```

Long monkey soaks should only be marked as release verification when they
finish without interruption.

## Permissions During Development

Settings can preflight Microphone and Speech Recognition. Local Network is not
preflighted because Apple does not expose a reliable explicit request/status API
for that permission. Validate Local Network on a real iPhone/iPad or Mac by
pairing against Home Assistant and confirming the system prompt appears during
actual LAN/Bonjour access.

The app intentionally avoids invoking the unstable Speech Recognition system
prompt from the Settings permission button. If Speech Recognition is already
granted, the app accepts it; otherwise it logs that stemactivatie is unavailable
until the user enables speech access in system settings. If permission prompts
behave differently under an Xcode beta, first confirm the callbacks update
SwiftUI state on the main actor and then retest on a physical device outside the
debugger.

## Visual QA

The shared UI should use the DJConnect blue/purple gradient canvas behind Now
Playing, Queue, Playlists, Games, Settings, Logs, and About on iOS, iPadOS, and
macOS. Table/list rows may keep native material backgrounds, but the surrounding
screen should not be plain black.

Games should lazy start behind the tap-to-play overlay, reset to that overlay
after leaving the screen, and consume arrow keys and space while the game
surface is focused. Verify this on macOS and on iPad/iPhone with a hardware
keyboard.

## Test

Swift Package tests:

```sh
swift test
```

Xcode project test scheme:

```sh
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO test
```

iOS UI tests:

```sh
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO test
```

`DJConnectIOSUITests` launches the app with `--uitesting`, isolated
`UserDefaults`, an in-memory token store, and `DJCONNECT_UITEST_HA_URL` pointing
at a mock Home Assistant URL. The current tests verify deterministic launch,
primary navigation, Settings URL seeding, and local Games menu choices. Add a
local mock HA server fixture before asserting full pairing, queue, playlist,
output, and voice flows.

## Repository Rules

- Keep HTTP and protocol code in `DJConnectCore`.
- Keep SwiftUI views in `DJConnectUI`.
- Keep app lifecycle code in `Apps/DJConnectIOS` and `Apps/DJConnectMac`.
- Do not log bearer tokens, Home Assistant tokens, Spotify secrets, or temporary
  TTS/audio URLs.
- Do not clear pairing/token state automatically on backend unavailable,
  version mismatch, authenticated 401/403, or 404.
