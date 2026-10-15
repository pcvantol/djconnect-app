# Apple Session widgets, Live Activity and Dynamic Island: acceptance handoff

Status: OPEN. This document describes required semantics and acceptance cases;
it does not introduce a producer schema or permission to export private content.

## Ownership and delivery boundary

Core owns the selected DJ contribution, original source identities, text and
Persona realization, publication order, artwork/metadata rights, attribution,
and original deadlines. Apple owns native layout, accessibility, App Group
storage within the granted purpose, ActivityKit lifecycle and transport handling.
Apple cannot derive passive/locked-display permission from owner-native media,
private Speech, VibeCast or the ordinary notification push registration.

Existing producer handoff remains under the single Core writer in task
“Pak VibeCast shared renderer op” (01a120e2-b557-76c3-8568-129dbce2f2d2).
The 2026-10-15 follow-up asks for an explicit lane identifier/order after the
current Speech delivery. It neither interrupts that delivery nor creates a writer.

## Required producer handoff

Deliver an exact reviewed source pin, versioned contract and actual HTTP/event
fixtures for the cases below. Specify separately whether the payload may be
stored by the app, copied to ActivityKit, cached in WidgetKit snapshots and shown
while locked. A boolean owner-display permission cannot stand in for these.

The producer must bind a projection to the resolved Profile/session authority,
publication identity/order and source revision. It must distinguish the Moment's
subject from a newer currently playing track. Media and metadata need their own
source binding, attribution and original expiry. Reconnect or consumer reads
cannot renew these deadlines. Document whether partial expiry may retain other
independently permitted components. Where OS cache revocation cannot meet the
required rights, retain the neutral presentation instead of promising deletion.

ActivityKit requires its own consent/token family, token rotation and removal,
paired registration/revocation API, monotonic update semantics, end behavior and
provider delivery qualification. General APNs registration is not this route.
WidgetKit background timing is subject to OS scheduling and needs separate
acceptance criteria; do not specify continuous live refresh as guaranteed.

## Joint acceptance matrix

| Case | Required result | Evidence owner |
| --- | --- | --- |
| No active session; playback continues | No rich publication and no active Live Activity | Core fixture + Apple lifecycle |
| First accepted publication | Exact permitted art, contribution and metadata; same session mood across sizes | Core fixture + installed Apple hosts |
| New DJ publication in same session | New contribution once; preserve original subject/attribution | Core ordered events + native rendering |
| Playback advances while old Moment remains current | Never relabel the old contribution with the new recording's art/metadata | Core mixed-subject fixture + Apple adapter |
| Duplicate or older event after reconnect | No rollback, expiry extension or extra Activity | Core order contract + Apple race tests |
| Session ends before a pending image/update returns | Late result cannot restore ended content | Core end fixture + Apple cancellation tests |
| Profile/session changes away and back | Old generation cannot regain authority | Core generation fixture + Apple lifecycle tests |
| Text, art or metadata expires independently | Apply explicit component policy; never renew from local read | Core rights fixtures + native expiry checks |
| User dismisses Activity | No automatic recreation on each foreground tick | Apple installed lifecycle |
| Background/locked, new contribution | Qualified ActivityKit route updates permitted content; measure actual timing | Core provider receipts + physical iPhone/iPad |
| Missed end notification / disconnected device | Finite expiry and documented OS-cache limit; no fabricated revocation guarantee | Joint native background test |
| Long text, RTL, missing artwork, VoiceOver | Readable hierarchy and meaningful accessible content without invented facts | Apple native hosts |
| Unsupported/malformed optional projection | Preserve app session/pairing; render neutral passive state | Core negative fixtures + Apple decoder tests |
| Upgrade from configured old widgets | Same shared provider behavior, explicit legacy-kind migration | Apple installed upgrade |

## Current Apple evidence and remaining work

The neutral shared snapshot/lifecycle and confirmed mood palette exist. Rich
small/medium/large/Activity/Island layouts are pure presentation without a
production publisher. The owner-native artwork adapter and private Speech adapter
remain separate; their tests do not close any row requiring passive rights.

`Tools/render_session_surface_layouts.py` extracts the current layout declarations
and renders fifteen synthetic macOS SwiftUI images: five surface sizes, each with
normal, long and right-to-left content. It records the source SHA256 and render
bounds, and removes its temporary source/executable automatically. Review PNGs
visually; matching bounds alone is not a clipping or accessibility proof.

Run after building the Mac framework:

```sh
python3 Tools/render_session_surface_layouts.py \
  --framework-directory /private/tmp/djc-hybrid-mac/Build/Products/Debug \
  --output-directory /private/tmp/djc-session-layout-40095
```

This render harness is neither installed WidgetKit/ActivityKit/Island evidence
nor iOS Dynamic Type qualification. Do not install the neutral replacement as the
completed rich experience. After the exact producer contract arrives, implement
the typed adapter, component-rights admission, scoped cache/publisher and token
flow, then execute the joint matrix on installed native hosts.
