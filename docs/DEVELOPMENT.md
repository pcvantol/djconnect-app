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
7. In Home Assistant, start the DJConnect app setup flow and choose macOS.
8. Enter the local Home Assistant URL and the 6-digit code shown by Home
   Assistant in the app, then choose the pairing action.
9. Finish the setup flow in Home Assistant. The app waits after the initial
   `POST /api/djconnect/v1/pair` until authenticated status succeeds.
10. When the green pairing success state appears, choose `Let's Start!`.

The app posts once to `POST /api/djconnect/v1/pair` from the Apple client to Home
Assistant, stores the returned DJConnect bearer token in app-private storage,
and sends the Home Assistant code as `pair_code`, `pairing_code`, and
`pairing_token` for compatibility with current Home Assistant integration
builds.

Pairing is local-first. The URL field validates real URL syntax and accepts
local `http` Home Assistant hosts such as `homeassistant.local`, LAN IP
addresses, or `localhost`. For development, `https://*.ngrok-free.dev` is
whitelisted so a tunneled Home Assistant dev environment can be paired. Other
remote HTTPS URLs are rejected for first pairing and should be used only after
Home Assistant returns `ha_remote_url` for runtime fallback.

If Home Assistant returns `error:"client_type_mismatch"` during pairing, the
client keeps the entered URL and 6-digit code, stops the current attempt, and
shows a platform-specific instruction to choose the matching DJConnect setup
flow in Home Assistant. For macOS use `client_type:"macos"`, for iPhone/iPad
use `client_type:"ios"`, and for Apple Watch through the iPhone proxy use
`client_type:"watchos"`.

For iOS Simulator testing, use the pairing flow above. Treat direct HTTP reachability to the configured Home Assistant URL as authoritative; Apple clients do not advertise a pairable service or host callback endpoints.

For Apple Watch pairing, choose Apple Watch in the Home Assistant DJConnect
setup flow and scan/open the generated `djconnect://pair?...client_type=watchos`
payload on the paired iPhone. The Watch does not show Home Assistant URL or
pair-code entry fields and the iPhone proxy pairing screen does not show Demo
Mode. The iPhone forwards the validated payload to the Watch and may proxy the
HTTP request, but the payload identity remains
`client_type: "watchos"` with a `djconnect-watchos-*` device ID.

The pairing sheet also offers Demo Mode. Use it only for local UI work or App
Store review/auditing when a real Home Assistant backend is unavailable. Demo
Mode does not validate HA entities, legacy pairing callbacks, Spotify OAuth, or voice
round trips. Demo Mode is session-only; restarting an unpaired app returns to
the pairing sheet. Stopping Demo Mode from Settings returns to Now Playing with
the pairing sheet on top. Pressing the microphone in Demo Mode plays and shows
a local sample DJ announcement for UI review.

Reset Pairing clears the locally stored DJConnect token and creates a fresh
local `device_id` for a new DJConnect app client setup. It also clears Demo
Mode, returns to Now Playing, and reopens the pairing sheet.

## Debug Logging

Set Log Level to Debug in Settings when validating pairing or backend flows.
Expected debug coverage includes user actions, navigation/recovery flows, Home
Assistant API calls, and iPhone-mediated Watch proxy actions. API log lines
include HTTP status codes. Do not add logs that include bearer tokens, pairing codes,
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
blocking sheets, do not call Home
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

## Automated Tests

Use `build-for-testing` as the fast sanity check after changing shared models,
token storage, or UI test sources:

```sh
xcodebuild -quiet -project DJConnectApp.xcodeproj -scheme DJConnectMac -configuration Debug -destination platform=macOS -derivedDataPath .xcode-derived-mac CODE_SIGNING_ALLOWED=NO build-for-testing
```

`DJConnectCoreTests` cover request/response contracts, diagnostics redaction,
app-private token storage, reset-pairing state, version mismatch handling,
HTML/backend error suppression, Ask DJ Demo Mode behavior, and local app-model
state transitions. Keep these tests free of live Home Assistant dependencies.

The iOS and macOS UI test targets cover deterministic navigation smoke checks
and Settings affordances, including the `App opnieuw koppelen` / `Pair App
Again` action. The iOS target also covers first-run dismissal, manual pairing
form wiring, Demo Mode entry/exit, compact permission rows, jump URL routing,
local Games menu choices, hardware-keyboard game input, safe monkey navigation,
and screenshot capture cleanup. UI tests should use `--uitesting` or
`--monkey-testing`, isolated `UserDefaults`, and local/demo data unless a
dedicated mock Home Assistant server fixture is introduced.

If `xcodebuild test` hangs or reports a UI runner bootstrap/finalization issue
locally, rerun the affected target with `build-for-testing` to distinguish
compile/test-source failures from Xcode runner infrastructure failures. Do not
mark a release as fully tested until a real `test` invocation completes on a
healthy local Xcode/simulator setup.

## Localization

Apple client user-facing text must be available for English, Dutch, German,
French, and Spanish. Keep protocol values, endpoint paths, JSON keys, and
`client_type` values (`ios`, `macos`, `watchos`) untranslated.

When adding or changing shared localized text, update every locale in
`Sources/DJConnectCore/Resources/Localization/{en,nl,de,fr,es}.lproj/Localizable.strings`
and prefer format placeholders over concatenating translated fragments. Then
run:

```sh
python3 scripts/validate_localizations.py
```

The validator fails on missing keys, extra keys, duplicate keys, invalid
`.strings` syntax, or mismatched printf placeholders.

## Permissions During Development

Settings can preflight Microphone and Speech Recognition. Local Network is not
preflighted because Apple does not expose a reliable explicit request/status API
for that permission. Validate Local Network on a real iPhone/iPad or Mac by
pairing against Home Assistant and confirming the system prompt appears during
actual LAN access.

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

Local iOS/iPadOS simulator matrix:

```sh
Tools/test_ios_simulator_matrix.sh
Tools/test_ios_simulator_matrix.sh --all-runtimes
Tools/test_ios_simulator_matrix.sh --full-ui
Tools/test_ios_simulator_matrix.sh --list
```

The matrix creates temporary simulators, runs the deterministic iOS UI smoke
test by default, and deletes those simulators after the run. It covers compact
iPhone, standard iPhone, large iPhone, and iPad form factors. By default it
tests the latest installed stable iOS simulator runtime for each form factor and
also runs the standard iPhone against the oldest installed stable runtime at or
above the app deployment target. Install older iOS runtimes in Xcode when you
want local coverage close to the minimum supported iOS/iPadOS version. Use
`--all-runtimes` to run every installed supported runtime, `--full-ui` to run
the complete iOS UI test target, and `--include-beta-runtimes` when validating
against Xcode beta runtimes.

`DJConnectIOSUITests` launches the app with `--uitesting`, isolated
`UserDefaults`, an in-memory token store, and `DJCONNECT_UITEST_HA_URL` pointing
at a mock Home Assistant URL. The current tests verify deterministic launch,
first-run dismissal, manual pairing form wiring, Demo Mode entry/exit, compact
permission rows, primary navigation, jump URL routing, Settings URL seeding,
local Games menu choices, hardware-keyboard game input, safe monkey navigation,
screenshot capture cleanup, and recorded runtime fixture flows for successful
pairing, paired status loading, stale auth, backend unavailable, version
mismatch, queue, playlist, output, Ask DJ, and voice unavailable states.

## Home Assistant Transport Check

For a manual regression check, pair iOS/macOS through the local
`/api/djconnect/v1/pair` flow, then validate that status and command calls use the
stored `ha_local_url`, fall back to `ha_remote_url` when local access fails and
remote is supported, and report offline when neither URL works.

For Apple Watch, keep DJConnect open on the paired iPhone. The Watch should show
the iPhone companion status and send pairing, status, Ask DJ history, playback
actions, voice/PTT, and push registration through WatchConnectivity. The Watch
must not expose inbound callback/discovery routes or store/use `ha_remote_url`
directly.

Music DNA on Apple Watch is also iPhone-mediated. Validate that opening either
Ask DJ or Music DNA can show the same initial consent sheet when the backend
reports `enabled:false`, and that Watch Settings can turn Music DNA off and on
again. Watch Music DNA profile/settings/clear requests must preserve the Watch
identity (`device_id` plus `client_type:"watchos"`). Turning Music DNA off
should be confirmed in the UI because Home Assistant clears learned Music DNA
and stops future profile buildup. Verify Settings explains the current state:
when disabled, no profile is being built and the learned profile is already
cleared. The clear-profile button should only be visible while Music DNA is
enabled.

`Connection reset by peer` after TCP connect usually means macOS firewall or
third-party security software, such as ESET, Little Snitch, or LuLu, is blocking
inbound local HTTP. Do not add automatic firewall exclusions in the app; keep the
macOS network server entitlement, log the inbound request details, and document
that users should allow inbound local-network connections for DJConnect. Prefer
an application-based allow rule because Home Assistant LAN access can be blocked when the
pairing server restarts.

## Repository Rules

- Keep HTTP and protocol code in `DJConnectCore`.
- Keep SwiftUI views in `DJConnectUI`.
- Keep app lifecycle code in `Apps/DJConnectIOS` and `Apps/DJConnectMac`.
- Do not log bearer tokens, Home Assistant tokens, Spotify secrets, or temporary
  TTS/audio URLs.
- Do not clear pairing/token state automatically on backend unavailable,
  version mismatch, authenticated 401/403, or 404.
