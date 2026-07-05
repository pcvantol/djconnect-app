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

- keeps secrets out of the iOS/macOS/watchOS app;
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

The app does not automatically clear locally stored token state for backend
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

## ADR-007: Current App/Protocol Version Is `3.2.2`

Status: accepted

The app uses version `3.2.2` for app/protocol examples and Xcode marketing
version in this release.

Reasoning:

- aligns with the DJConnect `3.2.z` integration contract;
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
  but the first real LAN use remains the system trigger.

## ADR-009: Do Not Host A Home Assistant-Callable Local App API

Status: accepted

iOS and macOS pair by calling Home Assistant's local `/api/djconnect/v1/pair`
endpoint directly, then use HA's local URL first and optional remote URL as
fallback. watchOS is mediated by the paired iPhone over WatchConnectivity. No
Apple target hosts a Home Assistant callback API, advertises a pairable discovery service, or shows a callback address.

Reasoning:

- Home Assistant owns the DJConnect app-client pairing and command contract at
  `/api/djconnect/v1/*`;
- remote access belongs to HA URL selection after local pairing, not to a
  client-hosted callback surface;
- watchOS cannot reliably own direct local/remote HA transport and is simpler
  and safer as an iPhone-mediated companion.

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

## ADR-012: Unpaired Runtime Uses A Blocking Pairing Sheet

Status: accepted

The Apple app blocks playback, queue, playlists, output, and voice UI while no
DJConnect bearer token is available. The iOS/macOS pairing sheet owns local
Home Assistant URL/code entry, pairing progress, and the final success state.
The watchOS pairing sheet shows the Watch code and paired-iPhone status.

Reasoning:

- prevents users from interacting with runtime controls that cannot work yet;
- gives Home Assistant one visible pair code and one local pairing flow;
- keeps the wakeword activation prompt from competing with pairing success;
- lets Settings remain available after pairing reset through the same recovery
  path.

## ADR-013: Demo Mode Is Local UI State Only

Status: accepted

Demo Mode is available from the unpaired pairing sheet for App Store review and
UI inspection when no Home Assistant backend is available. It uses local sample
playback, queue, playlist, output, and DJ announcement state.

Reasoning:

- App Store review can inspect the native UI without a private HA instance;
- no DJConnect bearer token is created or stored;
- no HA devices/entities are created;
- live HA validation remains mandatory for pairing, entities, Spotify OAuth,
  and voice round trips.

## ADR-014: Shared Visual Canvas, Native Controls

Status: accepted

The app uses a shared DJConnect blue/purple gradient canvas across iOS, iPadOS,
and macOS, but keeps native list/table rows, pickers, sheets, and platform
permission prompts where Apple users expect them.

Reasoning:

- visual identity should be consistent across the Apple clients;
- iPhone/iPad screens should not fall back to plain black backgrounds when
  moving between Now Playing, Queue, Playlists, Games, Settings, Logs, and
  About;
- native controls keep accessibility, keyboard focus, pointer, and Dynamic Type
  behavior predictable;
- compact permission rows avoid the oversized iPhone layout that happens when
  status/detail labels are laid out as tall table content.

## ADR-015: Games Own Keyboard Input While Focused

Status: accepted

When the Games surface has focus, arrow keys and space are consumed by the game
instead of being allowed to move around sidebars, tabs, segmented controls, or
other page navigation.

Reasoning:

- keyboard controls are expected for Paddle Rally, Meteor Run, Sky Dash, and
  Maze Chase on macOS and hardware-keyboard iPad setups;
- local games are self-contained and should not accidentally change app pages;
- the app still preserves normal navigation when focus leaves the game surface.

## ADR-016: Monkey Test Mode Is Non-Destructive

Status: accepted

Debug builds may launch with `--monkey-testing` to support random UI
navigation/tap stress tests. The app starts in local Demo Mode, skips
first-run/pairing/crash blockers, avoids local Client API startup, and avoids
Home Assistant calls.

Reasoning:

- monkey tests should never reset real pairing or mutate locally stored tokens;
- random UI tapping should not create HA entities or send Spotify commands;
- local sample data keeps the runtime UI inspectable without a backend;
- Games lazy start behind a tap-to-play overlay so entering the Games screen is
  cheap and deterministic, and leaving the screen stops the local loop.

## ADR-017: Track Insight Visualizer Uses Metal on Apple GPU Platforms

Status: accepted

The Track Insight visualizer uses `MTKView`/Metal on iOS and macOS. The SwiftUI
`Canvas` implementation remains as a fallback for platforms where MetalKit is
not available.

Reasoning:

- the animated Track Insight hero is visible for long stretches on macOS and
  should not keep SwiftUI canvas rendering on the CPU;
- Metal keeps the visualizer's animated gradient, glow, and spectrum bars on the
  GPU while Swift only prepares a compact vertex buffer per frame;
- the renderer is started when the Track Insight view becomes active and paused
  when the view is closed or inactive;
- reduced-motion mode lowers the Metal view to a static or very low frequency
  render path;
- watchOS and unsupported platforms keep the simpler Canvas fallback instead of
  carrying a MetalKit bridge they cannot use.
