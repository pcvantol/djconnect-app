# Release And Live Validation

This checklist tracks work that cannot be completed by source changes alone.

## Release Checklist

Use this checklist before publishing a new DJConnect App release. The private
repo may publish source releases and unsigned CI builds automatically; signed
App Store/TestFlight and notarized macOS binaries require local Apple signing
credentials.

### One-Time Apple Account Setup

- Join or renew the Apple Developer Program. Current status for this repo:
  renewed; confirm the Apple portal and Xcode both show the membership as
  active before signing or uploading archives.
- Add the signing Apple ID to Xcode.
- Confirm access to the Apple team that owns DJConnect.
- Register the iOS bundle identifier `dev.djconnect.ios`.
- Register the macOS bundle identifier `dev.djconnect.mac`.
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

### Renewed Developer Account Follow-Up

After renewing the Apple Developer Program membership:

- Sign out and back in under Xcode > Settings > Accounts if Xcode still reports
  an expired membership.
- Re-open Certificates, Identifiers & Profiles and confirm the expected Team ID
  is visible.
- Refresh automatic signing for `DJConnectIOS` and `DJConnectMac`.
- Recreate or download missing certificates and provisioning profiles if Xcode
  marks them invalid after renewal.
- Confirm Developer ID Application signing is available before publishing a
  public macOS binary.
- Re-run or create the notarytool keychain profile if notarization reports
  invalid team, agreement, or credential errors.
- In App Store Connect, accept any updated agreements in Business before
  uploading TestFlight or Mac App Store builds.

### One-Time Project Setup

- Set `DEVELOPMENT_TEAM` locally for signed builds. Prefer an ignored local
  Xcode config if team IDs differ per developer.
- Confirm iOS signing uses automatic signing for `DJConnectIOS`.
- Confirm macOS signing uses automatic signing for `DJConnectMac`.
- Confirm iOS capabilities and Info.plist strings:
  Local Network, Bonjour services, Microphone, Speech Recognition.
- Confirm macOS capabilities and Info.plist strings:
  Local Network, Bonjour services, Microphone, Speech Recognition.
- Confirm app icons, launch screen, welcome screen, About screen, and website
  link match the current DJConnect branding.
- Confirm the HA integration compatibility line is documented:
  app `3.2.x` requires HA integration `3.2.x`.
- Confirm the public macOS release helper works in dry/local mode before the
  first public binary release.

### Every Release: Source Repo

- Choose the next semantic version.
- Update `MARKETING_VERSION` in `project.yml`.
- Update `DJConnectAppModel.protocolVersion`.
- Update version examples in handoff/API/release/architecture docs.
- Confirm handoff, README, architecture, development, TODO, and issues docs
  reflect new runtime, logging, release, and pairing behavior.
- For cross-repo contract changes, update the canonical
  `pcvantol/djconnect/SYNC_PROMPTS.md`. For product roadmap changes, update
  `pcvantol/djconnect/PRODUCT_ROADMAP.md`. If either change originates here,
  create a follow-up change/commit in `pcvantol/djconnect`. Do not keep local
  `SYNC_PROMPTS.md` or `PRODUCT_ROADMAP.md` copies in this repo.
- Run the standard release script so third-party libraries, frameworks and
  installed release helper tools are updated/upgraded before build artifacts
  are compiled.
- Update `docs/THIRD_PARTY_NOTICES.md` and
  `docs/TECHNICAL_DESIGN_DECISIONS.md` when architecture, code patterns,
  platform versions, tooling, dependencies, or license/source metadata changed.
- Update `CHAT_BOOTSTRAP.md` so fresh Codex chats start with current release,
  handoff, workflow, and repository-status instructions.
- Add/update `docs/release-notes/nl/vX.Y.Z.md` for Dutch What's New content
  before publishing; otherwise the public workflow falls back to English text.
- Review repository hygiene docs (`CONTRIBUTING.md`, `SECURITY.md`,
  `CODE_OF_CONDUCT.md`, `docs/BUILD_RELEASE_HYGIENE.md`, `docs/TODO.md`, and
  `docs/TECHNICAL_DESIGN_DECISIONS.md`) whenever contribution, security,
  signing, CI, TestFlight, or release publication behavior changes.
- Confirm AI-assisted workflow material contains no secrets, private URLs,
  private data, raw diagnostics, sensitive screenshots, or proprietary
  third-party content.
- Consolidate `CHANGELOG.md`: move finished Unreleased entries into the new
  release section and leave a clean Unreleased placeholder.
- Run local verification:

```sh
swift test --no-parallel
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -configuration Debug -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -configuration Debug -destination generic/platform=iOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectWatch -configuration Debug -destination generic/platform=watchOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
git diff --check
```

- Commit and push the release changes to `main`.
- Create the GitHub source release/tag in `pcvantol/djconnect-app`.
- Confirm the `Public unsigned release` GitHub Actions workflow succeeds. It
  publishes unsigned macOS and iOS diagnostic zips plus checksums to
  `pcvantol/djconnect-app-releases`.
- The workflow runs `swift test --no-parallel` before building artifacts or
  publishing static release notes. Keep tests locale-independent or explicitly
  set/test the intended app language before asserting localized strings, so a
  runner's default language cannot block release-note publication.
- Release cleanup runs automatically from `release.sh` by default. It keeps the
  newest source release/tag and removes older matching entries. The public
  unsigned release workflow also removes older GitHub Actions runs after a
  successful publication so the Actions page only keeps the current run. To run
  the same release/tag cleanup manually:

```sh
./cleanup_old_releases.sh --keep 1 --keep-workflow-runs 1 --execute
```

### Every Release: iOS/iPadOS App Store Or TestFlight

- Open `DJConnectApp.xcodeproj` in Xcode.
- Select `DJConnectIOS`.
- Confirm bundle identifier `dev.djconnect.ios`.
- Confirm Team, Signing Certificate, and Provisioning Profile are valid.
- Confirm version/build number in Xcode match the intended release.
- Build and run on a physical iPhone.
- Build and run on a physical iPad.
- Validate first-run welcome, pairing sheet, Demo Mode, Settings, About, Queue,
  Playlists, Now Playing, Push-to-Talk, permissions, and logs.
- Validate pairing guidance uses a local Home Assistant LAN URL and does not
  suggest remote pairing. Confirm remote fallback is only shown/used after a
  successful local pairing response provides `ha_remote_url`.
- Validate the runtime status surface shows Home Assistant route
  (`local`/`remote`/`offline`), music backend availability, and playback state.
- Validate the DJConnect blue/purple gradient canvas is visible behind every
  primary iPhone/iPad screen and that permission rows stay compact.
- Validate Demo Mode microphone playback shows and speaks the local sample DJ
  announcement.
- Validate Games lazy start behind the tap-to-play overlay, reset to that
  overlay after leaving the Games screen, and arrow keys/space control the
  focused game without switching tabs/pages when a hardware keyboard is
  connected.
- Run a short Debug `--monkey-testing` session in an iPhone simulator to confirm
  non-destructive navigation/tapping does not call Home Assistant, reset
  pairing, or mutate locally stored DJConnect tokens.
- Validate Local Network permission against a real Home Assistant instance.
- Pair with a matching `pcvantol/djconnect` HA integration.
- Validate playback commands, output switching, queue, playlists, liked songs,
  voice/PTT WAV upload, diagnostics export, version mismatch UI, and pairing
  reset recovery.
- Validate diagnostics export redacts bearer tokens, pairing codes,
  Authorization headers, secret-bearing URLs, and private HA details while
  retaining bundle, locale, permission, route, backend, output, and playback
  readiness fields.
- Validate `App opnieuw koppelen` clears the local token, generates a fresh app
  code, reopens the pairing sheet, and makes the app discoverable/pairable
  again.
- Validate Ask DJ route/proxy/backend failures show only localized user-facing
  messages and never raw HTML or response bodies.
- Archive `DJConnectIOS` in Release configuration.
- Upload through Xcode Organizer or Transporter.
- Wait for App Store Connect processing.
- Complete beta/app review compliance prompts.
- Assign TestFlight testers or submit for App Review.
- Smoke-test the TestFlight build on a physical iPhone and iPad.
- For App Review notes, mention that Demo Mode is available from the unpaired
  pairing sheet for UI inspection without a private Home Assistant instance,
  while full playback/voice validation requires the matching Home Assistant
  DJConnect integration on the same LAN for first pairing.

### Every Release: macOS Public Notarized Binary

- This release path is local-only: GitHub Actions should run tests and unsigned
  builds, while the signed archive, notarization, and upload to
  `pcvantol/djconnect-app-releases` happen from a trusted Mac with Apple
  certificates installed.
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
- Launch the app, grant Local Network/Microphone/Speech permissions as
  needed, pair with Home Assistant, and validate playback/queue/playlists/PTT.

## Public Unsigned CI Artifacts

The private source repository contains `.github/workflows/public-unsigned-release.yml`.
It runs on `vX.Y.Z` tags and through manual `workflow_dispatch`.

The workflow:

- runs the Swift unit test suite;
- builds unsigned `DJConnectMac` and `DJConnectIOS` Debug artifacts with
  `CODE_SIGNING_ALLOWED=NO`;
- publishes `macos/vX.Y.Z` in `pcvantol/djconnect-app-releases` with
  `DJConnect-macOS-X.Y.Z-unsigned.zip` and a macOS checksum file;
- publishes `ios/vX.Y.Z` in `pcvantol/djconnect-app-releases` with
  `DJConnect-iOS-X.Y.Z-unsigned.zip` and an iOS checksum file;
- uses the matching release section from `CHANGELOG.md` as the English public
  release notes and optionally `docs/release-notes/nl/vX.Y.Z.md` or
  `CHANGELOG.nl.md` as the Dutch release notes;
- publishes static `.md` and `.json` release-note files into
  `pcvantol/djconnect-website` at
  `wwwroot/release-notes/{ios|macos}/{en|nl}/vX.Y.Z.{md,json}` plus a legacy
  English fallback at `wwwroot/release-notes/{ios|macos}/vX.Y.Z.{md,json}`;
- removes older platform-specific public releases and tags after successful
  publication, keeping the newest iOS and newest macOS public release online.

Required private repository secret:

```text
PUBLIC_RELEASES_TOKEN
WEBSITE_RELEASE_NOTES_TOKEN
```

The token must be able to create releases and upload assets in
`pcvantol/djconnect-app-releases`. The default `GITHUB_TOKEN` for
`pcvantol/djconnect-app` cannot write to a different repository.
`WEBSITE_RELEASE_NOTES_TOKEN` must be able to push to
`pcvantol/djconnect-website`; the website repo deploys those static files to
Cloudflare Pages for `djconnect.dev`.

Unsigned artifacts are for diagnostics, CI validation, internal validation, and
release-note hosting. The public release workflow publishes unsigned iOS and
macOS artifacts, but they are not a replacement for TestFlight/App Store iOS
distribution or Developer ID notarized macOS distribution.

The public release repository should keep iOS and macOS releases separated by
tag namespace. Use `ios/vX.Y.Z` for iOS release notes/assets and
`macos/vX.Y.Z` for macOS release notes/assets, so each app target loads the
matching What's New content at startup.

Do not publish a shared `vX.Y.Z` public app release for current builds. Shared
tags can make one platform show the other platform's What's New content.

If the public workflow fails before `Publish static release notes to
djconnect.dev`, the app will show the fallback "release notes could not be
loaded" message for that version. Fix the blocking workflow issue and rerun the
workflow for the version, or publish the missing static files directly to
`pcvantol/djconnect-website` using the same paths and JSON shape listed below.
Then verify the live URLs on `https://djconnect.dev` before considering What's
New publication complete.

## In-App What's New Notes

The app stores the last seen version in app-local preferences. On a later
startup, if the running app version differs, it opens a one-time `Wat is er nieuw`
/ `What's New` sheet.

Release notes are fetched at runtime from static `djconnect.dev` files:

```text
https://djconnect.dev/release-notes/ios/nl/vX.Y.Z.json
https://djconnect.dev/release-notes/macos/nl/vX.Y.Z.json
https://djconnect.dev/release-notes/ios/en/vX.Y.Z.json
https://djconnect.dev/release-notes/macos/en/vX.Y.Z.json
https://djconnect.dev/release-notes/ios/vX.Y.Z.json
https://djconnect.dev/release-notes/macos/vX.Y.Z.json
```

Current builds first read the matching platform and language-specific static
file, then the legacy English platform-specific static file. The GitHub release
metadata API is retained only as a final fallback:

```text
https://api.github.com/repos/pcvantol/djconnect-app-releases/releases/tags/ios%2FvX.Y.Z
https://api.github.com/repos/pcvantol/djconnect-app-releases/releases/tags/macos%2FvX.Y.Z
```

Only public release metadata is fetched. No DJConnect device token, Home
Assistant URL, Spotify token, diagnostics, or user data is sent to GitHub.

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
- Bundle identifier `dev.djconnect.ios` registered in Apple Developer
  Certificates, Identifiers & Profiles.
- App Store Connect app record for `DJConnect` using the same bundle
  identifier.
- A physical iPhone or iPad on the local network for Local Network,
  Microphone, and Speech Recognition permission validation.
- A matching Home Assistant `djconnect` integration in the same `major.minor`
  protocol range as the app.
- A supported music backend configured through the Home Assistant integration.

## App Store Submission Metadata

Use the same core copy for iOS/iPadOS App Store and Mac App Store unless the
platform-specific review notes need to mention TestFlight, notarization, or
Mac-only behavior.

### Required Store Listing Fields

App name:

```text
DJConnect
```

Subtitle:

```text
Muziekbediening met karakter
```

Short description / promotional text:

```text
Bedien je muziek via Home Assistant en praat met Ask DJ voor persoonlijke muziekvragen en verzoeken.
```

Full description:

```text
DJConnect is je muziekbediening met karakter voor Home Assistant. Koppel de app met
de DJConnect integratie, kies je uitvoerapparaat, bedien je muziek, bekijk de
wachtrij en afspeellijsten, en gebruik push-to-talk voor persoonlijke DJ
aankondigingen.

DJConnect bewaart geen muziekbackend- of Home Assistant-wachtwoorden in de app.
Een Home Assistant DJConnect-integratie met ondersteunde muziekbackend is
vereist voor echte playback. Demo modus is beschikbaar zodat je de app-interface
kunt bekijken zonder actieve Home Assistant backend.
```

Keywords:

```text
Home Assistant,Spotify,muziek,DJ,remote,voice,smart home
```

Support URL:

```text
https://djconnect.dev
```

Marketing URL:

```text
https://djconnect.dev
```

Privacy Policy URL:

```text
https://djconnect.dev/privacy
```

Copyright:

```text
Copyright © 2026 Peter van Tol
```

Category:

```text
Music
```

Secondary category:

```text
Utilities
```

Age rating:

```text
4+
```

### Review Notes

```text
DJConnect requires the DJConnect Home Assistant integration and a supported
Home Assistant music backend for live playback. For review, open the app and choose Demo
modus starten from the pairing screen. Demo Mode shows local sample playback,
queue, playlists, games, and a sample DJ announcement without requiring access
to a private Home Assistant instance.

Live setup instructions are available at https://djconnect.dev/start.
The app requests Local Network access to reach Home Assistant for local
pairing. Microphone is used for push-to-talk voice requests. Speech Recognition
is used only for optional foreground Stemactivatie.
```

### App Privacy Labels

Data linked to the user:

```text
None collected by the app developer.
```

Data not linked to the user:

```text
Diagnostics: only when the user explicitly copies logs or opens a GitHub issue.
Device ID: a local DJConnect install identifier used for Home Assistant pairing.
```

Data used for tracking:

```text
None.
```

Permissions and purpose strings:

```text
Local Network: used to connect to Home Assistant on your local network for
local pairing and runtime access.

Microphone: used to record push-to-talk DJ requests.

Speech Recognition: used for optional foreground Stemactivatie.

DJConnect device token: stored locally in app-private storage and cleared when
the user chooses to pair the app again.
```

### macOS-Specific Notes

For Mac App Store submission, use the same product copy. For public Developer
ID distribution outside the Mac App Store, publish the notarized zip and
checksum to `pcvantol/djconnect-app-releases` and link the public release from
the website/download page.

## First-Run Welcome

The first-launch welcome screen must show DJConnect branding, link setup to
`https://djconnect.dev/start`, and mention that playback is configured through
Home Assistant. It must not ask for Spotify, Music Assistant, or other backend
credentials; backend credentials are configured in Home Assistant.

## Pairing And Demo Mode

When the app is unpaired, the runtime UI must be blocked by the pairing sheet.
The sheet must show:

- DJConnect banner/branding.
- Home Assistant setup context.
- Local Home Assistant URL plus pairing code/QR entry on iOS/macOS, or Watch
  pairing code plus iPhone companion status on watchOS.
- Pairing progress while the app or iPhone companion polls Home Assistant.
- A green success state with `Let's Start!` after pairing completes.

Demo Mode is allowed from the pairing sheet for App Store review and UI
inspection without a live Home Assistant backend. It must be clearly local demo
data and must not store a bearer token, create HA entities, or be described as
real playback validation.

## App Permissions

The app declares only the permissions it needs:

- Local Network: required to reach Home Assistant on the LAN and expose the
  local pairing and runtime HA connection.
- Bonjour service `_home-assistant._tcp.`: used for local HA discovery on
  iOS/macOS. Apple clients do not advertise `_djconnect._tcp`.
- Microphone: required for push-to-talk WAV uploads.
- Speech Recognition: required for the foreground wake phrase.

Settings includes a Permissions section where users can request Microphone and
Speech Recognition before using voice or wakeword flows. Local Network does not
have a reliable Apple preflight status API, so the app documents why it is
needed in release documentation and still relies on the system prompt when
local network access is first used. Do not ship a fake Local Network request
button.

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
6. Confirm bundle identifier `dev.djconnect.ios`.
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
- Confirm bundle identifier `dev.djconnect.mac`.
- Archive with automatic signing enabled for the selected Apple team.

## Private CI

The private source repo uses GitHub Actions only for deterministic checks:

- `swift test --no-parallel`
- unsigned macOS Debug build
- unsigned iOS Debug generic build

On `main` pushes and manual CI runs, the CI workflow also removes older
completed GitHub Actions runs after the deterministic checks finish, keeping the
newest 2 completed runs per workflow. Pull requests never run this cleanup.

The `TestFlight beta` workflow is intentionally manual-only. It has no push or
tag trigger and must never be used without explicit maintainer approval, an
explicit semantic version, and an explicit matching source tag. To run it,
choose **Run workflow** and provide:

- `version`: for example `3.2.0`;
- `tag`: the exact matching source tag, for example `v3.2.0`;
- `confirm_upload`: exactly `UPLOAD_TESTFLIGHT`.

The workflow uses the protected `testflight-beta` GitHub Environment, checks out
the requested tag, confirms `project.yml` `MARKETING_VERSION` matches the
requested version, runs Swift tests, archives `DJConnectIOS`, exports an App
Store Connect IPA, and uploads it to TestFlight. It does not submit for App
Review, assign testers, promote a build, or retain the signed IPA as an
artifact. The export sets `testFlightInternalTestingOnly` so CI-created beta
builds cannot be used for external TestFlight or App Store distribution.

Required GitHub Actions secrets for TestFlight beta upload:

```text
APPLE_TEAM_ID
IOS_DISTRIBUTION_CERTIFICATE_BASE64
IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
IOS_APP_STORE_PROFILE_BASE64
IOS_APP_STORE_PROFILE_NAME
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_API_ISSUER_ID
APP_STORE_CONNECT_API_KEY_BASE64
```

Keep Developer ID certificates, notary credentials, App Store Connect API keys,
private signing certificates, and provisioning profiles restricted to protected
repository environments/secrets. Configure required reviewers on the
`testflight-beta` environment. Do not add automatic TestFlight triggers.

## TestFlight

- Prefer the manual `TestFlight beta` workflow only after the version and tag
  are explicitly chosen. Otherwise archive the `DJConnectIOS` scheme locally in
  Release configuration.
- Upload through the manual workflow, Xcode Organizer, or Transporter.
- Verify Local Network and Microphone permission prompts on a physical iPhone.
- Run pairing against a real Home Assistant `djconnect` setup before inviting
  external testers.

## Current Local Verification

For release `3.2.0`, local verification was completed with:

```sh
swift test --no-parallel
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -configuration Debug -destination platform=macOS -derivedDataPath .xcode-derived-mac CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -configuration Debug -destination generic/platform=iOS -derivedDataPath .xcode-derived-ios-generic CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectWatch -configuration Debug -destination generic/platform=watchOS -derivedDataPath .xcode-derived-watch-generic CODE_SIGNING_ALLOWED=NO build
git diff --check
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
./Tools/release/release_macos_public.sh --version 3.2.0
```

Create the notary profile once with:

```sh
xcrun notarytool store-credentials <notarytool-keychain-profile>
```

The script performs a clean archive, Developer ID export, notarization, staple,
Gatekeeper assessment, zip/checksum creation, and GitHub release upload to the
public `pcvantol/djconnect-app-releases` repository. This macOS-only script does
not build iOS artifacts; unsigned iOS diagnostics are published by the GitHub
Actions public release workflow, while normal iOS distribution should still use
TestFlight/App Store.

## Release Cleanup

After a successful release, old semantic-version GitHub releases, tags, and
GitHub Actions workflow runs can be cleaned up with the helper script. It is
dry-run by default. The public unsigned release workflow performs workflow-run
cleanup automatically after a successful publication.

```sh
./cleanup_old_releases.sh --keep 1 --keep-workflow-runs 1
```

When the dry-run list is correct, execute the cleanup:

```sh
./cleanup_old_releases.sh --keep 1 --keep-workflow-runs 1 --execute
```

The script deletes matching old `vX.Y.Z` GitHub releases, remote tags, and
local tags, plus old GitHub Actions workflow runs. It keeps the newest `--keep`
versions and the newest `--keep-workflow-runs` Actions runs, and only deletes
when `--execute` is passed. `release.sh` runs this cleanup automatically after a
successful release unless `--no-cleanup` is passed.

## Live HA Validation

Use a Home Assistant instance with the matching `djconnect` integration.

- Pair from the app-generated code and confirm HA creates the app device.
- Confirm iOS/macOS pair only through local `/api/djconnect/pair`, store
  `ha_local_url` plus optional `ha_remote_url`, and show no Client adres.
- Confirm watchOS actions, status, Ask DJ history, clear history, voice/PTT,
  and push registration run through the paired iPhone proxy and preserve
  `client_type:"watchos"`.
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
- Confirm setup, Settings, onboarding, and command payloads do not expose or
  send legacy `spotify_source` or `liked_proxy_playlist_uri` overrides.
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
`--uitesting` mode with isolated defaults and a mock Home Assistant URL. The
iOS and macOS UI tests include smoke coverage for primary navigation, local
Demo Mode, Games entry, Settings, and the `App opnieuw koppelen` action.
Extend those targets with a real mock server fixture for pairing, output
selection, queue, playlist/liked proxy, Ask DJ history sync, voice upload,
stale auth, backend unavailable states, and sanitized backend/HTML error
responses.
