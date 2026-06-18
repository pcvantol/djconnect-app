# Development Environment

This document describes the local machine setup expected for DJConnect app
development. For day-to-day build, pairing, simulator, logging, and test
commands, see [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Supported Host

- macOS with a current Xcode release that includes the iOS and macOS SDKs used
  by the project.
- The latest verified local setup is Xcode 26.5 (`17F42`) with Swift 6,
  macOS 26.5 SDK, and iPhoneOS 26.5 SDK.
- Apple Silicon is preferred for local simulator and archive speed, but the
  project should not rely on host-specific paths or machine-local secrets.

## Required Tools

- Xcode and Xcode command line tools.
- Swift Package Manager, provided by Xcode.
- XcodeGen, available as `xcodegen`, when regenerating
  `DJConnectApp.xcodeproj` from `project.yml`.
- Git.
- GitHub CLI (`gh`) for checking GitHub Actions and release metadata.

Useful checks:

```sh
xcodebuild -version
swift --version
xcodegen --version
git --version
gh --version
```

## Repository Setup

Clone this repository and work from the repository root:

```sh
cd /Users/pcvantol/Documents/GitHub/djconnect-app
```

`project.yml` is the source of truth for Xcode project settings. Regenerate the
project only when project configuration changes require it:

```sh
xcodegen generate
```

Open the generated project:

```text
DJConnectApp.xcodeproj
```

## Local Build Checks

Use unsigned builds for normal local validation:

```sh
swift test --no-parallel
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -configuration Debug -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -configuration Debug -destination generic/platform=iOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
```

These commands should not require Apple signing credentials. Configure
`DEVELOPMENT_TEAM` only for running on physical devices or producing signed
archives.

## Simulator Setup

The current preferred simulator target for local iOS UI validation is:

```text
iPhone 17 Pro
```

Use light appearance for screenshot review unless a task explicitly asks for
dark mode. Demo Mode and monkey test flows can be launched with
`--monkey-testing`; this avoids Home Assistant calls, local Client API startup,
and first-run blocking sheets.

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for the current monkey test and
UI test commands.

## Signing And Secrets

Do not commit signing certificates, provisioning profiles, App Store Connect
keys, team identifiers that are private to a developer, Home Assistant tokens,
Spotify credentials, bearer tokens, WiFi passwords, private URLs, raw
diagnostics, or screenshots that expose sensitive values.

Signed TestFlight/App Store and notarized macOS distribution are documented in
[docs/RELEASE.md](docs/RELEASE.md). GitHub-hosted signed beta workflows must
remain manual and protected by explicit version/tag confirmation plus GitHub
Environment approval.

## Home Assistant Test Backend

Live pairing and playback validation requires a configured Home Assistant
`djconnect` integration and a Spotify Premium account. The app never stores
Spotify, Home Assistant, Sonos, OpenAI, or other backend credentials. The only
app-owned credential is the DJConnect client bearer token issued by the Home
Assistant integration.

For UI work without a backend, use Demo Mode. Demo Mode is not a substitute for
live pairing, entity, Spotify OAuth, Assist/STT/TTS, or playback validation.

## Release Hygiene

Before release or maintainer-facing workflow changes, keep these files aligned
with the actual environment and process:

- [CHAT_BOOTSTRAP.md](CHAT_BOOTSTRAP.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [SECURITY.md](SECURITY.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [docs/BUILD_RELEASE_HYGIENE.md](docs/BUILD_RELEASE_HYGIENE.md)
- [docs/RELEASE.md](docs/RELEASE.md)
- [docs/TECHNICAL_DESIGN_DECISIONS.md](docs/TECHNICAL_DESIGN_DECISIONS.md)
- [CHANGELOG.md](CHANGELOG.md)

For docs-only environment updates, run:

```sh
git diff --check
```
