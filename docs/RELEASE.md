# Release And Live Validation

This checklist tracks work that cannot be completed by source changes alone.

## Release Checklist

Use this checklist before publishing a new DJConnect App release. The private
repo may publish source releases and unsigned CI builds automatically; signed
App Store/TestFlight and notarized macOS binaries require local Apple signing
credentials.

### One-Time Apple Account Setup

- Join the Apple Developer Program.
- Add the signing Apple ID to Xcode.
- Confirm access to the Apple team that owns DJConnect.
- Register the iOS bundle identifier `nl.pcvantol.djconnect.ios`.
- Register the macOS bundle identifier `nl.pcvantol.djconnect.mac`.
- Create or confirm the App Store Connect app record for iOS/iPadOS.
- Create or confirm the App Store Connect app record for macOS if macOS will
  ship through the Mac App Store.
- Configure app privacy details in App Store Connect for Local Network,
  Microphone, Speech Recognition, diagnostics copied by the user, and no
  automatic log upload.
- Configure export compliance and content rights answers in App Store Connect.
- Create a Developer ID Application certificate for public notarized macOS
  releases outside the Mac App Store.
- Create the notarytool keychain profile once:

```sh
xcrun notarytool store-credentials <notarytool-keychain-profile>
```

- Confirm `gh` can access both private source repo `pcvantol/djconnect-app`
  and public binary repo `pcvantol/djconnect-app-releases`.
- Keep Apple certificates, App Store Connect API keys, and notary credentials
  out of the source repo.

### One-Time Project Setup

- Set `DEVELOPMENT_TEAM` locally for signed builds. Prefer an ignored local
  Xcode config if team IDs differ per developer.
- Confirm iOS signing uses automatic signing for `DJConnectIOS`.
- Confirm macOS signing uses automatic signing for `DJConnectMac`.
- Confirm iOS capabilities and Info.plist strings:
  Local Network, Bonjour services, Microphone, Speech Recognition, Face ID.
- Confirm macOS capabilities and Info.plist strings:
  Local Network, Bonjour services, Microphone, Speech Recognition.
- Confirm app icons, launch screen, welcome screen, About screen, and website
  link match the current DJConnect branding.
- Confirm the HA integration compatibility line is documented:
  app `3.1.x` requires HA integration `3.1.x`.
- Confirm the public macOS release helper works in dry/local mode before the
  first public binary release.

### Every Release: Source Repo

- Choose the next semantic version.
- Update `MARKETING_VERSION` in `project.yml`.
- Update `DJConnectAppModel.protocolVersion`.
- Update version examples in handoff/API/release/architecture docs.
- Consolidate `CHANGELOG.md`: move finished Unreleased entries into the new
  release section and leave a clean Unreleased placeholder.
- Run local verification:

```sh
swift test --no-parallel
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -configuration Debug -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -configuration Debug -destination generic/platform=iOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
```

- Commit and push the release changes to `main`.
- Create the GitHub source release/tag in `pcvantol/djconnect-app`.
- Run release cleanup when the new release is confirmed:

```sh
./cleanup_old_releases.sh --keep 1 --execute
```

### Every Release: iOS/iPadOS App Store Or TestFlight

- Open `DJConnectApp.xcodeproj` in Xcode.
- Select `DJConnectIOS`.
- Confirm bundle identifier `nl.pcvantol.djconnect.ios`.
- Confirm Team, Signing Certificate, and Provisioning Profile are valid.
- Confirm version/build number in Xcode match the intended release.
- Build and run on a physical iPhone.
- Build and run on a physical iPad.
- Validate first-run welcome, pairing sheet, Demo Mode, Settings, About, Queue,
  Playlists, Now Playing, Push-to-Talk, permissions, and logs.
- Validate Local Network permission against a real Home Assistant instance.
- Pair with a matching `pcvantol/djconnect` HA integration.
- Validate playback commands, output switching, queue, playlists, liked songs,
  voice/PTT WAV upload, diagnostics export, version mismatch UI, and pairing
  reset recovery.
- Archive `DJConnectIOS` in Release configuration.
- Upload through Xcode Organizer or Transporter.
- Wait for App Store Connect processing.
- Complete beta/app review compliance prompts.
- Assign TestFlight testers or submit for App Review.
- Smoke-test the TestFlight build on a physical iPhone and iPad.

### Every Release: macOS Public Notarized Binary

- Confirm `DEVELOPMENT_TEAM` is available in the shell or local Xcode config.
- Confirm `NOTARY_PROFILE` exists in the login keychain.
- Confirm Developer ID Application certificate is installed.
- Confirm `gh auth status` can publish to
  `pcvantol/djconnect-app-releases`.
- Run the public macOS release helper:

```sh
PUBLIC_REPO=pcvantol/djconnect-app-releases \
DEVELOPMENT_TEAM=<APPLE_TEAM_ID> \
NOTARY_PROFILE=<notarytool-keychain-profile> \
./Tools/release/release_macos_public.sh --version <X.Y.Z>
```

- Confirm notarization succeeds and the ticket is stapled.
- Confirm Gatekeeper assessment succeeds.
- Download the public zip from `pcvantol/djconnect-app-releases` on a clean Mac
  user account.
- Launch the app, grant Keychain/Local Network/Microphone/Speech permissions as
  needed, pair with Home Assistant, and validate playback/queue/playlists/PTT.

### Every Release: Mac App Store, If Used

- Confirm a Mac App Store app record exists in App Store Connect.
- Confirm sandbox/capability choices match the production distribution plan.
- Archive `DJConnectMac` with Mac App Store signing, not Developer ID export.
- Upload through Xcode Organizer or Transporter.
- Complete App Store Connect compliance and review metadata.
- Smoke-test the processed TestFlight/Mac App Store build on a clean Mac user.

## iOS Signing Requirements

Before an iOS/TestFlight release, make sure these are available:

- An active Apple Developer Program membership.
- Access to the Apple team that owns the app identifier.
- Xcode signed in with that Apple ID.
- Bundle identifier `nl.pcvantol.djconnect.ios` registered in Apple Developer
  Certificates, Identifiers & Profiles.
- App Store Connect app record for `DJConnect` using the same bundle
  identifier.
- A physical iPhone or iPad on the local network for Local Network,
  Microphone, and Speech Recognition permission validation.
- A matching Home Assistant `djconnect` integration in the same `major.minor`
  protocol range as the app.
- A Spotify Premium account configured through the Home Assistant integration.

## First-Run Welcome

The first-launch welcome screen must show DJConnect branding, link setup to
`https://djconnect.pages.dev/start`, and mention that Spotify Premium is
required. It must not ask for Spotify credentials; Spotify OAuth is configured
in Home Assistant.

## Pairing And Demo Mode

When the app is unpaired, the runtime UI must be blocked by the pairing sheet.
The sheet must show:

- DJConnect banner/branding.
- Home Assistant setup context.
- Copyable `Client API url`.
- Copyable app-generated pairing code.
- Pairing progress while Home Assistant calls back.
- A green success state with `Let's Start!` after pairing completes.

Demo Mode is allowed from the pairing sheet for App Store review and UI
inspection without a live Home Assistant backend. It must be clearly local demo
data and must not store a bearer token, create HA entities, or be described as
real playback validation.

## App Permissions

The app declares only the permissions it needs:

- Local Network: required to reach Home Assistant on the LAN and expose the
  local Client API url while the app is active.
- Bonjour services `_home-assistant._tcp.` and `_djconnect._tcp.`: required for
  local HA discovery and HA -> app callbacks.
- Microphone: required for push-to-talk WAV uploads.
- Speech Recognition: required for the foreground wake phrase.

Settings includes a Permissions section where users can request Microphone and
Speech Recognition before using voice or wakeword flows. Local Network does not
have a reliable Apple preflight status API, so the app documents why it is
needed and still relies on the system prompt when local network access is first
used.

## Crash Diagnostics

The app does not upload crash logs automatically and does not embed GitHub
credentials. If the previous session appears to have ended uncleanly, the next
launch shows a crash report prompt. The user can copy redacted diagnostics or
open a prefilled GitHub issue in `pcvantol/djconnect` and submit it manually.

## iOS Signing Steps

1. Set `DEVELOPMENT_TEAM` for local release builds. Prefer an ignored local
   Xcode config if multiple developers use different teams; otherwise set it in
   `project.yml`.
2. Run `xcodegen generate` after changing signing settings.
3. Open `DJConnectApp.xcodeproj` in Xcode.
4. Select the `DJConnectIOS` target.
5. Confirm Signing & Capabilities uses automatic signing and the expected team.
6. Confirm bundle identifier `nl.pcvantol.djconnect.ios`.
7. Run the app on a physical iPhone/iPad and accept Local Network, Microphone,
   and Speech Recognition prompts.
8. Pair against a real Home Assistant `djconnect` setup and validate playback,
   queue, playlists, output switching, and voice/PTT.
9. Select Any iOS Device or a physical device destination.
10. Archive with Product > Archive in Release configuration.
11. Upload through Xcode Organizer or Transporter to TestFlight.
12. In App Store Connect, wait for processing, complete beta compliance, and
    assign internal or external testers.

## macOS Signing

- Set `DEVELOPMENT_TEAM` in `project.yml` or an ignored local Xcode config.
- Regenerate `DJConnectApp.xcodeproj` with `xcodegen generate`.
- Confirm bundle identifier `nl.pcvantol.djconnect.mac`.
- Archive with automatic signing enabled for the selected Apple team.

## Private CI

The private source repo uses GitHub Actions only for deterministic checks:

- `swift test --no-parallel`
- unsigned macOS Debug build
- unsigned iOS Debug generic build

CI must not contain Developer ID certificates, notary credentials, App Store
Connect keys, or public binary upload tokens until the signing pipeline is
explicitly hardened.

## TestFlight

- Archive the `DJConnectIOS` scheme in Release configuration.
- Upload through Xcode Organizer or `xcrun altool`/Transporter.
- Verify Local Network and Microphone permission prompts on a physical iPhone.
- Run pairing against a real Home Assistant `djconnect` setup before inviting
  external testers.

## Current Local Verification

For release `3.1.8`, local verification was completed with:

```sh
swift test --no-parallel
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -configuration Debug -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -configuration Debug -destination generic/platform=iOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
```

The Xcode toolchain was Xcode 26.5 (`17F42`). These checks do not replace
signed archive validation, TestFlight processing, notarization, or physical
device permission testing.

## macOS Notarization

- Archive the `DJConnectMac` scheme in Release configuration.
- Export a Developer ID signed app or disk image.
- Submit for notarization with `xcrun notarytool`.
- Staple the accepted ticket and verify Gatekeeper launch on a clean Mac user.

The local helper script packages and uploads public macOS releases:

```sh
PUBLIC_REPO=pcvantol/djconnect-app-releases \
DEVELOPMENT_TEAM=<APPLE_TEAM_ID> \
NOTARY_PROFILE=<notarytool-keychain-profile> \
./Tools/release/release_macos_public.sh --version 3.1.8
```

Create the notary profile once with:

```sh
xcrun notarytool store-credentials <notarytool-keychain-profile>
```

The script performs a clean archive, Developer ID export, notarization, staple,
Gatekeeper assessment, zip/checksum creation, and GitHub release upload to the
public `pcvantol/djconnect-app-releases` repository. iOS binaries are not
published this way; use TestFlight/App Store for iOS distribution.

## Release Cleanup

After a successful release, old semantic-version GitHub releases and tags can
be cleaned up with the helper script. It is dry-run by default:

```sh
./cleanup_old_releases.sh --keep 1
```

When the dry-run list is correct, execute the cleanup:

```sh
./cleanup_old_releases.sh --keep 1 --execute
```

The script deletes matching old `vX.Y.Z` GitHub releases, remote tags, and
local tags. It keeps the newest `--keep` versions and only deletes when
`--execute` is passed.

## Live HA Validation

Use a Home Assistant instance with the matching `djconnect` integration.

- Pair from the app-generated code and confirm HA creates the app device.
- Confirm the Client API url shown during pairing remains stable after pairing
  and after app restart until explicit pairing reset.
- Confirm Demo Mode can be entered from the unpaired pairing sheet and exited
  from Settings without creating HA state.
- Confirm the app accepts only matching `major.minor` HA integration versions
  and disables runtime controls with a clear update message on mismatch.
- Confirm HA entities/status sync for paired, stale, backend unavailable, and
  update-required states.
- Load backend devices through the `devices` command and switch output.
- Load queue through the `queue` command.
- Load playlists through the `playlists` command.
- Start a playlist through `start_playlist`.
- Start liked songs through `start_liked_proxy`.
- Record Push-to-Talk and verify WAV upload to `/api/djconnect/voice`.
- Copy diagnostics export and confirm no bearer token, pairing code, or query
  token appears.

## UI Test Automation

The source tree can only provide deterministic unit tests without a HA fixture.
For end-to-end UI tests, provide either:

- a real HA URL plus test integration credentials on the local network; or
- a recorded/mock HA server that implements `/api/djconnect/pair`,
  `/api/djconnect/status`, `/api/djconnect/command`, and
  `/api/djconnect/voice`.

The `DJConnectIOSUITests` target now launches the iOS app in deterministic
`--uitesting` mode with isolated defaults and a mock Home Assistant URL. Extend
that target with a real mock server fixture for pairing, output selection,
queue, playlist/liked proxy, voice upload, stale auth, and backend unavailable
states.
