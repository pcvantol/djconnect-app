# Apple active Session DJ presence v1

Assignment `DJC-APPLE-DJ-PRESENCE-V1-20261011`, existing
`SLICE::APPLE::DJ-PRESENCE-CONTROL`; pickup6150506243, fresh ACK6152445217.
Same Apple writer; branch `codex/apple-dj-presence-v1`, actual base
`a522596f5c232cb0f73351146a34392c9a0d711f`, tree
`cf9a20dbc14aee3d3cfc98dd61cebc6299e861fc`. 40021 source105/Finalization106
are reconciled; original installed snapshot/WIP/settings/backups retained.
Fresh authoritative host verify exits0, onboarding4.5.3, all required rows MATCH.
This design precedes its runtime implementation; qualification is pending.

## Producer and ownership

Use Core source [b5c25f7](https://github.com/pcvantol/djconnect/tree/b5c25f7c8098ce805bf4cab94a887c8590f9717f)
(1150), Finalization90fa046 (1151), unchanged v1 owner contract atc955ec8.
Canonical product, owner, policy and acceptance documents remain in Core.
Pinned sanitized final transport fixtures are consumer qualification data.
Available on the actual used server only when capability boolean, version1,
route/method/authentication/scope/catalogue/default/ordering all match.
Missing or incompatible metadata means unsupported, never an enabled fake slider.

Core owns actual proactive dosing, publication, budgets and immutable Moments.
Apple renders and requests one ephemeral active-Session setting. No Profile
preference, local contribution filter, invented fact, frequency promise, queued
Moment replay, Persona/Mood/volume/TTS change or Session restart is introduced.
Only ordinary paired owner authority writes; history is readonly. Playback pause
does not end an active Session or disable this control.

## Native presentation

An active Session exposes a clearly labelled glass control: DJ-aanwezigheid /
Hoeveel vertelt de DJ tijdens je sessie? Native stepped slider and accessible
choice labels, shared on iPhone/iPad/Mac with adaptive layout. Exactly:

| Wire value | Dutch anchor |
| --- | --- |
| music_only | Alleen muziek |
| occasional | Af en toe |
| balanced | Gebalanceerd |
| talkative | Praatgraag |
| presenter | Presentator |

All five language families follow the pinned owner-contract anchors. Provide
VoiceOver adjustable value/state, keyboard operation and Dynamic Type. Desired
choice/drag preview is visibly separate from confirmed server choice. Drag commits
at release; discrete/keyboard/accessibility actions commit deliberately. Rapid
actions coalesce to the latest desired value with at most one mutating request.
The control remains navigable while a request is pending. Conflict/uncertainty
offers an explicit decision and never silently resends stale intent.

The existing AppModel remains the sole controller; shared glass/layout and active
Session presentation are reused. New SwiftUI presentation owns no business state.
Search/scroll/selected Moment/draft remain in their existing owners. Music-only
copy describes suppression of future proactive content after confirmation;
explicit Ask DJ text/voice and normal retained cards remain available.

## State, transport and lifecycle

Add optional selected_presence/presence_revision to existing active Runtime and
Broadcast DTOs, maintaining old-server compatibility. A single monotonic presence
reducer handles HTTP acknowledgement, active read and paired-live/HTTP recovery.
Presence revision is independent from Mood and scoped to exact Session/owner
epoch. Equal revision with different value, negative/malformed revision or unknown
value never grants confirmation. New Session uses only its server-reported state;
no client restoration of the previous Session's setting.

The same capability read used by active Mood supplies presence metadata. Shared
AppModel stores bounded desired/pending/confirmed state and one request task.
Every captured request binds Session ID, owner epoch, generation, selected value
and last confirmed revision. Late responses cannot undo newer confirmed state,
erase a newer desired choice, affect another owner or replace a new Session.

POST `/api/djconnect/v1/session/presence` has exactly six fields: contract_version1,
client_type, device_id, session_id, selected_presence, expected_presence_revision.
Reuse ordinary bearer and matching identity header; no generic identity envelope,
Profile hints, HA credential, Broadcast grant or action WebSocket route. Presence
writes remain HTTP. The existing local/remote coordinator gains only a bounded
single-attempt option for this mutation, avoiding its existing broad network
fallback replay; other transport work belongs to the separate transport slice.

- 200/no-op: validate exact contract/Session/value/revision delta and apply through
  the same reducer; drain at most the latest deliberately queued choice.
- 409: accept only authorized same-Session current state/readback; stop automatic
  draining and let the user decide about the wanted choice.
- Response loss or cancellation after send: unknown outcome, never write replay.
  Reconcile via an authorized active read when foreground and existing paired
  live/40021 HTTP recovery. Background cancels pending work and resumes with a
  read; it does not replay old writes.
- 401/withdrawal: use existing canonical owner revoke/reset/auth recovery; old
  private state/tasks are fenced.404/end/replacement makes old control inert.
- 400/malformed/unsupported: clear localized feedback, no invented acceptance or
  revision. End/background/Profile/pairing changes use existing lifecycle gates.

No new poller, controller, HTTP/WS protocol, routing redesign or renderer is added.

## Qualification and bounded resources

First shared decode/exact-request/reducer/controller tests, all5 values, no-op,
two-client conflict, rapid intent, reply/event races, lost reply/cancel, unsupported
metadata, auth withdrawal, end/replacement/old reply and foreground resume.
Re-run relevant40021 privacy/no-replay/HTTP recovery and UI invariants.

Then existing isolated actual HA SDK/router/pairing/Profile/Runtime/Broadcast
paths from the exact producer, with synthetic configured music/provider/STT
boundaries declared. Own loopback18213/18214 must be free; no installed HA,
user credentials, external provider calls or Core writes. Ordinary paired HTTP
CAS, live/readback and native UI must be connected; decoding fixtures alone
is not integration PASS. Capture exact source/producer bindings and native
iPhone/iPad Simulator/Mac screenshots and a short pending/confirmed sequence.
Verify music-only retains old publications/explicit questions and doesn't reset
budgets when raised. Physical voice/speakers/installed/CAF/Pi remain separate.

Native all5 language/accessibility/layout proof plus independent technical/privacy/
concurrency and UX reviews apply to the exact candidate. Fix findings and re-review.
Protected source PR/checks/exact-main/artifact readback precede separate exact-SHA
Finalization. Send actual node/status/consumer receipts to Core1101 for its owning
writer's DAG updates; no sibling roadmap/SYNC copy or Core document write.
No install, signing, HA/Pages/runner/workflow change, Forecast, summary, new provider
or automatic next product slice. Stop after this selected Presence delivery.

## Owner-added presentation scope

The Owner additionally requested glass rows for queue, saved Sessions and playlists
during implementation. Their existing shared `DJConnectMediaRowSurface` now reuses
the native Session glass modifier and bright border, including the existing
Reduce Transparency material fallback. This is a bounded Apple presentation
change; the list models, row actions and backend contracts remain intact.

The Owner subsequently requested one scrolling Session panel on iPhone/iPad/Mac:
current playback/Moment and retained conversation now share the existing timeline
scroll controller. The former pinned upper panel and its nested fallback scroller
are removed. The existing Mood palette paints the entire active Session surface;
readonly history retains its ordinary canvas. Composer, exact-entry search,
reading anchors and owner/Session identity keep their existing owners.

The Owner also reported blurred unselected Media/Format labels in Track Insight
sharing. That shared selector retains its outer native glass surface; individual
segments use ordinary high-contrast fills with white labels, avoiding nested
interactive glass over the text. Selection, accessibility traits and rendering
actions retain their existing owners.

## Native qualification isolation

Bind Xcode's first automatic app launch as well as the explicit test launch to
the loopback-only ordinary-pairing fixture. Use dedicated new simulators and a
temporary distinct Mac bundle while preserving the running installed Mac app.
Debug UI/Swift qualification resolves shared presentation/widget preferences to
an isolated suite; production app-group identity remains `group.dev.djconnect`.
No fixture data may replace installed40021 preferences or private widget state.

## Owner-added Mac window chrome correction

The Owner reported desktop content showing through the toolbar in ordinary
window mode. The main NSWindow now uses its standard opaque background and
nontransparent native titlebar. The fullscreen toolbar visibility and removal
of fullSizeContentView remain intact; no traffic-light/header geometry is changed.
The unsigned Mac build-for-testing gate passes. Native visual Mac qualification
remains behind the existing temporary-runner permission gate. No installation.

## Owner-added stable Mac toolbar placement

Collapsing the sidebar must not relocate page actions to the trailing edge.
The system-owned sidebar toggle is explicitly repositioned with
`DefaultToolbarItem(kind: .sidebarToggle, placement: .navigation)`; no replacement
sidebar controller or visibility store is added. Session actions and list search
use explicit platform placement. The active Mac Session uses one action group,
with the existing refresh action passed from its owner and rendered first.
Queue/playlist refresh also precedes search on Mac; iOS retains trailing refresh.
Both unsigned Mac/iOS build-for-testing gates pass. Native Mac visual proof still
requires the already-pending temporary-runner authorization.

The active Session refresh belongs to the same toolbar action group on both
platform families: first on Mac, last on iOS/iPadOS. The parent renders refresh
only outside the active timeline, preserving its existing action/toast owner.
An initial native iPhone order check caught the parent/child placement regression;
its failed receipt is retained. After grouping the actions, the existing
`testSessionRefreshIsRightmostToolbarAction` passes (one test, zero failures,
12.792 seconds). Both unsigned platform builds pass after this correction.
Mac collapsed-sidebar visual qualification remains pending runner authorization.

The Owner reported the Media/Format labels again. The share selector now applies
its frosted surface to a separate background view rather than the controls'
entire subtree, keeping all option text outside the glass compositor. Labels
use explicit white semibold body text; existing selection and accessibility
traits are retained. Both unsigned Mac/iOS builds pass. This is source/build
qualification; native Mac visual verification remains pending runner permission.

## Owner-added queue selection recovery

Starting a queue item now schedules an explicit fresh queue read through the
existing command refresh scheduler. The read is independent of the eight-second
status throttle and thirty-second collection throttle. A pre-selection queue
read is allowed to finish, then the invalidation triggers another read rather
than being discarded by `isLoadingQueue`. Waiting remains cancellable and checks
foreground, pairing and offline state. Coalescing retains the queue invalidation
until completion, including when a subsequent status-only action reschedules it.
The server response updates the existing shared queue projection on all Apple
clients; playback commands, transport and backend contracts are unchanged.

Qualification: 511 shared Swift tests pass, including wire regressions for busy
status and a delayed pre-selection queue read, plus scheduler overlap retention.
Unsigned Mac/iOS build-for-testing gates pass. Independent technical delta review
reports no remaining P1/P2. This is software/build proof, not installed/native
end-user acceptance. The installed40021 apps/settings remain untouched.

## Owner-added hero glow

Track Insight's empty hero, Discover's header and Ask DJ's hero reuse one
decorative glyph view. The sharp foreground symbol retains the existing gradient;
a faint blurred duplicate behind it breathes over six seconds, without moving
text or controls. The animation redraws only the glyph at a maximum of fifteen
updates per second. Reduce Motion and inactive scenes render a static halo with
no animation timeline. The decoration is excluded from accessibility and hit
testing. Both unsigned Mac/iOS build-for-testing gates pass; independent bounded
source UX review reports no finding. Native animation smoothness/performance and
installed acceptance are not claimed. No release or installation is performed.

The Owner also requested gentle spinning of the welcome vinyl illustration.
Only the disk/grooves and a faint reflection rotate, once per thirty-two seconds;
the center label, sparkle and surrounding badges/equalizer stay stationary.
Reduce Motion and inactive scenes use a static disk without an animation timeline.
Existing illustration geometry, accessibility hiding and hit-testing behavior
remain intact. Both unsigned Mac/iOS builds pass; bounded source UX review has
no findings. Native smoothness/performance and installed acceptance remain unclaimed.

## Owner-added archive back-to-top control

Readonly earlier Session timelines now reuse the existing floating glass
`session-jump-top` button and sole scroll-position controller. The archive
summary is the real top target; visibility tracking shows the button when that
header leaves view and hides it at the top. Archive help/accessibility text is
localized in all five languages, while active Session labels remain unchanged.
Localization validation passes for1081keys; unsigned Mac/iOS builds pass.
The existing iPhone active-Session shared-control test
`testIPhoneSessionHeroScrollsAwayAndJumpReturns` passes (one test, zero failures,
19.362seconds). This verifies preservation of the active shared control, not
native archive-specific or Mac visual qualification. Independent bounded source
UX review reports no finding. Installed apps remain untouched.

The Owner requested stronger search highlighting. Session/server-range and
Ask DJ text marks now share an opaque warm-gold background with dark navy text;
selected Session cards and Ask DJ bubbles share a three-point focus border.
The existing focus gradient, server UTF-16 ranges, queries and result navigation
remain intact. Both unsigned Mac/iOS builds pass; bounded source UX review has
no findings. Native visual/installed acceptance is not claimed.

## Owner-added active Session Play Now parity

The new Session timeline previously rebuilt conversation replies as text-only
messages and made every common bubble readonly. It now reuses the existing Ask DJ
response mapper and playback-action stack for a directly accepted live answer in
the active Session. Ephemeral presentation state in the existing HistoryModel
binds that answer to the owner epoch, Session, server/client message identity,
text and retained entry. History reads never populate it; suspend/reset/Session
identity changes clear it. Archived answers remain the existing readonly projection.

Only the common playback stack is enabled by this live adapter. Its callback
revalidates the captured scope and exact offered payload before using the existing
AppModel playback route. Generation/validity fences cover dispatch, response,
follow-up status/collections, errors and loading cleanup. Only the `active`
presentation field is normalized for completion/output state; command/URI/value
identity stays intact. Accepted response links use native URL opening after the
existing safe link projection and a HTTP/HTTPS/no-credentials guard.

Qualification:514shared Swift tests PASS, including live reply-to-entry projection,
one explicit callback dispatch/status refresh, forged/stale/archive rejection,
withdrawal before dispatch and late command/status/collection responses. The
existing rapid Presence test replaces its20ms request-start assumption with a
held first reply and observed dispatch; its one-write/latest-queue assertions
remain intact. The initial timing failure and successful controlled full rerun
are preserved separately. Both unsigned Mac/iOS build-for-testing gates PASS.
Independent source technical/UX findings were repaired; final frozen review is
recorded separately. These are software/build checks, not installed/native Play
Now acceptance. No Core contract/source write, transport rebuild or installation.
