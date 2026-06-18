# Contributing to DJConnect

Thanks for helping improve DJConnect.

This repository is part of the DJConnect project and is MIT-licensed. Related
DJConnect repositories are also MIT-licensed unless their own repository
metadata or a third-party dependency states otherwise. See the local
[LICENSE](LICENSE) file for the full license text.

Please follow the community standards in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
when participating in DJConnect project spaces.

## What Belongs Here

This repository contains the native Apple DJConnect app client for iOS, iPadOS,
and macOS. Changes that belong here include:

- Swift source for the app client, shared UI, and local app model;
- local app tests, build scripts, release scripts, and GitHub Actions workflows;
- app-specific docs for pairing, release validation, architecture, privacy, and
  the Home Assistant/client contract;
- local release assets and helper files that are required to build or validate
  this app.

Do not commit secrets, bearer tokens, Home Assistant tokens, Spotify OAuth
credentials, WiFi passwords, private Home Assistant URLs, private user data, or
raw diagnostics that contain sensitive values. Keep secrets out of commits,
logs, screenshots, test fixtures, release notes, and diagnostic exports.

Report suspected vulnerabilities privately through [SECURITY.md](SECURITY.md)
instead of public issues or pull request comments.

## Development Setup

Requirements:

- Xcode with the iOS and macOS SDKs used by the project;
- Swift Package Manager;
- GitHub CLI (`gh`) for release validation and GitHub release work;
- XcodeGen when regenerating `DJConnectApp.xcodeproj` from `project.yml`.

Useful commands:

```sh
swift test --no-parallel
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectMac -configuration Debug -destination platform=macOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
xcodebuild -project DJConnectApp.xcodeproj -scheme DJConnectIOS -configuration Debug -destination generic/platform=iOS -derivedDataPath .xcode-derived CODE_SIGNING_ALLOWED=NO build
./release.sh <X.Y.Z> --dry-run
```

`project.yml` is the source of truth for Xcode project settings. Regenerate the
Xcode project only when project configuration changes require it, and keep the
generated project diff focused.

## Cross-Repo Contract

DJConnect clients are coordinated through the Home Assistant integration and
shared protocol contract. Changes to protocol fields, endpoints, client types,
pairing, local Client adres behavior, OTA/update flows, Assist/STT/TTS, Spotify
playback behavior, release-note hosting, or branding may require updates in:

- `pcvantol/djconnect` for the Home Assistant integration;
- relevant client or firmware repositories;
- `SYNC_PROMPTS.md` and `PRODUCT_ROADMAP.md` in `pcvantol/djconnect` when the
  contract, roadmap, or cross-repo implementation guidance changes.

Do not introduce app-only protocol assumptions without updating the canonical
Home Assistant integration contract and any affected client implementations.

## Contribution Guidelines

- Keep changes small, focused, and easy to review.
- Add or update tests for code changes and protocol/contract changes.
- Update docs, examples, screenshots, and release notes for user-facing or
  protocol changes.
- Do not log secrets, tokens, credentials, pairing codes, private URLs, or raw
  diagnostics.
- Respect Spotify trademark and non-affiliation language: DJConnect is not
  affiliated with, endorsed by, or sponsored by Spotify AB.
- Use real DJConnect brand assets from the project. Do not redraw the logo or
  app icon unless the change intentionally replaces the brand asset.
- Keep app clients sending generic playback commands through Home Assistant;
  do not reintroduce removed client-side Spotify source or default playlist
  override settings.

## Pull Requests

Before opening a pull request:

1. Run the repo-specific tests/builds that match your change.
2. Check `git status` and keep unrelated local changes out of the PR.
3. Describe what changed and why.
4. List the checks you ran, including any tests you could not run.
5. Call out impact on other DJConnect repositories and any required cross-repo
   follow-up.

## Releases

This repo uses semantic version tags in the form `vX.Y.Z`.

The normal release flow is:

```sh
./release.sh <X.Y.Z>
```

The release script runs the third-party/tooling preflight, validates unsigned
iOS and macOS debug builds, creates the source release/tag in
`pcvantol/djconnect-app`, and triggers the public unsigned release workflow.
Public unsigned artifacts are published to `pcvantol/djconnect-app-releases`
under platform-specific tags such as `ios/vX.Y.Z` and `macos/vX.Y.Z`.

Signed TestFlight/App Store and notarized Developer ID macOS builds require the
manual signing steps documented in [docs/RELEASE.md](docs/RELEASE.md). After a
release, sync any protocol, roadmap, release-note, or branding changes back to
the relevant DJConnect repositories.

## Licensing

By contributing to this repository, you agree that your contribution is
licensed under the MIT License in [LICENSE](LICENSE).

Spotify is a trademark of Spotify AB. DJConnect is not affiliated with,
endorsed by, or sponsored by Spotify AB.
