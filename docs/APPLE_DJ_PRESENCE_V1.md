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

The Owner specified the Mac sidebar sequence: DJ Session, Now Playing, Track
Insight, Discover, Ask DJ, Earlier Sessions, Music DNA, Queue, Playlists, Games,
Settings, Logs, About, Legal, Privacy, Share Feedback. Existing Mac rows are
reordered accordingly without changing destinations or their actions. The
unsigned Mac build-for-testing gate passes; no installation or native visual
acceptance is claimed.

The Mac Share Feedback action now reuses `SidebarItem` directly under Privacy,
so its body semibold font, icon/text alignment, padding and hit target match the
other sidebar rows. It retains the existing feedback-sheet action. The unsigned
Mac build-for-testing gate passes; the installed app is untouched.

The output-selector refresh action now uses the existing circular44-point
`DJConnectButtonStyle(shape: .icon)` with native interactive glass, a white
glyph and localized help. Both unsigned Mac/iOS builds pass; no installation
or native visual acceptance is claimed.

## Play Now installed/candidate discrepancy readback

After the Owner reported missing playlist controls again, fresh readback showed
that the installed `/Applications/DJConnect.app` UI framework hash matches the
preserved signed40021 binding exactly. Its UI-framework symbols lack the new
live-response projection, message lookup and scoped playback guard; the unsigned
candidate framework contains all three. Build number alone was not used as
artifact proof. Thus the source fix has not changed that installed renderer.

The existing accepted-response regression now covers both track and playlist
recommendations and dispatches the corresponding offered command exactly once,
followed by status readback. Both cases PASS on a69-file hashed, readonly Swift
input export at `/private/tmp/djc-playnow-playlist-minimal-2c9e419` using the
standard Swift build system. The original source-directory attempt stopped on
input-timestamp drift despite byte-identical SessionTimelineScreen content;
its failed log and both input-export manifests are retained. Product source is
unchanged by this test expansion. This remains software proof, not native/live
playlist acceptance. No installation was performed: the selected slice explicitly
excludes new installations until the Owner changes that scope.

### Owner-requested output device glass cards — 2026-10-14

OutputDeviceChoiceRow now uses the existing shared djSessionFrostedSurface on a non-hit-testing background, with the same bright card border and native glass/material accessibility fallback as the dashboard cards. Existing 14pt row shape, typography, selection action and selected checkmark remain; selected output also has a 2pt accent outline. No device discovery, playback, Core or persistence changes.

Unsigned Mac and iOS Simulator builds PASS from temporary source qualification copy /private/tmp/djc-output-glass-proof-f035ba7, containing the exact changed RootView bytes. Logs /private/tmp/djc-output-glass-mac-readonly-build.log and /private/tmp/djc-output-glass-ios-readonly-build.log. First sandbox build failed SwiftUIMacros service access; subsequent source-directory build stalled in NSFileCoordinator before compilation and only that own process was terminated. Failed/stalled logs retained. Native visual and installed verification NOT_RUN; no signing or installation.

### Owner-requested adaptive Music DNA card packing — 2026-10-14

The desktop/iPad Music DNA dashboard now uses an intrinsic-height SwiftUI Layout instead of row-aligned LazyVGrid. It places each next card in the shortest column, with deterministic left-to-right tie handling and unchanged subview identities/source order. Column count follows available width (minimum280pt,360pt at accessibility text sizes). Cards no longer reserve220pt minimum height or an independent vertical scroller on those surfaces; existing content18pt padding, glass borders and horizontal artist carousels remain. Compact iPhone horizontal cards retain their bounded content scrollers. Only presentation changes; no data reordering in the backend, new intelligence or action changes.

Unsigned Mac and iOS Simulator builds PASS from a separate readonly build copy /private/tmp/djc-music-dna-masonry-c3f1084. Logs /private/tmp/djc-music-dna-masonry-mac-build.log and /private/tmp/djc-music-dna-masonry-ios-build.log. Both independent source reviews give bounded GO. Native resizing/long-content/VoiceOver traversal and installed visual acceptance remain NOT_RUN for this new layout; source order alone does not prove spoken traversal. The previous6bb/c3f pre-delivery evidence stays bound to its original candidate. This Owner-requested UI delta supersedes that final source freeze; it does not complete Finalization or waive pending Mac signing/protected-publication gates.

### Owner-requested Mac archive detail title — 2026-10-14

The dated archive title was previously enabled only for iPhone. A shared savedSessionNavigationTitle now supplies the existing localized Session/date title on Mac, iPad and iPhone, both when opening from the saved-session list and through the contextual archive sheet. It resolves only the exact selected session's list or timeline metadata, uses actual startedAt/createdAt and the existing localized dMMM/current-timezone formatting, and falls back to localized Session when metadata is unavailable. The overview retains Earlier Sessions. No owner, model, navigation, playback or history behavior changes.

Both unsigned Mac/iOS Simulator builds PASS from /private/tmp/djc-archive-title-6733378; logs /private/tmp/djc-archive-title-mac-build.log and /private/tmp/djc-archive-title-ios-build.log. Independent technical and UX source reviews give bounded GO. Native Mac titlebar update and installed acceptance remain NOT_RUN; no signing/installation/publication occurred. Earlier pre-delivery evidence remains pinned to its original candidate.

### Owner-requested Mac sidebar escape from an opened archive — 2026-10-14

Mac root now owns the opened saved-session navigation binding and supplies it to SavedSessionsView. All Mac sidebar page actions clear that binding before selecting their destination; selecting Earlier Sessions again returns to its overview, and Feedback withdraws the archive before its existing sheet action. Programmatic section changes also clear the binding. Other Saved Sessions routes retain their existing local state. This is UI navigation state only: Session, playback, Profile, history windows/data and server authority are unchanged.

The existing actual-Core Mac archive/player regression additionally checks Track Insight, Music DNA and Ask DJ, requires the archive to disappear rather than only a changed sidebar highlight, verifies the same Earlier Sessions item returns to the list and asserts active Session B remains unchanged. Fresh unsigned Mac build-for-testing (including the expanded UI test) and iOS Simulator build PASS from /private/tmp/djc-archive-sidebar-0a1dec6; logs /private/tmp/djc-archive-sidebar-mac-build.log and /private/tmp/djc-archive-sidebar-ios-build.log. Independent technical and UX source reviews give bounded GO. Native execution of the corrected Mac behavior remains pending the existing temporary test-runner signing gate; compilation is not runtime PASS. No signing, installation or publication. Earlier native/pre-delivery evidence remains tied to its original source.

### Owner-requested Music DNA hero explanation — 2026-10-14

Active Music DNA hero now shows one localized sentence directly below its helix animation: “Music DNA leert van je muzieksmaak en luistergedrag om aanbevelingen op jou af te stemmen.” All five languages use ui.music.dna.hero.description. The centered subheadline has white0.82 contrast, scales normally and wraps without a line limit; the card grows with its content. No backend/state/consent or recommendation behavior changes. Localization validation passes1082keys and fresh unsigned Mac/iOS Simulator builds PASS (logs /private/tmp/djc-music-dna-description-mac-build.log and /private/tmp/djc-music-dna-description-ios-build.log). Independent copy/source UX review gives bounded GO. Native visual/installed acceptance remains NOT_RUN; no signing/installation/publication.


### Mac keyboard/chrome follow-up — 14 October 2026

The existing writer fixes the owner-reported Mac presentation regressions: hide the detail top scroll-edge veil; keep one explicit leading sidebar toggle through collapse; use individual native borderless sidebar Buttons for Tab; bind their focus to one Mac-only root FocusState and transfer focus on activation, clearing the previous row border. Native Space action and archive/Discover consent remain intact. Custom button outlines read Environment.isFocused; there is no custom Tab handler or extra focusable wrapper. The Mac composer uses ultraThinMaterial without the dark opaque gradient. Logs uses the shared frosted card, retaining search, selectable text, copy/clear and scrolling. Menu-toggle accessibility text is translated in all five languages.

Private installs: both physical Macs build40028 have identical signed files, strict/deep signatures, preserved main/widget entitlements and preferences before normal launch, with prior-app backups retained. iPhone physical build40027 updates in place and normal launch succeeds;40028 adds Mac-only focus transfer. Existing signing/profiles reused. MacBook Keyboard Navigation explicitly authorized from0 to2 and read back.

Native regression PASS on both Macs: Tab focuses Track Insight; native DJ-session button activation transfers actual focus to DJ-session; next Tab focuses Now Playing.40026 proof covers player buttons/sliders, output choices, all16 sidebar actions and reverse Shift-Tab, plus exactly one toggle at identical x/y visible/hidden/restored. Private screenshots verify the missing top veil, translucent composer and Logs card. Earlier failed/stale-process probes are retained and do not qualify later builds. This does not turn the prior Mac XCTest bootstrap failure into PASS or claim full presence/transport/runtime qualification.

No Core producer change, source publication, protected merge or slice Finalization is established by these installs. Private receipts and native readbacks remain beside the recovery writer; personal diagnostic logs/screenshots are not published.

## Owner UI refinements and private build 40029

The Mac sidebar uses a fixed 28-point icon column and 10-point label spacing. Its native toggle has neutral color and centered 36 by 28-point label bounds. Logs clear and session end use a separate trailing confirmation toolbar item. Shared chat input uses the existing five-language chat placeholder. Destructive shared trash glyphs are explicitly red. Privacy and Legal/OSS use the shared frosted card; About uses three separate cards. The VibeCast popover follows content height, omits the standalone divider and uses the shared primary button. Mac Games bounds canvas height by the measured picker and non-canvas content, retaining scrolling for small windows.

Both signed Mac and physical-iPhone Xcode builds PASS with CURRENT_PROJECT_VERSION=40029 from a recorded temporary input copy. Its Xcode project was regenerated from existing project.yml to include the focus helper. Private installation and ordinary launch verified on Mac mini, MacBook and iPhone; both Mac signed-file maps match and original entitlements/preferences were preserved before launch. Backups and input/install receipts remain private. Syntax and whitespace checks PASS. These installation checks do not claim full native visual/runtime acceptance of every refinement.

Fresh public capability read on the configured Mac connection returns HTTP200 and ha_version4.0.0-rc.1 but omits active_session_mood and active_session_presence support/version/contract. Current Core source presence support therefore does not establish installed runtime adoption. This is tracked with the existing Core issue1165. No backend deployment/restart was performed. Source publication, full presence-native acceptance and Finalization remain separate.

## Review correction: bounded VibeCast popover

Independent exact5c2266a reviews identified a P2 when an unscrollable fixed-width handoff presentation exceeded a compact iPhone or accessibility viewport. Restored the prior adaptive scroll container on iOS. Mac retains one stable scroll container and measures its form height, bounded by the visible screen; ordinary content uses its own height without empty lower space and oversized content remains scrollable. No second form/controller or handoff mutation is introduced. The initial package run from the minimal build input had six missing-file failures (five workflow/release checks and the Python redirect fixture); complete unchanged repository test support is now present for rerun. That failed result is retained, not promoted to PASS.

## Installed Mac popover regression correction (40031)

Owner observed an empty VibeCast popover after40030. The measured-height feedback admitted a transient zero. Mac form now requests its intrinsic vertical size, ignores nonfinite/zero preference measurements and keeps a bounded nonzero layout height; the same scroll container and form state remain. Signed Mac build40031 PASS. Private update and normal launch on both Macs PASS with signature/file/prefs checks and backups. Native AX opens the real installed popover on both Macs and verifies the heading, six-digit-code field and approve button with nonzero frames; closing/reopening on Mac mini also retains all controls. No code was entered and no session handoff was sent. iPhone remains40030 because this guard is Mac-only. Complete514-test40030 run PASS; failed minimal-input runs remain retained.

The tracked Xcode project now registers the existing focus helper in both Apple UI source phases, matching the generated project used in the successful builds. This resolves the initial source-CI missing-helper errors without changing workflows, runner policy or signing. Full native Presence acceptance/installed Core capability adoption and protected Source/Finalization remain separate.

## Track Insight requires playing music

Owner-requested empty-state analysis button is disabled while playback.isPlaying is false (including missing playback), with localized caption ui.track.insight.play.music.first below it. The ordinary primary style handles disabled appearance. Native playback observation re-enables the action when music resumes; the click closure also rejects a stopped playback race. This is bounded empty-state UI admission; existing backend analysis contracts and cached insight/refresh behavior remain unchanged. All five language keysets match1084 keys; Mac and physical-iPhone signed build40032 PASS.

## Ask DJ newest-first presentation

Owner requests newest items at the top in Ask DJ and active Session with an upward jump action. Ask DJ now reverses only the already normalized presentation sequence; the backend message model and exchange metadata remain untouched. Search result traversal matches the displayed order. Initial/show-newest targets move to a top sentinel, and the floating arrow/help/accessibility label use the existing localized back-top wording. Scroll geometry drives the near-top state instead of offscreen LazyVStack bottom/viewport preferences. SessionTimelineScreen already presents retained entries newest-first and uses an upward current/top jump; that behavior is retained. No replay, prompt send or playback mutation is introduced.

## Newest-first search selection review correction

Independent review identified positional search-selection drift when a newer matching response was prepended. Ask DJ now retains the selected message UUID across message updates and recomputes its displayed index. Navigation explicitly changes that UUID; query changes and closing search reset it. A focused regression covers prepending a reply, disappearing selected message, query reset and empty results. Earlier full-suite failures in unchanged Mood-replacement timing and shared widget-language defaults are retained separately, not labeled PASS or altered as part of the presentation scope.
