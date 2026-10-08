# DJConnect Repository Prompt Index

## Current Apple assignment — 2026-10-08

`DJC-APPLE-MOMENT-FIRST-SESSION-V1-20261008` bron is beschermd gemergd:
[Apple #95](https://github.com/pcvantol/djconnect-app/pull/95), reviewed head
`d57e7a441a05c455ed05e33fb6bc30fba3d74873`, exact main
`a4cb7ed2cc332499f784eb40c822a1983a9e5289`, gedeelde tree
`18a1fd935c52ff5f63db77d422349e4c3737eb65`. De oorspronkelijke
Apple WIP bleef bewaard; slechts de geïsoleerde checkout was schrijver.

De source-merge is exact-main gekwalificeerd: main-CI
[37811802408](https://github.com/pcvantol/djconnect-app/actions/runs/37811802408)
en interne SHA-evidence
[37812663643](https://github.com/pcvantol/djconnect-app/actions/runs/37812663643)
zijn PASS. Deze afzonderlijke Finalization-documenten verzoenen de bronstatus,
het oorspronkelijke WIP en de aanvullende productafhankelijkheden. Het definitieve protected-merge-, publicatie- en cleanup-readback voor
dit documentpakket wordt na uitvoering in owning
[#87](https://github.com/pcvantol/djconnect-app/issues/87) geregistreerd.
Native iPhone/iPad/Mac met werkelijke pinned producer→owner transport→state→
SwiftUI, beide spelersituaties, zes netwerkgevallen, 408 reguliere tests,
vijf talen en onafhankelijke technische/UX reviews slagen. Bewijs en grenzen:
[Finalization-record](docs/history/prompts/2026-10-08-apple-moment-first-session-finalization.md),
[assessment](docs/APPLE_MOMENT_FIRST_SESSION_ASSESSMENT.md) en
[owning #87](https://github.com/pcvantol/djconnect-app/issues/87).

Gespreks-/historieaanvulling6061498264 is afhankelijk van nog te leveren
Core-contracten, geregistreerd in [#1101 comment6064346207](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6064346207)
voor een gerelateerde Apple vervolg-PR vóór pickup. #95 levert de actuele
Moment/Flow en onafhankelijke speler, geen persoonlijke archief/conversatieclaim.
Cast/Pages en LG hostkwalificatie behouden aparte grenzen. Geen nieuwe schrijver,
Store-release, certificaat, fysieke installatie of HA-deployment.

The previous VibeCast slice is closed by #87 comments 6010273946 and
6010386668. The following predecessor sections retain their historical freeze
points and do not reopen that assignment.


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

Status at PR #90 freeze point: first VibeCast Pi owner handoff slice active;
physical acceptance open

Repository: `pcvantol/djconnect-app`

## Earlier Reconciled Repository Phase

macOS runner workspace retention (PR #70).

## Status

`MERGED_RECONCILED`; `WORKSPACE_READY`.

## Historical prompt at predecessor freeze point

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
