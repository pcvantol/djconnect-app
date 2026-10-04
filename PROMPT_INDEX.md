# DJConnect Repository Prompt Index

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

Status at PR #90 freeze point: first VibeCast Pi owner handoff slice active;
physical acceptance open

Repository: `pcvantol/djconnect-app`

## Earlier Reconciled Repository Phase

macOS runner workspace retention (PR #70).

## Status

`MERGED_RECONCILED`; `WORKSPACE_READY`.

## Current Prompt

Continue only `DJC-VIBECAST-PI-OWNER-HANDOFF-V1-20261004` for its outstanding
nonterminal active-Session update on the physical Pi. The precommit local
candidate showed owner approval, snapshot, reconnect, end cleanup and the
browser-token boundary; its installed binary was not bound to the later source
SHA. The source is merged as PRs #89 and #91. Bind a Spotify Direct backend to
the HA-dev test profile through a supported reversible path before claiming the
live update. `PI_QUAL=OPEN`. Do not start the later Google Cast slice or
select a new product item here.

## Earlier Reconciled Repository Phase

Track Insight to Apple Native Sharing implementation (PR #52).

## Earlier Current Prompt

PR [#52](https://github.com/pcvantol/djconnect-app/pull/52), **Implement Track
Insight Apple native sharing**, merged as
`0cdf0b529d51cf8631010d08bd64cc75d1e6a5c4`. It completed the sole
CMB-11-authorized Track Insight (CAP-IN-01) → Apple Native Sharing slice.

## Completion Report

The current decoder Finalization report is
`docs/history/prompts/2026-10-04-vibecast-pi-session-decoder-finalization.md`.
The earlier owner-handoff source Finalization is
`docs/history/prompts/2026-10-04-vibecast-pi-owner-handoff-source-finalization.md`.
Earlier Track Insight to Apple Native Sharing implementation history remains in
`docs/history/prompts/2026-07-26-track-insight-apple-native-sharing-implementation.md`.

Both records use the repository's existing immutable Prompt History convention.

## Earlier Next Repository Phase

At the earlier Track Insight freeze point, no subsequent Apple implementation
had been selected locally. The current selected first slice is recorded above.
