# Architecture Decisions

This document records the current technical choices for the DJConnect native
Apple app scaffold.

## ADR-001: Home Assistant Is The Trusted Backend

Status: accepted

The app does not talk directly to Spotify, OpenAI, Sonos, or Home Assistant
Assist for DJConnect actions. It talks to the Home Assistant `djconnect`
integration, which owns playback credentials, OAuth, STT/TTS, pairing, and
backend command execution.

Reasoning:

- keeps secrets out of the iOS/macOS app;
- preserves the existing ESP32 integration contract;
- lets iOS, macOS, and ESP32 clients coexist against one backend;
- keeps future backend changes behind the Home Assistant integration.

## ADR-002: Use `client_type`, Not `device_type`

Status: accepted

DJConnect client identity is represented with `client_type` values `ios`,
`macos`, and `esp32`.

Reasoning:

- matches the Home Assistant integration contract;
- avoids overloading playback-output metadata;
- allows `device_type` to remain reserved for backend-returned playback device
  information.

## ADR-003: Keep HTTP Contract Out Of SwiftUI

Status: accepted

`DJConnectCore` is UI-free. `DJConnectUI` depends on `DJConnectCore`, but
`DJConnectCore` does not depend on SwiftUI.

Reasoning:

- command/status/voice behavior can be tested without UI;
- iOS and macOS can share screens without contaminating the client layer;
- future menu bar, widget, shortcut, or live activity targets can reuse the same
  integration layer.

## ADR-004: XcodeGen Is The Project Source Of Truth

Status: accepted

The committed `.xcodeproj` is generated from `project.yml` with XcodeGen.

Reasoning:

- the repo opens directly in Xcode;
- project diffs remain understandable in `project.yml`;
- generated Xcode changes can be reproduced after target or setting changes.

When changing targets, schemes, bundle ids, or build settings, edit
`project.yml` and run:

```sh
xcodegen generate
```

## ADR-005: Conservative Token Handling

Status: accepted

The app does not automatically clear Keychain token state for backend
unavailable, version mismatch, authenticated 401/403, or 404 responses. During
unauthenticated pairing polling, 401/403 responses stop the polling loop and
show code/setup mismatch recovery without rotating the device id automatically.

Reasoning:

- backend unavailable is not an app pairing failure;
- version mismatch should be recoverable by updating app or integration;
- stale auth or missing route may be recoverable without discarding diagnostics;
- explicit user reset is the clearest destructive action boundary.

## ADR-006: Shared SwiftUI, Separate App Entrypoints

Status: accepted

The repo uses shared SwiftUI screens in `DJConnectUI`, with thin native
entrypoints in `Apps/DJConnectIOS` and `Apps/DJConnectMac`.

Reasoning:

- keeps platform-specific lifecycle code small;
- lets macOS use native `Settings` scenes while iOS uses tab navigation;
- leaves room for platform-specific UX without forking the full UI.

## ADR-007: Current App/Protocol Version Is `3.1.7`

Status: accepted

The app uses version `3.1.7` for app/protocol examples and Xcode marketing
version in this release.

Reasoning:

- aligns with the DJConnect `3.1.z` integration contract;
- leaves patch versioning for app releases;
- keeps the initial repo baseline clear.

## ADR-008: Permission UX Lives In `DJConnectUI`

Status: accepted

The app exposes Microphone, Speech Recognition, and Local Network permission
state in Settings. Microphone and Speech Recognition can be requested before the
user starts push-to-talk or foreground wakeword. Local Network remains
informational because Apple does not provide a reliable preflight status API for
that permission.

Reasoning:

- permission prompts are user-facing platform UX, not HTTP contract logic;
- keeping permission presentation in `DJConnectUI` preserves the UI-free
  `DJConnectCore` boundary;
- preflight prompts avoid surprising users at the exact moment they press the
  microphone or enable wakeword;
- Local Network access is still declared in Info.plist and explained in the UI,
  but the first real LAN/Bonjour use remains the system trigger.

## ADR-009: Host A Local App API While Active

Status: accepted

The Apple app hosts local `/api/device/*` endpoints while active so Home
Assistant can pair, send callbacks, and inspect the app client. The app reports
a stable Client API url after successful local pairing and keeps that URL until
pairing is reset.

Reasoning:

- Home Assistant needs a reachable callback target for app-client pairing and
  two-way status updates;
- the URL used by HA during pairing must remain stable or HA will call a stale
  endpoint;
- the local API belongs in `DJConnectUI` because it coordinates app state,
  pairing lifecycle, and platform networking rather than reusable HTTP request
  serialization.

## ADR-010: User-Mediated Crash Reporting

Status: accepted

The app detects a likely previous unclean exit with a local clean-shutdown
marker and shows a next-launch crash report prompt. It does not automatically
upload logs to GitHub Issues.

Reasoning:

- GitHub issue creation from the app would require a token or backend service;
- diagnostics may include local URLs or device metadata, so user review is
  required;
- a prefilled issue URL and copyable redacted diagnostics provide a useful
  support path without adding third-party crash reporting or secret handling.

## ADR-011: One-Time Welcome Screen

Status: accepted

The app shows a branded first-run welcome screen once per installation. The
screen points users to the Home Assistant setup repo and states that Spotify
Premium is required.

Reasoning:

- pairing and Spotify OAuth are intentionally configured through Home
  Assistant, not inside the app;
- the first launch is the clearest place to set expectations before users see
  playback controls;
- keeping it one-time avoids adding friction after the user has already paired
  or intentionally skipped setup.
