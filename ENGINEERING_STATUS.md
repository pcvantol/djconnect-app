# DJConnect App Engineering Status

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

## Earlier reconciled engineering state

Status: macOS runner workspace retention reconciled

Repository: `pcvantol/djconnect-app`

## Reconciled Engineering State

PR [#70](https://github.com/pcvantol/djconnect-app/pull/70), **Add runner
workspace retention cleanup**, merged into `main` as
`1711458d8d6a2171914e6788b4fe9942f20022d4`.

The existing daily `com.djconnect.ci-tooling-maintenance` LaunchAgent now
reclaims only Git-ignored output from inactive runner worktrees and runner
diagnostics older than fourteen days. Its first canonical execution succeeded:
one inactive ESP32 workspace was cleaned, a recently active Apple workspace
was preserved, and fifteen expired diagnostics were removed. Runner binaries,
update state, Actions caches, source, published artifacts and formal evidence
remain excluded. The recorded Docker Desktop cask update remains an interactive
administrator maintenance item, not a runner-cleanup failure.

Repository State: `MERGED_RECONCILED`.
Workspace State: `WORKSPACE_READY`.

## Earlier Completion Context

PR [#52](https://github.com/pcvantol/djconnect-app/pull/52), **Implement Track
Insight Apple native sharing**, merged into `main` as
`0cdf0b529d51cf8631010d08bd64cc75d1e6a5c4`.

The implementation qualifies the existing `TrackInsightShareRenderer`,
`TrackInsightShareService` and SwiftUI `ShareLink` path. Track Insight remains
the sole producer and Apple the sole Renderer Host. The local payload excludes
Music DNA, Profile, Performance Memory, Planner/Runtime context, provider
payloads, Ask DJ history, credentials, tokens, device IDs and installation IDs.

Decision: `TRACK_INSIGHT_APPLE_SHARING_IMPLEMENTED`.
