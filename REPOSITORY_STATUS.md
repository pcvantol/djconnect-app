# DJConnect Repository Status

## VibeCast Session locale handoff

Apple [PR #93](https://github.com/pcvantol/djconnect-app/pull/93) merged the
independently reviewed Session-start locale handoff as exact main
`f8e4bf9d8e4096983a04502245babd864abb04b2` from head
`d7292b29851ce81f55c436b97e72e1ef8ddcc23a`. The reviewed source and merge
trees are identical. Exact-main
[CI](https://github.com/pcvantol/djconnect-app/actions/runs/37355321818),
[Mac mini CI](https://github.com/pcvantol/djconnect-app/actions/runs/37355322019)
and [SHA-bound evidence](https://github.com/pcvantol/djconnect-app/actions/runs/37355998819)
succeeded. The internal prerelease `internal-ha-f8e4bf9d8e4096983a04502245babd864abb04b2`
targets that merge and contains one qualification JSON with SHA-256
`ff90ebfadb70d29c167abee96fe4ffd900d347d461a7afecb99733388d96cde1`.
No signing, public release, production deployment or workflow change ran.

The Apple Session-start request now sends the app's normalized BCP-47 locale
alongside the selected mood. Core exact main
`dfd78cca1f128285527631fdc4a06de560cad435` consumes that value and freezes the
five-language family in the backend-owned Session. Local qualification passed
all 401 Swift tests, the unsigned iOS Simulator build, 976 localization keys
and 29 HTTP contract routes; independent review found no actionable issue.

`PI_QUAL=OPEN` remains accurate until a signed candidate built from the exact
Apple merge is installed on the physical iPhone and proves the live
nonterminal update, reconnect, Runtime-end cleanup and token boundary on the
physical portrait Pi. This same first slice remains active and selects no
second product item. Repository State: `MERGED_RECONCILED` after this
governance-only Finalization merges. Workspace State: `WORKSPACE_READY` only
after mandatory cleanup.

## VibeCast Pi decoder source reconciliation

Apple [PR #91](https://github.com/pcvantol/djconnect-app/pull/91) merged the
independently reviewed Session decoder correction as exact main
`29f3ad55d74c155fbab51c039358cea871d4c512` from head
`6221beacb178bd26e614411c32c97ee646138165`. Exact-main
[CI](https://github.com/pcvantol/djconnect-app/actions/runs/37214330425),
[Mac mini CI](https://github.com/pcvantol/djconnect-app/actions/runs/37214330165)
and [SHA-bound evidence](https://github.com/pcvantol/djconnect-app/actions/runs/37214736801)
succeeded. The existing internal prerelease has one qualification JSON; no
signing, public release, production deployment or workflow change ran.

The precommit local candidate was observed with a paired iPhone and physical
portrait Pi through owner approval, live snapshot, WebSocket reconnect,
Runtime-end cleanup and no durable browser token. The installed binary was
not separately bound to the later reviewed head or merge SHA. A separate
nonterminal update remains unproven on HA-dev: its Profile
Platform default backend is `later_manual`. The Spotify-authorized iOS entry
already has `spotify_direct` in its options, but the normal options flow does
not change the profile default backend. No HA-dev setting was changed.
Source/browser contract tests do not replace that live receipt. `PI_QUAL=OPEN`
and the same first slice remain active. The
canonical Core Execution Horizon remains the only portfolio authority; this
record selects no second slice. Repository State: `MERGED_RECONCILED` after this
governance-only Finalization merges. Workspace State: `WORKSPACE_READY` only
after mandatory local cleanup.

## Earlier VibeCast owner-handoff source reconciliation (PR #90 freeze point)

The owner merged [PR #89](https://github.com/pcvantol/djconnect-app/pull/89)
from the independently reviewed `af5a6da4d59d42b55e22cb5b784309120e86dab2`
as exact main `1963d7a986c81b6ecb8407a21451ca84e03bdef7`. Its paired Core
[PR #1104](https://github.com/pcvantol/djconnect/pull/1104) merged as
`c46b41cb77354b57f3388ddde8e67a462b2ff919`. Exact-main Apple
[CI](https://github.com/pcvantol/djconnect-app/actions/runs/37192645432),
[CodeQL](https://github.com/pcvantol/djconnect-app/actions/runs/37192645434),
[Mac mini CI](https://github.com/pcvantol/djconnect-app/actions/runs/37192645450)
and [post-merge evidence](https://github.com/pcvantol/djconnect-app/actions/runs/37192909516)
succeeded; the single SHA-bound internal evidence prerelease contains its
qualification JSON. No public release, signing, production deployment or
deployment workflow ran; HA-dev received the explicit test installation below.

The selected first slice remains `PI_QUAL=OPEN`. The exact Core candidate is
installed in HA-dev Docker and an iPhone simulator built from exact Apple main
is paired. Live session start revealed a decoder contract error: HA returns
`broadcast.planner.current_direction`, while Apple requires absent
`session.planner.current_direction`. A backend-shaped Swift probe reproduces
`keyNotFound(current_direction)` at `session.planner`; the simulator displays
error 6. The Apple contract needs correction before the physical portrait Pi
can prove code approval, snapshot/updates, reconnect, Runtime end/privacy and
no durable token. Product qualification remains `BLOCKED`; see the
[live readback](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-5980280138). This Finalization
reconciles the merged source without selecting the later Cast slice. Repository
State: `MERGED_RECONCILED` after this Finalization merges. Workspace State:
`WORKSPACE_READY` only after mandatory cleanup.

Status at PR #90 freeze point: VibeCast Pi owner handoff source merged;
integrated acceptance open

## Repository

`pcvantol/djconnect-app`

## Role

Apple Intelligence Client UX for iOS, iPadOS, macOS and watchOS.

## Earlier Reconciled Predecessor

PR [#70](https://github.com/pcvantol/djconnect-app/pull/70), **Add runner
workspace retention cleanup**, merged as
`1711458d8d6a2171914e6788b4fe9942f20022d4`.

The daily macOS CI-tooling maintenance LaunchAgent is now the sole canonical
runner workspace-retention path. It cleans Git-ignored output only from
inactive, non-recent worktrees under the dedicated runner root and removes
expired runner diagnostics. It excludes runner binaries, update state, Actions
caches, source, durable release assets and formal qualification/release
evidence. The first canonical execution succeeded with one inactive workspace
cleaned, one recently active Apple workspace preserved and fifteen expired
diagnostics removed.

Repository State: `MERGED_RECONCILED`.
Workspace State: `WORKSPACE_READY`.

## Earlier Reconciled Predecessor

PR [#52](https://github.com/pcvantol/djconnect-app/pull/52), **Implement Track
Insight Apple native sharing**, is `MERGED` as
`0cdf0b529d51cf8631010d08bd64cc75d1e6a5c4`.

Full CI passed. The existing `TrackInsightShareRenderer`,
`TrackInsightShareService` and SwiftUI `ShareLink` remain the sole Apple path;
the user explicitly invokes the Share Sheet and no Runtime, Broadcast, API or
DJ Intelligence behavior changed.

## Current Prompt

Continue only the already selected first VibeCast Pi owner handoff slice. The
precommit local candidate showed paired Apple owner approval, physical Pi
snapshot, reconnect, end cleanup and browser-token boundary. Its installed
binary was not bound to the later source SHA. The separate nonterminal
active-Session update remains open because the HA-dev test profile selects
`later_manual`.
Use a supported reversible Profile Platform binding before claiming that live
receipt. No second Apple implementation prompt is active.

## Completion Report

The current decoder Finalization report is
`docs/history/prompts/2026-10-04-vibecast-pi-session-decoder-finalization.md`.
The earlier owner-handoff source Finalization is
`docs/history/prompts/2026-10-04-vibecast-pi-owner-handoff-source-finalization.md`.
The earlier PR #50 assessment remains in
`docs/history/prompts/2026-07-26-apple-native-share-capability-assessment.md`.

## Repository-Local Next Action

Complete the first slice's separate nonterminal active-Session update on the
physical Pi, preserve the separate Google Cast WIP branch and stop before
another slice.
