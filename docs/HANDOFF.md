## 2026-10-19 — UI follow-through and native Session acceptance slice

User selects the next lane slice and open development work. Preserve the current
single writer/checkout and consolidate the accumulated owner-requested UI fixes:
white Website link, plain push-registration copy, visible artwork gesture
feedback, white native interactive-glass Favorite, top-aligned avatar/text, and
shared mood-colored WidgetKit/ActivityKit avatar without the duplicate expanded
Island icon. Existing palette/expiry/rights fences remain authoritative. No
foreground capture/pending/speech state is exported into passive caches.

Next bounded slice is native Session regression acceptance: isolated review_demo
checks one avatar, side-by-side text, Favorite action, pause/resume and retained
content. It makes no live backend request or personal mutation. Source builds
and component renders already pass; actual UI-test result/review/CI/merge remain
separate. No installation is selected in this continuation.

Core1210 has no delivered catalogue and Core1212 explicitly remains planned;
Core1209 has no qualified lifecycle handoff. Apple128's atomic suggestions/Help,
Apple129 speech routes and Apple127 dynamic states therefore stay OPEN. Do not
replace those prerequisites with local catalogues or inferred background states.

## 2026-10-19 — Now Playing album-tinted glass and interactive controls

Owner asks for the playback controls card to use glass and follow album art,
plus interactive glass on Play/Favorite/Shuffle/Repeat. Both native player layouts
now reuse the artwork URL-fenced tint sampler and shared glass compositor without
image-only padding; their existing cover-aligned width remains unchanged. Missing
or replaced artwork cannot retain the previous cover tint. Demo uses the same
neutral placeholder choice as its displayed cover. Retired the old opaque player
gradient and its duplicate unfenced tint task. Primary/selected button surfaces
now opt into interactive glass; Favorite no longer disables it. Existing actions,
selected states, accessibility/disabled behavior and Glass effects/Reduce
Transparency fallbacks remain. Native build/review/visual proof follow separately;
no backend change or physical functional acceptance is claimed.

## 2026-10-19 — consolidate all retained stashes

All12 historical stash entries are compared against main17477f0, including
untracked files and screenshots. Only the Watch mood icon correction remains to
recover; all other source changes are present, evolved or explicitly retired
Party experiments. See [complete disposition](maintenance/STASH_CONSOLIDATION_20261019.md).
Verified snapshots, original Git commits and hash manifest remain under
`build/recovery/stash-consolidation-20261019/`; preserve during cleanup. Protected
merge/readback and removal of exact audited stash refs form the next checkpoint.
Existing Core-contract and native/physical acceptance gates remain open.

## 2026-10-18 — avatar graphics lane resumed after migration

User selects existing lane continuation. Reused clean `feat/dj-persona-avatar`
at main c012e5456d0b1eabbb390fc4d5b42ffb9cd13170 in the migrated Shared Data
checkout. First local-graphics slice follows Apple127/Core1209's latest full-ring
headphone refinement. Native vector and static menu derivative share geometry;
one material current-card parent contains the avatar and every existing state.
No backend activity/touch/audio wiring starts before Core's qualified handoff.
See docs/design/DJ_PERSONA_AVATAR_V1.md. Source PR130 protected-merged as
`d95d3c3ebc8aae153c04d0bb3c5ce512a8afa3c5`; independent automated review
completed without findings on exact candidate `5d661066dc6b113a3723c09099c3700eb6692e21`.
Full861tests/10suites PASS; ordinary signed iOS/macOS40348 and iOS UI-test
compilation PASS. Main CI39167432496 and formal run39168031661 PASS; documentary delivery pending; no installed
or full-app interaction acceptance claimed. Old `.xcode-derived` contains former
Documents paths and is not used; new builds must use a fresh generated stage.

## 2026-10-18 — Session start card copy

The pre-playback Session card now says “Je sessie begint hier” with the requested
Dutch explanation in a smaller body font underneath. All five app languages
have equivalent copy. This is local to the Session card; the quiet-playing
state and shared brand sentence retain their separate existing meaning.

## 2026-10-18 — integral manual refresh consistency

Every iOS/iPadOS/macOS content-refresh gesture and toolbar action now delegates
to the same per-screen function and shared manual-refresh controller. It emits
localized loading/result notices, shares concurrent callers, survives gesture
cancellation, waits for an existing read where needed, and suppresses results
after a Profile epoch change. The generic toolbar button now requires an explicit
action so new screens cannot silently bypass the shared handling.

Music DNA, conversation history and timeline reads return their actual result;
retained old content no longer implies a successful refresh. Session feedback
covers playback, current Session, conversation and the visible timeline read.
Archive details and their inline retry share the same operation. Output inventory
refresh also has progress/result feedback. Empty-screen and idle-Session refresh
restrictions remain in force. See `docs/MANUAL_REFRESH_AUDIT.md` for the screen
matrix and validation boundaries.

## 2026-10-18 — Discover gesture refresh

Manual Discover refresh now shares a request between pull and toolbar callers
and survives cancellation of the SwiftUI gesture task. Both actions show progress
and the actual result. Existing epoch, source, foreground and response-generation
checks still reject obsolete responses, including after suspension. Push refresh
coalescing and initial-feed supersession retain their existing behavior.

## 2026-10-18 — no pull-to-refresh on empty feature screens

Track Insight, Discover, Ask DJ and Music DNA remove the native refresh action
while their displayed content is empty. Track
Insight requires an insight; Discover requires visible sections; Ask DJ requires
messages; Music DNA requires an enabled, nonempty profile. Automatic initial
loads and toolbar/retry actions remain available. Pull-to-refresh becomes available when content arrives.

## 2026-10-18 — consistent manual refresh

Active DJ-session pull-to-refresh and toolbar refresh now share the same async
route, including loading/result notices and conversation/timeline reads. Idle
sessions still have no manual refresh. Now Playing announces progress on both
entry points. Manual playback refreshes share one request and wait for an
in-flight background refresh instead of treating busy as failure. The shared
request survives SwiftUI gesture cancellation; backend/transport errors still
return failure and existing output/authority fences remain in place.

Validation for this slice is recorded in the delivery PR; physical gesture
acceptance remains separate from model tests and native compilation.

## 2026-10-18 — Confirm disable and delete app diagnostics

Owner follow-up supersedes PR119's retained-history behavior for an explicit
confirmed disable action. The Settings picker keeps the current level until
confirmation; Cancel changes no preference or data. Confirm deletes the app's
persistent diagnostic file, sets the local level tooff, and clears visible
entries without emitting a replacement clear marker. A deletion error leaves
logging enabled and presents an inline localized retry explanation. All four
confirmation/error strings exist in five languages. System/server logs and
Profile data are outside this app-file operation. Unconfirmed preference changes
and startup never delete logs. Six focused actual-file tests pass0.224s and
full850tests/10suites pass91.233s;1318-key/five-language and work-register/diff
validation pass. Ordinary40342 build/installation readbacks follow separately.

## 2026-10-18 — Disabled app diagnostics by default

Owner requests an additional Disabled log level, default selection, and hiding
Logs from the menu while disabled. The local preference now defaults tooff;
invalid stored values also resolve tooff, while existing explicit valid levels
remain intact. More and Mac sidebar only show Logs when logging is enabled;
old Logs navigation requests route to Settings. App diagnostic emission and
persistent writes, including the separate debug presentation recorder, honoroff.
Retained diagnostic files are preserved. No Profile/backend contract changes.

Existing persistence/redaction tests explicitly opt in; screenshot walks that
include Logs opt in through their launch argument domain. New actual-file
regressions cover defaultoff/no-file and off persistence/no append/no deletion/
re-enable. Six focused tests pass0.249s; full849tests/10suites PASS91.212s;
Mac and iOS build-for-testing,1314-key five-language validation and work-register/
diff checks pass. Ordinary40341 build/installation readbacks follow separately.

## 2026-10-18 — UI consolidation and bounded cleanup

Owner requests protected merges and thorough stale test/simulator/branch/worktree
cleanup, with no residual work hidden by a source merge. PR116 protected merged
as9f3d0fef; PR117 protected merged as6058ddd9. Each squash tree was verified equal
to its qualified source tree. The latest UI/preferences/search work passes the
full847-test/10-suite serial run94.336s; ordinary iOS/Watch/widgets and Mac40339
builds passed before the unused-localization-only cleanup. Four unreferenced
history UI keys (More/Ended/Final/counts disclaimer) are retired in all five
locales;1313keys remain coherent. Active compatibility/security regression tests
are retained; no test was deleted merely for exercising legacy input.

Fresh local simulator inventory is empty. Two unused old simulator build caches
were removed (486477824allocated bytes); screenshots, xcresult evidence, source,
recovery apps and current qualification stages remain intact. Exact cleanup
receipt: ignored build/qualification/finalization-20261018/cache-cleanup.json.
Native/source merge does not qualify unavailable devices, provider audio or
background transport. Existing Core writer is handling the remaining explicit
producer/installed handoffs; no open acceptance item is silently marked closed.

## 2026-10-18 — iPad and Mac Now Playing card width

The playback card now shares the exact `IOSTrackHero` maximum-width value with
the artwork above it. The constraint precedes its material/outline, keeping the
visible bounds aligned in loaded and empty states. iPad playback controls remove
their redundant inner padding and tighten the five-action row to5pt spacing so
all44pt targets fit inside the270pt artwork column. The owner follow-up applies
the same shared artwork width to the Mac playback card before its background
and outline; its existing controls fit inside that column. iPhone layout is
not changed. Native ordinary iOS/Watch/widget and Mac builds40339 and localization/diff
validation pass; physical rotation/window pixel acceptance and installation
remain open.

## 2026-10-18 — Idle Session refresh presentation

Owner follow-up removes `.refreshable` from the idle DJ-session welcome scroll
view and removes its idle refresh toolbar action on iPhone/iPad/Mac. The existing
active Session timeline owns its normal refresh controls. The active refresh
callback checks Session identity before work and after each awaited read, so a
late response cannot add a refresh result toast to a different/ended Session.
Only UI/manual refresh is changed; no connection discovery/polling or history
refresh policy was changed. Shared compilation and diff hygiene pass. Not yet installed.

## 2026-10-18 — Configured TTS example still open

The owner again requests the agreed TTS example in Speech preferences. It is
still absent: the local Apple sample is a separate feature. Current Core source
contains preview implementation/fixtures but its canonical handoff still says
qualified producer pin and installed HA-dev capability are pending. The existing
authorized Core writer was asked to complete qualification/delivery and provide
the exact consumer handoff; Apple has not invented an endpoint or replayed a
fake turn. See [preview request and current boundary](feedback/APPLE_VOICE_PREVIEW_CONSUMER_REQUEST_20261017.md).

## 2026-10-18 — Speech preferences pop-out follow-up

Owner-requested local WIP after installed40338: shared iPhone/iPad/Mac Voice
pop-out is now titled "Spraakvoorkeuren" (five languages). Device Apple STT and
TTS controls are moved from Settings into its distinct device section, below the
existing output/voice/autoplay choices. An independently observed child keeps
local controls reactive inside the equatable Profile editor, including without
a server snapshot/text-only output. Existing private preference keys, input and
output routing are retained. The TTS explanation now states what enabling it
does. Shared compilation, six local speech/menu tests (0.422s),1317 localization
keys and diff hygiene pass. Watch's separate native preferences screen remains unchanged. New build
installation and physical pop-out/scroll acceptance remain open.

Additional owner follow-up moves the existing voice-activation action, editable
wake phrase and live activation status from Settings to that same observed
device section. Existing prompt/permission handling and status explanations are
reused; normal action labels stay white. Shared compilation and seven existing
wake-word/local speech/menu tests pass (0.472s). No wake-word behavior or stored
values are changed by moving the controls. Not yet installed.

## 2026-10-18 — Automatic search pagination follow-up

Owner-requested local WIP after PR118/installed40338: remove both manual
"Meer laden" controls. Saved Sessions uses its existing lazy cursor footer during
search as well as ordinary scrolling; the search field shows loading and no-match
is withheld while more headers remain. Session Flow search buffers up to100
matches automatically, then prefetches near the end through scrolling or result
navigation. Cursor/generation/owner checks remain; stale expected cursors do not
read and a repeated search cursor fails closed instead of looping. Four focused
tests pass in2.354s, covering stale query/scope, list append/deduplication,
transient/repeated-cursor/revision-change failures, and automatic search paging.
Shared UI compilation and diff hygiene pass. Native visual
acceptance and installation remain open for this follow-up.

## 2026-10-18 — Installation-local Apple STT and UI refinements

Apple STT is opt-in/defaultoff in the device speech section. Both shared
composers recognize the temporary recording locally, insert the final text into
the existing draft and submit once. Explicit supported on-device recognition,
permission/locale checks, no WAV fallback, cancellation and owner/context/draft
fences are implemented. No backend/Profile contract changed. Speech permission
purposes and four new labels/errors are translated in five languages.
Focused3testsPASS; full846/10PASS93.140s without parallel execution. Native signed
ordinary40338 iOS/Watch/widgets and Mac builds, strict signatures, compiled
permission strings, zero test bundles and163source/stage inputsPASS. Ordinary40338 installed/read back/opened on iPad/MacBook/Mac mini; previous
Mac apps and pairing retained, defaultoff toggle. Actual microphone/TCC/STT
accuracy/offline audio acceptance remains unqualified. Watch's
own input route is unchanged. See [scope and evidence](feedback/APPLE_DEVICE_STT_20261018.md).

## 2026-10-18 — Passive contribution grant and publication recovery

Owner follow-up: archive list/detail omit redundant ENDED ("Afgesloten") and
final-summary ("Definitief") labels. INTERRUPTED remains visible as "Onderbroken";
provisional summaries retain their qualifier. The redundant counts-scope footer
is also removed at the owner's request. A white corresponding Mood symbol follows
the predominant-Mood line in both list rows and details, using the existing
selector symbols only for a known complete symbolic Mood. These refinements are included in the ordinary40338 products after PR117.
List artwork/icon tiles now share the More-menu reference radius14pt: queue,
playlists, saved-session leading tile, Music DNA tracks and Ask DJ media rows,
including loading/error placeholders. An earlier compile attempt could not complete with only133MiB free; after space
became available, full846tests and ordinary40338 native builds pass. No generated
caches, active evidence or installed recovery apps were removed by this work.
Native visual acceptance remains open.
Settings follow-up: destructive buttons opt into interactive red-tinted glass
through the existing button style, respecting the local glass preference and
Reduce Transparency. Non-destructive settings labels explicitly use white text;
content and navigation both supply white tint/accent to native controls. Red
destructive roles and existing confirmations remain intact. Included in40338.

Current Apple WIP is stacked on summary PR116. Two passive1 defects are
reproduced/fixed: home widgets accept their own grant without locked-screen
permission, and publication hints during artwork IO survive for a bounded pure
reread. Focused18/full843testsPASS; original expiry/owner fences remain intact.
Core's v1 narration compatibility repair and negotiated attribution/quiet-push
contracts remain pending. No background delivery or installed widget acceptance
is claimed. See [scope and evidence](feedback/APPLE_PASSIVE_CONTRIBUTIONS_20261018.md).

## 2026-10-18 — Apple history summary consumer

The next existing-lane slice `HISTORY::APPLE::SUMMARY` consumes Core's already
protected-delivered summary1 projection; no producer contract or Core source
change. Owner list/archive header now render registered observations, semantic
publication counts, optional retained counts and predominant Mood, gated by
exact capability/version. Revision scalar types/as_of/state/bases/coverage are
validated; malformed optional data never hides a valid Session. No local totals,
new requests or passive/shared export. Full suite840/10PASS91.736s, focused6tests/
29casesPASS,1313keys/fivelanguagesPASS; signed ordinary Mac/iOS/Watch/widgets40336buildsPASS. Installed/read back and
opened40336 on iPad/MacBook/Mac mini; old Mac apps preserved, pairing retained.
iPhone/Watch unavailable/last40331.
Native visual/paired-device rendering and protected delivery remain open.
See [scope and qualification](feedback/APPLE_HISTORY_SUMMARY_ADOPTION_20261018.md).

Prior source work is merged via PR115/main `abcb7316d3189123302c7bddecf1815a3284ab56`.
All candidate checks and the ordinary main CI tests/builds passed. Separate main
native coverage could not initialize its IDE session; full formal release evidence
remains unqualified. No SIP/security bypass; profiling stays owner-deferred.

## 2026-10-18 — Saved-session deletion consumer and pending UI follow-ups

Single and bulk manual archive deletion are implemented as capability-gated Apple
consumers of the existing Core writer's selected contracts. Bulk uses an owner-bound
five-minute server snapshot and exact count before confirmation, then one fresh
UUIDv7 mutation. Search and red trash share the list's leading toolbar group.
Empty snapshots never offer a destructive action. Active Flow/ownerepoch/live
speech leases survive; archive-only invalidation fences stale reads and returns
archive navigation to the refreshed list. No personal data was deleted for testing.

Full Swift suite: **834 tests /10 suites PASS91.717s**; focused deletion/toast
qualification **8 tests /43 cases PASS**; localizations **1302 keys/five languages
PASS**; work-register/diff validation PASS. Seventy tracked product/test inputs
match the private compiled source stage. Evidence and limits:
[manual deletion qualification](feedback/APPLE_SAVED_SESSION_DELETION_20261018.md).
Core producer implementation/fixtures/exact qualified pin, native visual acceptance
and installed enablement remain pending. Both deletion topics remain PARTIAL;
missing capabilities keep the actions hidden. Ordinary build40335 now includes these follow-ups and is installed/read back on
iPad, MacBook and Mac mini. Deletion remains hidden without producer capabilities;
installed enablement and protected delivery are not claimed. iPhone/Watch remain
on their last confirmed40331 because they are unavailable. The local native UI runner timed out enabling automation mode before screen
actions; own processes were stopped without repeating the failed run. Native
visual acceptance remains open; USB scroll profiling stays owner-deferred.

Other pending UI follow-ups in this same preserved WIP: help-command onboarding
hint, consistent party icon, white native action tint, session-artwork separated
from clock-driven rendering, shorter session-end actions/profile-retention message,
and removal of its duplicate saved toast/extra archive lookup. Swift compilation
and regressions passed; visual transition/confirmation/device proof is separate.
Profiling was explicitly deferred by the owner; do not resume measurements silently.

## 2026-10-18 — HTTP200 history decode repair / ordinary40334

Existing Core writer confirmed the live closed-decoder mismatch; new metadata
narration rejected the whole200page on40331. Four explicit bases/six kinds,
source-free withdrawn/silent receipts and capability-negotiated historyv2 now
supported. Same-identity withdrawal, version/cursor boundaries and typed upgrade
without pairing loss are covered. Full828tests/10suites PASS91.278s. Physical
iPad15→18entries and MacBook12entries read/reopen PASS/no duplicates; iPad
stop/start/archive/resume PASS. Mac mini live check SKIP/unpaired. Ordinary40334
installed/read back/launched on allthree named targets, strict signatures and
zero test bundles. All161build-source hashes match. Core's minimal history-only
HA-devartifact77861070… installed199/199match; independent archive hash and
capability2/v1typed409/v2schema2HTTP200 readback PASS. After restart, iPadv2
lifecycle PASS; final iPad+MacBook both3entries/one new narration/reopen/no
duplicates PASS. Ordinary apps restored/launched, new Session left active.
No protected source-main/production, old404, Watch/iPhone, audible TTS or
USB-performance closure.
[Repair and evidence boundaries](feedback/APPLE_SESSION_HISTORY_REPAIR_40334_20261018.md).

## 2026-10-18 — Ask DJ context menus /40332 local candidate

Followup on main7af44f7, branch `codex/ask-dj-session-context-menu`.
Ask DJ prompt/report menu icons explicitly use white native menu tint. Active
Session conversation questions and answers now reuse the same menu and report
sheet, including pending questions/current-only answers and retained rows.
Questions offer prompt reuse; assistant answers also offer reporting. Archived
Sessions stay readonly; retained actions check response epoch and retention.
Signed iOS (including Watch dependency) and macOS40332 builds PASS. Native
iPhone simulator test `testSessionConversationContextMenuReusesPromptAndReportsAnswer`
PASS; final menu screenshot visually confirms both white icons. Localization
validation1287keys PASS; diff whitespace check PASS. Initial native attempts
exposed lazy-row test navigation and an unreliable software-keyboard visibility
assertion; final test scrolls to the row and checks the draft/send availability.
No physical installation or physical keyboard-focus acceptance claimed. Devices
remain40331. Private test evidence: MacBook `/private/tmp/djc-context-menu-40332-white.xcresult`;
local screenshot `/private/tmp/djc-context-menu-40332-white-menu.png`.

## 2026-10-18 — All devices40331; formal source proof PASS

iPhone/iPad/Watch/MacBook/Mac mini40331 actual installed versions and launch/
process readback PASS. Watch retried after explicit unlock/nearby confirmation,
previous40311. No physical Watch TTS or performance acceptance inferred.
SourcePR113 protected-merged as803d77c; mainCI39109669813 including native
coverage and formal reconciliation39110224530 PASS. Durable asset hash, canonical
integrity,12formal checks, coverage main SHA and runner ZIP digests independently
verified. Separate documentary Finalization candidate is ready; not merged.
TDE3CRITICAL184HIGHcomplexity and named product/runtime gaps remain OPEN.
[Snapshot](history/prompts/2026-10-18-apple-40331-finalization.md) /
[exact source readback](verification/apple-40331-finalization/source-main-readback.json).

## 2026-10-18 — Source PR113 merged; separate Finalization in progress

Reviewed candidate0386dc89788b8ce35fa579c9761c1e8eda7d7cf0 protected-merged as
source-main803d77c665701fc9fe3d3d5cc8ee0752597343a1; identical tree0ff7976d.
PremergeCI39109183076 and Trusted Delivery39109183011 PASS. Source classified
NORMAL_RISK; Owner Authorization NOT_REQUIRED on exact SHA. All276installed
source-input hashes and independent remote-ref/fetch readback match.
Documentary branchcodex/apple-40331-finalization changes no product/test/project
bytes. MainCI39109669813/formal evidence pending; source MERGED_UNRECONCILED.
TDE observed assessment FAIL with3CRITICAL184HIGHcomplexity findings, regression
UNKNOWN; explicit non-blocking workflow success is not quality acceptance.
Watch and all other named product/runtime acceptance remain open.
[Finalization snapshot](history/prompts/2026-10-18-apple-40331-finalization.md).

## 2026-10-18 — Owner requested delivered-work finalization /40331

Source finalization preparation started, preserving sole writer and WIP.
29local commits after reconciled mainf6b0a71 plus delivered followups selected;
seven recovery duplicate paths excluded and preserved. Four physical installations
confirmed40331; Watch remains unverified. Required local checks PASS; full source
regression821tests/10suites PASS90.555s; standalone VibeCast10tests PASS.
No source PR, protected merge or current full independent
review yet. [Scope and remaining gates](feedback/APPLE_SOURCE_FINALIZATION_40331_20261018.md).

## 2026-10-18 — Owner requested all-device installation /40331

Ordinary40331 installed and launched on iPhone/iPad (actual app version readback),
MacBookPID96898 and Mac miniPID55792 (actual installed bundle/version/signature
readback). Includes prior UI work through immediate Ask DJ example submission.
Watch candidate embedded40331, but direct tunnel timed out and MacBook Watch
read failed Bluetooth authentication. Watch installation remains UNVERIFIED;
owner asked to unlock/place it near iPhone with wifi enabled. No pairing reset.
No physical audio acceptance or Core/backend repair included in app install.
See [installation record](feedback/APPLE_BUILD_40331_INSTALL_20261018.json).

## 2026-10-18 — Ask DJ examples send immediately /40331

Owner requested all empty Ask DJ example rows send automatically. Selection now
sets the existing localized draft and invokes the same composer send handler,
including submitted-question scrolling; hides keyboard rather than focusing the
draft. Capability/send/recording guards prevent blocked or duplicate sends.
No model, backend, prompt-content or speech-policy change. Not installed.
Native iOS build log: /private/tmp/djc-ask-examples-40331-ios.log.

## 2026-10-18 — First-play suggestion under active Session header /40330

Added localized existing Surprise me with new music prompt directly under
current Session card, styled like Ask DJ examples. Uses the exact composer send
and submitted-question scroll path; no client recommendations or new backend
request shape. Only before current/historical Session playback is known; owner-
scoped in-memory UI latch prevents return after pause/empty snapshots/reopening.
Opening DJMoments do not count as music. Hidden in archives/recovery/unavailable
state; no replacement of an existing draft and disabled during recording/send.
New lifecycle regression covers current/history/new Session/pause/snapshot loss/
authority reset. Targeted lifecycle test PASS0.136s; Swift package compiled
Mac UI/tests. Final ordinary iOS/embedded Watch40330 native build PASS. Five-
language validator PASS1287keys; git diff --check PASS. Not installed.
Logs: /private/tmp/djc-first-play-40330-{ios-final,tests}.log.
Source manifest: /private/tmp/djc-first-play-40330-manifest.json.

## 2026-10-18 — Server-owned opening DJMoment requested

Owner explicitly requests first DJ contribution narrates confirmed start mood,
persona and DJ presence, welcomes and wishes listening pleasure. Sent to existing
Core writer within authorized server Moment work. One durable opening per new
Session, retry/reconnect/reopen idempotency, start-settings snapshot retained,
separate from date/time metadata, localized, existing speech/consent policy.
No client-generated narration or invented music facts. Apple history decodes
moment_type as String; producer must confirm compatibility or publish fixture/
contract before consumer changes. Implementation and installed acceptance OPEN.

## 2026-10-18 — Nirvana playback failure / wrong English fallback OPEN

Owner09:13 screenshot: Dutch request/UI with English playback_failed bubble.
Exact text traced read-only to Core ask_dj._playback_failed_text; hybrid catch
omits request payload and helper consults text heuristic/runtime.device_language.
Apple profileConversationPayload sends currentRequestLocale from app language.
Owner explicitly authorized existing Core writer to repair both language and
Spotify-start root cause; evidence sent. Latest physical40324client log collected
but500line rotation no longer contains09:12request. No new playback, reset,
producer mutation or cosmetic client text replacement. Core readback: two
separate turns (Pearl Jam09:12, Nirvana09:13), not duplicate bubbles. Conversation
locale Dutch. Search yielded Eddie Vedder / Guns N Roses respectively, rejected
by existing artist identity check before playback. Core confirmed broad limit1 search as root; artist-qualified same-HA-dev search
returns correct artists. Core reports source repair with bounded10candidate
artist verification and confirmed-conversation locale, targeted tests PASS.
Golden and other playback routes still running; no installed repair established.

## 2026-10-18 — Saved-session overview search /40329

Added leading search toggle and shared glass search bar to Earlier Sessions.
Filters loaded canonical summaries (localized date/time/duration/status), supports
previous/next-result scrolling and clears on close or owner epoch change. Scope
is explicitly loaded sessions; no invented backend global-search contract. While
filtering, pagination requires Load more rather than eager background scanning;
normal infinite pagination returns when the query is cleared. Five-language keys
PASS1285; native iOS and Mac builds PASS. Native iPhone simulator demo
filter/no-results/close/reopen test PASS (23.956s test session), screenshot
exported for visual review. No installation.

## 2026-10-18 — Queue/playlist search at leading edge /40328

Owner requested search in a separate left toolbar item on Queue and Playlists.
Both now use topBarLeading on iOS/iPadOS and retain navigation on macOS, apart
from trailing connection/refresh. Search behavior and eligibility unchanged.
Not installed. Native iOS build log: /private/tmp/djc-search-leading-40328.log.

## 2026-10-18 — Ask DJ clear action in leading search group /40327

Moved the existing iOS/iPadOS clear-history action into the leading search
ToolbarItemGroup. Connection/refresh remain trailing, macOS already groups
search/clear at the left. Existing empty-history visibility, busy state,
accessibility and destructive confirmation unchanged. Includes preceding Dutch
DJ aanwezigheid label and6second saved-Session notice. Not installed.
Native iOS build log: /private/tmp/djc-ask-toolbar-40327.log.

## 2026-10-18 — Saved Session toast duration /40326

Only the confirmed saved-Session notice (real archive and demo) requests6seconds,
previously2. Shared notices keep their2second default; existing identity guard
prevents an older toast timer dismissing its replacement. Presentation only.
Native build log: /private/tmp/djc-session-saved-toast-40326.log. Not installed.

## 2026-10-18 — Confirmed Presence/Persona toolbar glyphs /40325

Owner requested menu-bar icons follow the selected Presence and Persona like
Mood. Both shared toolbar buttons now render the Core-confirmed selection glyph;
unknown values keep their existing generic icon. Persona welcome/popover/toolbar
reuse one enum glyph mapping. No mutation, optimistic state or backend contract
change. Native Mac and iOS/embedded Watch builds40325 and strict/deep signatures PASS.
Not installed; physical devices remain40324 (Watch unverified).
Build logs and exact276input manifest: /private/tmp/djc-toolbar-selection-40325.

## 2026-10-18 — iPad installation / Watch unavailable

Owner requested both additional devices. iPad40324 installed, actual bundle version
read back and launched. Watch candidate40324 is embedded in the iPhone app, but
physical Watch is unavailable and direct installation timed out20s; installation
and runtime version remain UNVERIFIED. No Watch audio acceptance claim.

## 2026-10-18 — Owner requested physical installation /40324

Installed ordinary40324 on iPhone (previous40315), MacBook (40314) and Mac mini
(40266). Actual bundle versions read back; iPhone launched, MacBookPID94661 and
Mac miniPID7787 run the installed app. Both Mac signatures strict/deep PASS.
Owner explicitly superseded preservation of the old iPhone baseline. USB profiling
remains deferred; no visual/audio acceptance or original404/widget/queue closure.
See [installation receipt](feedback/APPLE_BUILD_40324_INSTALL_20261018.json).

## 2026-10-18 — Native UI follow-up /40324

Reproduced native iPhone leading-toolbar overflow hiding connection/refresh in
first run; bounded44point compact row fixes it. Final iPhone6/6 + iPad1/1 with
portrait/landscape PASS and viewed screenshots. Full820testsPASS90.838s;15passive
regressions PASS. Added privacy-safe widget lifecycle/refusal diagnostics; no
widget repair claim. Signed iOS/Watch40324/source276hashes/locales PASS; not
installed, phone40315 preserved for tomorrow USB baseline. Core original404/widget
root cause, queue and physical Watch/audio remain open. See
[qualification](feedback/APPLE_NATIVE_UI_WIDGET_DIAGNOSTICS_40324_20261018.md).

## 2026-10-18 — Home widget rich data absent (OPEN)

Physical AppGroup cache: widget rich key absent, neutral Session present;
LiveActivity current track without art/Moment. Earlier widget authorization/read
were200. Existing authorized Core widget repair handoff updated; Core actively
investigates authorization loss. No client fix/install or physical acceptance.
See [widget evidence](feedback/APPLE_HOME_WIDGET_DATA_20261018.md).

## 2026-10-18 — Physical iPhone diagnosis /40323 layout correction

Phone still40315/PID17305. Repeated history404 reproduced in existing device log;
read-only HA-dev confirms current03:44Session ACTIVE/historyenabled/same owner.
Actual failed reference/refusal unresolved. Owner approved bounded existing-Core
repair handoff; message successfully sent. Client polling removed/reinserted error
layout every retry; red/green regression and full819testsPASS89.983s; ordinary
iOS/Watch40323build/276inputhashes PASS. Not installed, phone baseline preserved.
USB CPU/GPU profiling deferred to tomorrow by owner. Neither server repair nor
physical stutter acceptance claimed. See
[debug evidence](feedback/APPLE_IPHONE_SESSION_DEBUG_40323_20261018.md).

## 2026-10-18 — Unknown music availability when HA unreachable /40322

About shows grey Cannot verify when the HA route cannot confirm music
availability; cached/default backendAvailable no longer displays green Available.
Explicit reachable backend availability/unavailability retains its meaning; this
is not a Spotify OAuth status. Native iOS40322 build including Watch/widgets,
276input hashes,1283keys/five languages and diff validation PASS; not installed.
See [music status evidence](feedback/APPLE_MUSIC_AVAILABILITY_40322_20261018.md).

## 2026-10-18 — Duplicate Session outage text removed /40321

Active Session recovery keeps its status card and toolbar refresh. Removed the
separate Session error, history outage text and duplicate refresh beneath it;
matching outage no longer adds a timeline error block. Native iOS40321 build
including Watch/widgets and276input hashes PASS; not installed. See
[status evidence](feedback/APPLE_SESSION_STATUS_DEDUP_40321_20261018.md).

## 2026-10-18 — Session toolbar controls left /40320

Compact iPhone: More first, Mood/Presence/Persona/End left; Connection/Refresh
right; Search in More. Expanded iPad keeps direct actions left and status/refresh
right. Search opens after popover dismissal, retaining epoch/availability guards.
Ordinary signed iOS40320 build including Watch/widgets and276input-manifest check
PASS; UI test expectations updated but not executed; not installed. See
[toolbar evidence](feedback/APPLE_SESSION_TOOLBAR_40320_20261018.md).

## 2026-10-18 — Track Insight leading control block /40319

Share and Mood now form the far-left iPhone/iPad toolbar block; Connection and
Refresh stay right. Ordinary signed iOS/Watch40319 compilation PASS,276input
manifest checked; not installed. See
[toolbar evidence](feedback/APPLE_TRACK_INSIGHT_TOOLBAR_40319_20261018.md).

## 2026-10-18 — Watch Session display and native replay /40318 (PARTIAL)

Continued the existing Watch flow: current music first, latest admitted Moment
with Listen/Stop, collapsible complete flow cards, Session/card timestamps and
shared presence choices. Uses frozen Core local-settings3 source bc6e080e and
unaltered actual producer fixtures81318257; no invented backend wire or grants.
Own-Watch iPhone proxy revalidates owners before/after prepare; exact original
revision and expiry fences remain. Local opt-in/manual only; no refresh autoplay.
Signed ordinary iPhone/Watch40318 builds and strict signatures PASS. Physical
Watch currently unavailable; no installation, audible/Bluetooth or native UI
acceptance claimed. Core writer separately reports the same frozen producer
candidate installed on HA-dev; not independently deployment-qualified here.
See [Watch evidence](feedback/APPLE_WATCH_SESSION_TTS_40318_20261018.md).

The new Discover→Queue screenshot is also investigated: existing physical iPhone
log contains10 decoded/10 normalized/1 distinct track at03:27:17,03:27:28 and
03:32:34. Earlier view-ID fix does not close that producer-projection recurrence.
No content dedupe or backend mutation. Core-handoff question pending owner answer;
[bounded queue evidence](feedback/APPLE_QUEUE_DISCOVER_REPRO_20261018.json).

## 2026-10-18 — unlocked physical iPhone / Instruments transport blocked

Owner unlocked the phone: CoreDevice confirms unlocked, developer/DDI ready and
ordinary40315 running over localNetwork. Instruments still lists it offline on
both hosts and direct attach cannot find the verified live PID. USB-connect owner
question pending; no app update/settings change or physical performance capture.
See [physical preflight](feedback/APPLE_PHYSICAL_PROFILE_PREFLIGHT_20261018.json).

## 2026-10-18 — authorized MacBook source copy / verified Now Playing scroll40317

Owner explicitly approved source transfer;273files copied and final hashes checked
on the MacBook. Native build-for-testing and two verified native scroll/CPU runs
PASS; title moved374.67pt. Glass on/off scroll mean23.29%/21.38%CPU, peaks27.60%/25.73%;
short-run memory flat. Initial central-drag tests did not prove scrolling and are
excluded from this comparison. SwiftUI template unsupported Hitches, separate
instrument produced no SwiftUI data; no body/layout/FPS acceptance. Real cover,
long Session and physical iPhone/GPU remain open. Only simulator40317 installed;
no production performance fix/publication. See [profiling scope and evidence](feedback/APPLE_NATIVE_SCROLL_PROFILING_20261018.md).

## 2026-10-18 — on-device TTS client slice /40316 (PARTIAL)

Local Apple voice controls and bounded static sample implemented across phone,
iPad, Mac and Watch; actual OS metadata only, no shared Profile writes or autoplay
change. One native renderer, existing playback coordinator, Watch generation and
text_only/unknown-policy fences. Signed ordinary iOS40316/Watch build,272inputhashes and full811tests/10suites
PASS90.059s. Scope at [device TTS evidence](feedback/APPLE_DEVICE_TTS_40316_20261018.md).
At40316 Core Speech3 rejected local_on_device; no legacy/visible-text bypass,
local server synthesis or invented grant. Actual DJ contribution speech remains
blocked pending a frozen Core delta. Owner approved the Core handoff with “Akkoord”; the bounded request was sent
to existing chat “Pak VibeCast shared renderer op”. Producer delivery/Apple adoption
were pending at40316; the40318 Watch continuation above supersedes that dependency status. No new client install/publication.

## 2026-10-18 — VibeCast Apple lane resumed / native qualification

Existing owner-scanner slice resumed with sole writer/WIP preserved. Exact API94fbe118b3 generator read back; 10 portable binding/race tests and33 fresh Mac/native↔API/Node JOSE checks PASS. Private software keys remain process memory only. Isolated actual-app iOS diagnostic build/strict signatures PASS,40315/dev.djconnect.ios; no product dependency/runtime/install change. iPhone reachable but locked, unlock question pending; physical test NOT_RUN. API0.4-draft NOT_FROZEN/NO_RUNTIME_GO, genuine action/HA-route/independent review/joint TV gates remain open. See [receipt and scope](feedback/APPLE_VIBECAST_NATIVE_BINDING_20261018.md); local tooling at Tools/qualification/vibecast-native, logs/spec /private/tmp/djc-vibecast-native-20261018. No new App Attest call/key, source push or merge.

## 2026-10-18 — native CPU/memory/Metal profiling (OPEN)

Dedicated iPhone17Pro/iOS27.0 simulator on MacBook; actual Time Profiler/Metal traces and native short-session scroll benchmark recorded. Three scroll rounds average2.563s appCPU/10.485s wall clock,65.94MB physical peak.94.45%weighted CPU samples main thread; no measured runaway background worker or growing heap in this short demo. NowPlaying idle9.01%CPU/37M; dedicated NowPlaying scrolling and real-art/long-session repro remain pending. GPU rows belong to simulator host processes, not a qualified iPhone GPU/FPS result. Physical iPhone Instruments offline. At that baseline, source transfer was rejected pending consent. Owner now explicitly approved; the273-file40317 transfer and verified scroll comparison above supersede that blocker. Existing remote UI hashes match the measured current three UI files; no new install/publication. See [profiling evidence](feedback/APPLE_NATIVE_SCROLL_PROFILING_20261018.md).

## 2026-10-18 — Live Activity grey Spotify mark /40315

Grey rectangle matches the Spotify attribution slot. Replaced widget's3432×940px source asset with real70pt1x/2x/3x prepared images from the unchanged shared logo; bounded cover image decoding to actual display scale. Existing attribution, links and leases unchanged. Native iOS build/signature and17targeted tests pass; iPhone40315 installed/read back, normal launch Locked; physical ActivityKit rendering not yet accepted. See [evidence](feedback/APPLE_LIVE_ACTIVITY_GREY_LOGO_40315_20261018.md). MacBook40314/iPad40290 unchanged.

## 2026-10-18 — session scroll performance / installed40314

MacBook and iPhone40314 installed/read back; MacBook running. Optimized repeated history date parsing, visible artwork prefetch checks, collection allocation and static card timers. Generic HTTP-cacheable artwork now reuses background-prepared images/tints in a memory-pressure-sensitive cache (60/32MiB limits, original HTTP expiry); protected no-store SessionMedia remains view-local and never gains offline storage. Core permission question for a future bounded memory-reuse contract is pending; no message sent. Targeted9/full806tests PASS; component date benchmark improved, but physical scroll CPU/FPS remains unmeasured. See [evidence](feedback/APPLE_SESSION_SCROLL_PERFORMANCE_40314_20261018.md). Mac40312 recovery preserved; iPad40290 unchanged.

## 2026-10-18 — gesture overlays / installed iPhone40313

Gesture feedback is now a centered overlay painted above the native tap surface and image/glass crossfade, with geometry driven solely by the cover. Prior tap mappings, playback guards and feedback semantics preserved. Native iOS build/signature/install and independent40313 readback passed; launch blocked because the iPhone was locked. Full803 Swift tests/10 suites PASS91.050s; native gesture visibility remains unaccepted. The preceding UI follow-ups are included on iPhone; MacBook40312 and iPad40290 remain unchanged. Core four-level dosing is still a separate producer delivery. See [evidence](feedback/APPLE_ARTWORK_GESTURE_OVERLAY_40313_20261018.md).

## 2026-10-18 — large album artwork fade

DJ Session and Now Playing use a shared 0.45s opacity crossfade when replacement pixels are decoded; the old cover remains during loading and the glass color changes with the pixels. Removed Now Playing's metadata-triggered renderer remount/scale animation. Reduce Motion is respected. See [qualification](feedback/APPLE_LARGE_ARTWORK_FADE_20261018.md). No new installed build.

## 2026-10-18 — queue client rendering identity

User confirmed one actual queued item. Corrected the client identity path: queue position now identifies each rendered row and search target; normalization guarantees unique IDs despite metadata variants and reserved suffixes. No repeated-track removal. See [regression evidence](feedback/APPLE_QUEUE_RENDER_IDENTITY_20261018.md). Old-code regression failure confirmed; corrected native compilation and 25 focused tests pass. No new installation or physical acceptance.

## 2026-10-18 — Mac composer expands on popover dismissal

Mac composer expansion now requires deliberate editing intent as well as focus, so native popover focus restoration cannot change the bar height. Mouse/typing/explicit question insertion still expand; draft and selection remain mounted. See [diagnosis and checks](feedback/APPLE_MAC_POPOVER_COMPOSER_FOCUS_20261018.md). Native mouse-cycle regression added, not yet executed; installed build remains 40312.

## 2026-10-18 — small artwork glass tint

Small admitted Session/history covers now use the large-cover glass treatment and sample the already admitted pixels. No additional fetch/cache or lease renewal; tint clears with the image. See [evidence](feedback/APPLE_SMALL_ARTWORK_TINT_20261018.md). Native compilation and 18 targeted tests passed; no new installation.

## 2026-10-18 — four presence options (in progress)

See [presence handoff](feedback/APPLE_PRESENCE_FOUR_OPTIONS_20261018.md). Welcome and active selectors now offer Alleen muziek / Af en toe / Gebalanceerd / Presentator. Praatgraag remains historical decode-only. Core acknowledged the explicit server-side dosing and migration request; producer contract/pin and active capability adaptation remain pending. No new installation claim.

# Latest installed follow-up — build40312 unified choices and rapid-selection recovery

Welcome and active Session mood/presence/persona use one selector style matching
the original welcome mood row. Fast unsent gestures coalesce for250ms; no-op
choices do not write. A confirmed current-settings read clears stale conflict UI;
real rejection is shown once as an existing transient notice, while unknown and
failed outcomes remain explicit and unreplayed. Saving overlays existing geometry.
29 focused tests PASS1.332s; final full801tests/10suites PASS90.958s; five-language
1261-key and diff checks PASS. iPhone ordinary signed40312 installed/read back;
launch blocked by locked phone. Mac native compile on MacBook passed unsigned,
then locally signed with unchanged rights and validated original profiles;
strict signature/install79-entry manifest/independent40312 readback/process PASS.
iPad unchanged40290. No physical rapid-touch/layout acceptance claim. Local
follow-up remains unpublished. See
[selector and root-cause evidence](feedback/APPLE_UNIFIED_CHOICES_CONFLICT_20261018.md).

Core handoff remains separate: local ingress, widget producer and narrative
settings-change Moments have no new installed qualification. A cleanup/resource
status handoff was automatically rejected; owner permission is pending, so no
resource message was sent. Core files/services/snapshots remain unchanged.

# Earlier installed follow-up — MacBook and iPhone40311 Ask DJ failure UX

Pending/failed Session questions now use normal right-aligned chat bubbles with
original user metadata; separate left delivery-status bubble replaces combined
full-width cards. Per-turn Ask DJ error copy in five languages replaces misleading
history wording for submit failures. Network/409/hybrid/authority behavior remains
distinct; original payload/identity/date preserved and no automatic replay.
Three tests/seven cases PASS0.715s; native signed Mac/iOS builds/signatures/
ordinary-product/brand-key checks PASS. iPhone installed/read back40311, launched.
Owner explicitly authorized MacBook update; mbpro-peter installed/read back40311,
all79 manifest entries match, strict signature and launch/process PASS; old app
retained. This installs the earlier accumulated Mac toolbar/layout fixes too.
iPad unchanged40290. Physical viewport and original backend failure cause remain
separate. See [Ask DJ failure evidence](feedback/APPLE_ASK_FAILURE_CHAT_UX_20261018.md).

# Latest built follow-up — Mac40310 toolbar edges

All existing Mac screen refresh actions now trail connection at the right edge.
Feature search/mood/voice/etc stay leading; root sidebar toggle and Session
VibeCast each use native fixed separation. No added refresh operations. Native
signed Mac40310 build/strict signature/ordinary-product/diff/work-register checks
PASS. Not installed under standing scope; physical cross-screen/overflow/fullscreen
acceptance remains separate. iPhone40309/iPad40290/MacBook40292 unchanged. See
[Mac toolbar policy](feedback/APPLE_MAC_TOOLBAR_EDGES_20261018.md).

# Latest follow-up — build40309 direct Mac voice control

Removed duplicate output/voice picker labels while retaining accessibility names.
Mac direct DJ-voice speaker button now joins refresh/search/mood/presence/persona
in one group; VibeCast is a separate item. Existing popover scope/write fences
unchanged. Native Mac/iOS builds/signatures/ordinary-product/diff checks PASS;
iPhone install, independent40309 readback and launch succeeded. Mac40309 built
but uninstalled under standing scope; no physical Mac viewport claim. See
[direct voice toolbar](feedback/APPLE_DIRECT_VOICE_TOOLBAR_20261018.md).

# Latest installed follow-up — iPhone40308 duplicate connection detail

Mac/iOS connection cards omit the generic unreachable detail that repeats the
status heading, retaining backend recovery and other actionable messages. No
connection/pairing state changes. Native signed build/signature/ordinary-product
and diff checks PASS; iPhone install, independent40308 readback and launch
succeeded. Mac remains source-only under standing installation scope. See
[connection detail](feedback/APPLE_CONNECTION_DUPLICATE_DETAIL_20261018.md).

# Latest installed follow-up — iPhone40307 welcome settings

Presence and Persona added to the idle Session start card alongside mood. Uses
confirmed backend Profile defaults, allowed choices, existing patch/readback and
native selector. Migration opens existing six-field review; no local persistent
settings. Start blocked during saving/uncertain outcomes. Three Profile contract
tests PASS0.006s; native signed build/signature/ordinary-product/diff PASS;
iPhone install, independent40307 readback and launch succeeded. iPad/Mac source
only; no physical viewport acceptance claimed. See
[welcome choices](feedback/APPLE_WELCOME_PRESENCE_PERSONA_20261018.md).

# Latest installed follow-up — iPhone40306 idle Session tagline

Removed the synthesized loose Nothing Playing label for missing/blank titles.
The quiet Session bubble shows the localized brand tagline when playback is not
playing; ordinary playing/paused/recovery/Moment presentation retains its branch.
Diff/five-language brand validator/native signed build/strict signature/ordinary
app checks PASS; iPhone install, independent40306 readback and launch succeeded.
No physical viewport acceptance claimed. See
[idle Session copy](feedback/APPLE_IDLE_SESSION_TAGLINE_20261018.md).

# Latest installed follow-up — iPhone40305 composer spacing

Session and standalone Ask DJ composer now use8pt bottom padding with keyboard
hidden, matching iPad instead of21pt. Measured question-scroll reservation follows
the same value. Native signed build/signature/ordinary-product checks PASS;
iPhone install, independent40305 readback and launch succeeded. Physical viewport
acceptance remains separate; iPad/Mac unchanged.
See [spacing evidence](feedback/APPLE_COMPOSER_MENU_SPACING_20261018.md).

# New request — narrative Moment after settings change

Owner explicitly authorized the existing Core writer to add one durable narrative
Moment after each confirmed actual active-Session mood/persona/presence change,
including shared Profile settings. Handoff delivered; implementation and installed
acceptance OPEN. Preserve idempotency, conflict/uncertain-write and music-only
speech fences. No local synthesized copy or new build.
See [requested behavior](feedback/APPLE_SETTINGS_CHANGE_MOMENT_20261018.md).

# Latest follow-up — iPhone40304 widget current music layout

Widget now presents current music before the latest admitted contribution,
including both on small widgets; large current cover104pt. Native signed40304,
strict signature and ordinary-product checks PASS; iPhone installation and
independent40304 readback PASS. No physical widget acceptance claimed. Actual
pre-update passive cache contained current metadata but no cover/contribution;
backend passive source/deadline/background delivery investigation was explicitly
authorized and delivered to the existing Core writer. No client rights/expiry
bypass. See [widget evidence](feedback/APPLE_WIDGET_CURRENT_CONTENT_20261018.md).

# Latest diagnosis — MacBook local transport rejected

MacBook remains installed40292. Its configured LAN origin is reachable but the
transport-context POST returns HTTP426 `transport_security_required` before
authentication; saved local URL remains correct. Ordinary local HTTP success
and external hybrid Session transport explain the brief green-to-external
presentation. Backend direct-local ingress acceptance remains OPEN; no fabricated
qualification, client bypass, pairing reset or new install. Core-thread handoff
was initially rejected by automatic approval review, then explicitly authorized
by the owner and successfully delivered to the existing Core writer. Repair and
installed local acceptance remain pending. See [MacBook diagnosis](feedback/APPLE_MACBOOK_LOCAL_TRANSPORT_REJECTION_20261017.md).

# Latest installed follow-up — iPhone40303 compact playback card

Removed duplicate artwork-level Spotify attribution where the enclosing card
already supplies its footer. Observed playback on iPad/Mac now places artwork
left and heading/title/artist/album right, with timestamp/source links/one logo
below; structured fields retain projected search highlights. Native Moment cards
also avoid repeating their existing Spotify footer. Grant/source/expiry and
playback authority unchanged. Highlight regression PASS0.001s; native signed
iOS40303/strict signature/ordinary-product checks PASS. iPhone installed/read back
40303 and launched. iPad40290/MacBook40292 unchanged per standing installation
scope, so their new wide layout is not installed/visually accepted yet. See
[compact-card evidence](feedback/APPLE_COMPACT_PLAYBACK_CARD_20261017.md).

# Earlier installed follow-up — iPhone40302 submitted-question positioning

Session and standalone Ask DJ now position a submitted question immediately above
the measured input-bar safe-area reservation. Session uses one bottom-anchored
scroll controller and follows pending/retained/current-only identity; standalone
Ask DJ follows the submitted UUID instead of generic feed-top requests. Added
leading scroll room for short feeds; manual scrolling/search/navigation release
automatic question following. No backend request/replay or payload change.
Identity regression PASS0.007s; native signed iOS40302/strict signature/ordinary-
product checks PASS. iPhone installed/read back40302 and launched. Physical
viewport/keyboard acceptance and a new full-suite PASS are not claimed.
iPad40290/MacBook40292 unchanged. See
[scroll evidence](feedback/APPLE_SUBMITTED_QUESTION_SCROLL_20261017.md).

# Earlier installed follow-up — iPhone40301 inline listening status

Quiet Session status now places the static icon and text in one horizontal row,
wrapping text when needed instead of truncating. Recovery spinner remains absent.
Swift parse/diff/native signed iOS40301/strict signature/ordinary-product checks
PASS; iPhone installed/read back40301 and launched. No physical viewport or new
full-suite claim. iPad40290/MacBook40292 unchanged. See
[UI evidence](feedback/APPLE_HISTORY_PLAY_LAUNCH_20261017.md).

# Earlier installed follow-up — iPhone40300 separate Now Playing cards

New open TTS finding: existing iPhone logs around21:21 show contract3 prepare
unavailable reason `source_processor_not_qualified` for the reported text-replay
failure. Audio fetch/output are not reached by that branch. Core owns live dev
source/provider qualification; no client grant/text/provider bypass. See
[TTS diagnosis and dependency](feedback/APPLE_TTS_TEXT_REPLAY_20261017.md).
No newer install or positive replay acceptance is claimed.

Artwork is a standalone glass card above a separate track/playback card on
iOS/iPadOS and in the macOS summary. Shared artwork width matches Session:
iPhone full available width with20pt edge insets, iPad/Mac270pt. Playback actions
and control logic unchanged. Swift parse/diff/native signed iOS40300/strict
signature/ordinary-product checks PASS; iPhone installed/read back40300 and
launched. Physical layout acceptance not inferred. No new full-suite claim.
iPad40290/MacBook40292 unchanged. See
[UI evidence](feedback/APPLE_HISTORY_PLAY_LAUNCH_20261017.md).

# Earlier installed follow-up — iPhone40299 stable artwork border tint

Session/Now Playing album glass frames seed their first frame from a shared
synchronous URL-bound color cache. Removed per-mount tint clearing/animation and
the nil URL gate while the image loads. Entries inherit HTTP cache expiry and
exclude no-store/no-cache/max-age=0, bounded to180 colors without decoded images.
Four tests/six cases PASS0.043s; native signed iOS40299/strict signature/ordinary-
product checks PASS. iPhone installed/read back40299 and launched; no physical
screen-switch acceptance inferred. iPad40290/MacBook40292 unchanged. See
[UI evidence](feedback/APPLE_HISTORY_PLAY_LAUNCH_20261017.md).

# Earlier installed follow-up — iPhone40298 queue diagnostics

Owner's single-item/duplicated Volbeat Queue report is explicitly HA-dev and
remains OPEN: current Core receipt has20distinct positions/repeat off, without
reproducing the original snapshot. Client decode/projection replaces arrays;
six queue regressions PASS0.138s. Added count-only explicit queue response logs,
preserving all existing positions; no blanket dedup or original-cause fix claim.
Native signed iOS40298/strict signature/ordinary-product checks PASS; iPhone
install/independent40298 readback/launch PASS. iPad40290/MacBook40292 unchanged.
See [queue evidence and dependency](feedback/APPLE_QUEUE_SINGLE_ITEM_20261017.md).

# Earlier installed follow-up — iPhone40297 session metadata

Active/archived timelines show a start metadata bubble at their oldest end,
using the matching backend Session started_at, local time and a full localized
date. Five-language regression cases including DST/invalid timestamps PASS;
native signed iOS40297, strict signature/ordinary-product checks and iPhone
install/independent40297 readback/launch PASS. No physical viewport acceptance
or new full-suite claim. iPad40290/MacBook40292 unchanged. See
[UI evidence](feedback/APPLE_HISTORY_PLAY_LAUNCH_20261017.md).

# Earlier installed follow-up — iPhone40296 Ask DJ artwork

Rich Ask DJ images/history/action thumbnails now share the artwork cache and
response projection follows the confirmed HA origin for public image_proxy URLs.
Existing no-store/expiry/authority boundaries remain intact. Signed iOS40296
build/strict signature/ordinary-product checks PASS; iPhone installed/read back
40296 and launched. Full788tests/10suites PASS89.528s with explicit no-parallel;
initial concurrent failures retained, not a parallel-suite PASS. Physical reopen
acceptance and the original runtime HTTP cause remain unproven. iPad40290 and
MacBook40292 unchanged. See [UI evidence](feedback/APPLE_HISTORY_PLAY_LAUNCH_20261017.md).

Open existing-lane follow-up: Ask DJ submit currently mislabels generic failures
as history unavailable. Correct five-language question/connection wording with
HTTP502/503/decode/transport/pre-HTTP scope tests, preserving authority withdrawal,
409 context, frozen client_message_id and uncertain-effect/retry rules. No claim
that wording correction establishes the original Armin transport cause. This
follow-up is queued; no implementation or new Core writer in the artwork fix.
Core lane subsequently reported the same owner-visible failed-submit wording for
“wie is de artiest” and “wie zijn de zangers”; include both alongside the Armin
question in this existing mapping/diagnostic follow-up. The Armin report is
explicitly HA-dev. Original per-question HTTP causes remain unproven; Core owns
live dev investigation. No user-turn replay, deployment or additional writer is
authorized merely by this report.

# Earlier source follow-up — iPad saved-session row width

Saved-session rows now fill the iPad List width, retaining20pt edge insets;
removed the1000pt cap on iPad only. See the40295 entry in
[UI follow-up evidence](feedback/APPLE_HISTORY_PLAY_LAUNCH_20261017.md).
No iPad installation/physical landscape acceptance; latest installed versions
at that snapshot were iPhone40294, iPad40290, MacBook40292.

# Latest installed follow-up — iPhone40294

DJ-session status cards now show status text without the decorative disc in the
quiet card or the progress spinner during recovery. Text and card styling remain.
Native signed iOS40294 build, strict deep signatures, ordinary-product checks,
iPhone install/independent40294 readback/launch PASS. No physical viewport
acceptance or new full-suite claim. iPad/MacBook not updated. See the40294 entry
in [UI follow-up evidence](feedback/APPLE_HISTORY_PLAY_LAUNCH_20261017.md).

# Earlier installed follow-up — iPhone40293

Only iPhone updated for now, per the owner's explicit latest direction. Signed
ordinary40293 build/signatures/install/independent version readback/launch PASS.
Ask DJ composer with Glass effects off or Reduce Transparency now uses the dark
opaque surface/subtle border; removed full-opacity mood color. No physical
viewport acceptance or new full-suite PASS is inferred. iPad last40290, MacBook
40292; no further update attempted on either. See the40293 entry in
[UI follow-up evidence](feedback/APPLE_HISTORY_PLAY_LAUNCH_20261017.md).

Earlier source/install snapshots retain their evidence bindings below.

# Latest installed follow-up — 40292

MacBook (mbpro-peter) and iPhone ordinary40292 installed, independently version-
read back and launched. MacBook was40208; complete remote bundle manifest and
strict signatures match; normal quit/install succeeded and old app is retained.
Mac mini unchanged. iPad update failed CoreDevice4016; last confirmed40290.

Session headers now route public proxy artwork through the confirmed HA origin
like Now Playing, retaining vinyl only as missing/failed-image fallback. Source
9d54967: full787Swift tests/10suites PASS89.600s; signed native Mac/iOS PASS.
The first full run's obsolete game-cap source assertions were replaced by an
executed layout-space test. Exact Git-archive qualification excludes untracked
workspace duplicates, which remain preserved. Physical cover/UI acceptance,
Core history replay producer and public merge/formal Finalization remain open.

See [40292 routing and MacBook evidence](feedback/APPLE_ARTWORK_ROUTE_MACBOOK_40292_20261017.md).
The following sections are earlier installed snapshots.

# Current local Apple follow-up — iPad40290

Current ordinary versions: iPad40290 and iPhone40291, installed/read back/launched.
The iPhone active-Session connection/search group now sits separately at leading.
The owner explicitly approved the iPhone catch-up from40267 after the vinyl-card
report; the same existing shared artwork glass wrapper covers the placeholder.
The build includes all iPad
Session toolbar actions directly visible (no More menu), equal
selector icon cells for presence/persona/mood and shared
purple toggle styling, including the
compact connection popover/keyboard presentation correction, following
Discover width40284, fixed Logs title40285 and games available-space40286.
Each has its own signed native build receipt in the history/launch report below;
physical viewport acceptance is not claimed. The786test result below binds
the earlier clear-state source, not these later presentation changes.

Protected consolidation PR111/112 are merged; main is f6b0a71b. Current local
follow-up branch `codex/apple-history-row-play-launch` contains98eda79:
Ask DJ clear preserves the admitted Profile; neutral system launch; explicit
history actions render inline. Full786Swift tests/10suites PASS87.359s. Signed
ordinary iOS build/signatures PASS; only iPad installed/read back40283 and
launched. Real-user chat clear was not repeated; no physical replay acceptance.
Core must still supply history replay actions. Public source merge and formal
source Finalization for this follow-up are not claimed. Original369-file source
formal evidence remains dependent on the named central collector pagination fix.

See [clear recovery](feedback/APPLE_CHAT_CLEAR_RECOVERY_20261017.md) and
[history/launch](feedback/APPLE_HISTORY_PLAY_LAUNCH_20261017.md). Previous
handoff snapshots below retain their original evidence bindings.

# DJConnect iOS/macOS/watchOS App Handoff

Actuele Apple-lanestatus (17okt2026): [integrale open-werk- en acceptatiematrix](feedback/APPLE_OPEN_WORK_20261017.md) en [requirementniveau/afmeldingen](feedback/APPLE_REQUIREMENT_ACCEPTANCE_20261017.md). Historische done-notities hieronder sluiten nieuwe Session/Speech/Settings/Watch-acceptatie niet af.

## Mainconsolidatie — 17 oktober 2026

[Bron-PR111](https://github.com/pcvantol/djconnect-app/pull/111) is beschermd
gemerged als `b47d17a3bd7aade005787206785578bee585096b`; kandidaat
`0688cf6529358ba72660cb5c0da28d296df84463` heeft exact dezelfde tree
`422cf1173bc48e660931b0a5beb5f4264a03b973`. Alle premergechecks en officiële
Owner Authorization PASS. Nieuwe portable784tests/10suites PASS89.368s; native
784tests/10suites PASS82.596s; unsigned iOS/macOS inclusief Watch/widgets PASS.
Drie CI-testcorrecties veranderen geen appgedrag en behouden alle assertions.

Beide oorspronkelijke checkouts staan schoon op dit main. Hun18/155WIPpaden
zijn behouden in stashes en onafhankelijk hashgecontroleerde herstelarchieven;
Gitbundles bewaren alle oorspronkelijke refs. Drie exact bewezen oude lokale
branches zijn verwijderd, nul worktrees. Oude remote branches zijn weg; de
tijdelijke Finalizationbranch blijft apart open zolang PR112 draft is. Het
ongeïnstalleerde Base-launchscreenexperiment en twee dubbele Xcodeprojecten
blijven herstelbaar buiten de merge. Gewone iPad40282/iPhone40267/Mac40266
blijven ongewijzigd; geen nieuwe installatie, HA-deployment of distributie.

Main CI39061192756 inclusief native coverage PASS. Coverage- en runnerartefacten
zijn onafhankelijk gehasht; coverage noemt exact bron-mainb47d17a3. Formele
reconciliatie39061762379 FAILED vóór publicatie door een concrete centrale
producerfout: de ongepagineerde commitread levert300 van369bestanden. Alle
369bestanden komen bij volledige gepagineerde GitHub- en lokale Gitreadbacks
exact overeen. De bestaande Core-writer heeft de collectorcorrectie ontvangen;
geen status of bewijs wordt omzeild. Aparte documentaire Finalization blijft
pending totdat de juiste exact-main evidence is gelezen. De poging deze run te
stoppen was te laat; de duurzame builder had het niet-gekwalificeerde rapport
al terecht geweigerd. Er is geen ongeldig rapport gepubliceerd.

TDE-observeworkflow PASS, maar de analyse zelf FAIL/repositoryqualification
FAILED met3CRITICAL/174HIGHcomplexiteitsbevindingen. Deze blijven open voor
triage/refactor; geen baseline-regressie- of runtime/crashconclusie. Nieuwe
onafhankelijke volledige technische/UXreview op deze gehele kandidaat is niet
uitgevoerd. De23actieve functionele/acceptatiepunten blijven open; bounded
source-inclusie sluit geen LAN/WS, TTS, Profile, VibeCast, OS-surfaces, Watch,
productiepush, performance of fysieke acceptatie af.

Zie [bronconsolidatie](feedback/APPLE_MAIN_CONSOLIDATION_20261017.md) en
[exacte bronreadback](verification/apple-main-consolidation/source-main-readback.json).

## Opruiming40282 — 34 ongebruikte componenten verwijderd

Alle 28 concrete roots uit het legacyassessment plus zes transitieve helpers zijn
verwijderd, naast een leeg toolbarbestand en nooit gevulde WS-cache. Actieve
TTS/settings3/Watch/pairing en publieke API/migraties blijven behouden. Volledige
784 Swift-tests in tien suites PASS (92.272s); signed iOS/macOS inclusief
Watch/widgets, source/stage, ordinary copy en signatures PASS. Gewone iPad40282
geïnstalleerd en onafhankelijk teruggelezen; iPhone40267/Mac40266 behouden,
Mac40282 alleen kandidaat. Eén worktree/drie branches zonder bewezen veilig
merged/stale kandidaat: nul deleties.

Eerste echte fysieke idlecollectie40282: drie samples, circa 57–58 MB piekgeheugen
en 0.113–0.557 CPU-seconden per circa 4.93s. Geen performancewinst-, p95-, soak-
of crashvrijclaim. DJ-stem-menutests blijven twee failures per run, ook bij
landscape en vers proces. Volledige capture toont pop-out binnen beeld; remote
AX/hit-testprobleem nog te onderscheiden van echte refreshdismissal. Geen
fysieke twaalfsecondenstabiliteitclaim. Zie [retirement en bewijsgrenzen](feedback/APPLE_LEGACY_RETIREMENT_20261017.md).

## iPadmoodranden40280 — gewone fysieke viewports bevestigd

De buitenste root achter UIKit en de Sessionwrapper volgen de bevestigde mood.
Statusbalk en onderste systeemrand kleuren door; Meer/geenactieveSession gebruiken
de gewone canvas. Nativebuild/signatures/source-stage/copyPASS; iPad40280install
vóór/na onafhankelijk teruggelezen. Externe screenshotprobe1PASS15.959s; volledige
EnergieSessionbeelden liggend/staand én Meer bekeken: groene randen, correcte
merkcanvas na tabwissel. Geen mood-/backend-/playbackactie; oriëntatie hersteld,
eigen runner verwijderd. De viewports bevestigen ook vinyl-in-kaart en TTSknop
rechtsonder; geen audio-/downloade2e.2bestaande renderchecks6gevallenPASS0.040s.
Zie [oorzaak en echte bewijsgrenzen](feedback/APPLE_IPAD_SESSION_MOOD_EDGES_20261017.md).

## Afspeelknop40279 — rechtsonder, gelijke rechter-/ondermarge

Contextvraagruimte reserveert alleen inhoud; de speechfooter gebruikt de volle
breedte. DJ-conversatiepadding14pt rechts/onder; gedeelde rij bottomaligned zodat
statusregels de knop niet omhoog duwen.4bubblelayout-renders met geïnjecteerde
44ptfooterPASS, twee bestaande rendertests/6gevallenPASS0.041s. Gewone signed
native iOS/macOSincl.Watch/widgets/source-stage/copy/signaturesPASS; iPad40279
geïnstalleerd/teruggelezen. Geen nieuwe fysieke audio-/screenshotacceptatie.
Zie [oorzaak/fix/bewijsgrens](feedback/APPLE_SPEECH_BUTTON_CORNER_20261017.md).

## Vinylkaart40278 — dezelfde album-artvorm met en zonder hoes

De glass-kaart zat alleen rond geladen pixels. Nu deelt de vinyl-/laad-/foutfallback
hetzelfde albumframe, met gelijke maat, inset8, afgeronde hoeken en rand. De
Glaseffectenpolicy blijft leidend; geen extra tintdownload zonder geladen hoes.
2bestaande rendertests/6gevallenPASS0.041s; handmatige vierkante renders op3maten
PASS en358ptPNGbekeken. Gewone signed iOS/macOSincl.Watch/widgets en bron/stage/
copy/signaturesPASS. GewoneiPad40278install/versiereadbackPASS; iPhone40267 en
Mac40266behouden. Geen nieuwe fysieke artworkpixelclaim of volledige UIclosure.
Zie [fix en bewijs](feedback/APPLE_VINYL_ALBUM_CARD_20261017.md).

## Glaseffecten40277 — gewone iPadinstall en toggle/persistentie bevestigd

Eén apparaatgebonden schakelaar onder Instellingen → App vervangt app-eigen
glass/materials door dekkende vlakken, direct en zonder herstart. De keuze is
lokaal; systeem Verminder transparantie blijft leidend.1257localechecksPASS,
2render-/vinyltests met6gevallenPASS0.058s; gewone signed iOS/macOS inclusief
Watch/widgets en source/stage/copy/signaturesPASS. GewoneiPad40277install en
onafhankelijke versieteruglezingPASS. Externe UItestPASS33.872s controleert
omschakelen, gewoneherstart, persistentie en herstel oorspronkelijke waarde;
eigen runner opgeruimd. Private screenshots tonen dekkende kaarten, maar zijn
rechts afgesneden: geen complete layoutacceptatie. iPhone40267/Mac40266behouden.
Geen gemeten oudere-deviceperformancewinst; algemene profiling blijftopen.
Zie [ontwerp en bewijsgrenzen](feedback/APPLE_GLASS_EFFECTS_PREFERENCE_20261017.md).

## Automatische surfaces40268–40272 — 17 oktober 2026

De extra pop-out/twee toggles zijn weg. Bevestigde actieve Session/settings3 en
OS-widgetplaatsing/Live Activity-toestemming sturen automatisch onafhankelijke
grants. Historysuspension, settings-first startup, exacte Activityinstancefence
en onafhankelijke neutrale/veldexpiry zijn hersteld; geen onzeker-write-replay,
nieuwe poller of bronleaseverlenging.

26gerichte testsPASS2.533s; signed gewone iOS/macOS40272 inclusiefWatch/widgets,
strictdeep signatures en bron/stagehashesPASS. GewoneiPad40272 geïnstalleerd en
teruggelezen; SDK active/count1, twee gewone reads zonder daarna app-einde,
actuele neutralcache/widgetmuziek. De huidige LiveActivityrichcache ontbreekt,
0art/pixels; eerdere40269/40271 hadden beide richstores met muziek/bijdrage.
Geen fysieke OS-pixel- of duurzame background-PASS. Vier tijdelijke SDK-
authorizationfouten tijdens startup vóór de geaccepteerde start zijn behouden.

Owner kiest nu alleeniPad: iPhone40267 behouden, Mac40266draait/ordinary40272gereed,
Watchalleenmeegebouwd. Owning Corebeleid/SYNC/verse rijke bron/achtergrondlevering
blijft afhankelijkheid: v1 explicit_consent_required=true, background_delivery=false,
max120s. Consumerimplementatie bounded afgemeld; parentpassive blijftPARTIAL.
Zie [ontwerp/bewijs](feedback/APPLE_PASSIVE_AUTOMATIC_SURFACES_20261017.md) en
[integrale uitvoering](feedback/APPLE_INTEGRAL_EXECUTION_20261017.md).

## UI-followup40267 — 17 oktober 2026

De volledige regel 'Demo · Voorbeeldsessies, geen echte luistergeschiedenis'
is verwijderd uit actieve sessies, eerdere sessies en het startscherm. Geen
lege banner of gereserveerde teksthoogte. Gedeelde iPhone/iPad/Mac-weergave,
dus dezelfde wijziging in alle talen. Bestaande demo-UI-test verwacht nu dat de
banner ontbreekt. Native signed iOS/macOS-builds en 1255 lokalisatiesleutels PASS;
geen nieuwe fysieke UI-test of volledige regressierun. Installatiestatus staat
in de integrale uitvoering en de werkregisters.

## UI-followup40266 — 17 oktober 2026

Demo toont de bestaande vinylplaat in Speelt Nu, de sessieheader en Track
Insight. Eén gedeeld SwiftUI-bronbestand voor iPhone/iPad/Mac en Watch;
Watchminiatuur en grote hoespreview sluiten aan. Geen externe demohoes nodig.
Een breedtevoorstel zonder hoogte reserveert een vierkant. Draaien volgt
playback, sceneactiviteit en Reduce Motion.

Renderregressie PASS op 54/190/270/358pt (4 gevallen, 0.025s); gedeelde render
visueel bekeken. Gewone signed iOS/macOS-builds 40266, inclusief Watch, PASS.
Mac mini 40266 geïnstalleerd en exact manifest/signature teruggelezen; vorige
40258 herstelbaar bewaard en gewone app heropend. Zie integrale uitvoering
voor grenzen. Ook iPhone/iPad40266 installatie/readback PASS; geen verse
Watchhardwareclaim.

## UI-followup40265 — 17 oktober 2026

De actieve lokale Bluetoothuitvoer toont de door iOS gemelde apparaatnaam in
Speelt Nu, de sessieheader en de uitvoerlijst. Eén centrale route-observer
verwerkt aansluiten, ontkoppelen en hervatten; apparaat-ID en backendnaam blijven
ongewijzigd. Geen naam bij een andere/cached uitvoer, onduidelijke route of
conflicterende lokale aliassen. Geen audioactivatie of claim over audiokwaliteit.

7 gerichte tests PASS (0.484s); signed native iOS/macOS-builds en signatures PASS.
Echte iPhonecontrole met actieve AirPods PASS (1.144s): één Bluetoothroute,
matching actieve iPhone-inventarisrij en beide weergaven gelijk aan routenaam.
Eerdere controles zonder actieve route of tijdens omschakelen waren SKIP;
geen pixel-/tikacceptatie geclaimd. Gewone 40265 hersteld na XCTest; iPhone/iPad
installatie en readback PASS. Mac mini blijft 40258; gewone 40265 staat gereed.
De 762 volledige regressies horen bij 40258; bredere productacceptatie blijft open.

## UI-followup40264 — 17 oktober 2026

Adreslabel zonder Actief in5talen.1255keys en compiledlocalevaluesPASS;
signed native builds/iPadinstall/readback40264PASS. Mac mini40258/40264gereed;
iPhone unavailable. Overige product-/hardware-/bronacceptatie ongewijzigd open.

## UI-followup40263 — 17 oktober 2026

Sessionhoes op iPhone volgt contentbreedte en gebruikt de bestaande SpeeltNu-
vinylfallback bij laden/fout/geenURL. Opslagtoast met serverdatum/duur verschijnt
na bevestigde End én matchingreadonlyarchief, zonder replay of geschatte eindtijd.
8gerichte testsPASS0.796s,1255keys/5talenPASS; signed native builds en iPad40263
install/readbackPASS. Mac mini40258/40263gereed; iPhone unavailable, USB gevraagd.
Fysieke iPhone/echte Endtoast en overige parentacceptatie blijven afzonderlijk open.

## UI-followup40261 — 17 oktober 2026

Bronlinks tonen alleen providernaam; Opname/Eerdere opname verwijderd bij
MusicBrainz/Spotify en overige bronnen in huidige Moment- en historybijdragen.
Signed native buildsPASS; iPad40261 geïnstalleerd/teruggelezen. Mac mini40258,
gewone40261 gereed; iPhone unavailable. Geen verse fysieke screenshotclaim.

## UI-followup40260 — 17 oktober 2026

Verbindingsstatus heeft het info-icoon rechts in dezelfde volledig klikbare regel
naar Over; aparte Detailsregel weg. Gedeelde iOS/macOS/demo-weergave;
signed native buildsPASS en iPad40260 geïnstalleerd/teruggelezen. Mac mini
blijft40258 na eerder geannuleerd appafsluiten; gewone40260 staat klaar.
iPhone unavailable. Geen nieuwe fysieke tik-/screenshotclaim.

## UI-followup40259 — 17 oktober 2026

Albumhoezen in de gedeelde DJMoment/historyrenderer zijn afgerond binnen de
glazen rand. Signed iOS/macOS-buildsPASS; iPad40259 geïnstalleerd/teruggelezen.
Mac mini blijft40258 na geannuleerd appafsluiten;40259 staat gecontroleerd klaar.
iPhone unavailable. Geen nieuwe fysieke screenshot- of volledige testclaim.

## Actuele uitvoering40258 — 17 oktober 2026

Gewone40258 op iPad/Macmini,762regressiesPASS91.023s. Settings-startup op eigen
settings3autoriteit en stabiele installatie/Profilefence hersteld; echte iPadread
PASS0.274s. Watchforeground Session/flowcards/gedeelde settings en bounded proxy
bronmatig aanwezig; passive v1 echte current-music authorize/read/disablePASS,
maar verse pixels en OS-/Watch-/crossdevicematrix open. Zie
[integrale uitvoering](feedback/APPLE_INTEGRAL_EXECUTION_20261017.md) voor failures,
herstel, geïnstalleerde readback en actuele laneberichten. Bestaande solewriter
codex/apple-dj-presence-v1, HEAD4fa9115 plus behouden WIP; geen nieuwe protected
bronoplevering/Finalization. Secties hieronder zijn historische snapshots en
verlenen geen nieuwe uitvoeringsbevoegdheid.

## Current build40021 source reconciliation — 2026-10-13

[Source PR #105](https://github.com/pcvantol/djconnect-app/pull/105) is protected merged as `357251cedc4b78a4f9d5b446d3cdafc610cedc40`; reviewed head `6edfcb0c1dddde38398d23dbee93a6b557b742e2` shares tree `d6ae93ee6fd3eb64a1c9ab6756f17cac87c9dd35`. All previously local40021 followups are retained, plus the independently reviewed HTTP authority-withdrawal privacy correction.498 shared tests, unsigned Mac/iOS Simulator builds and contract/localization/security checks PASS; technical/privacy and UX bounded GO. Source-main CI/coverage38439881390 and formal evidence38441132690 PASS; independently verified hashes and canonical integrity are in [portable receipts](verification/40021-source-finalization/source-main-readback.json). Separate Finalization requires its own exact-candidate publication/merge authority and readback.

Existing Mac40021 installation task remains closed. Backups, settings, original separate WIP and exact installed-source snapshot are preserved; the later review correction is not installed. Physical/provider/artist-image and full transport parity limits remain explicit in [qualification](verification/APPLE_40021_SOURCE_RECONCILIATION_20261013.md). No Core write, new install or release is authorized by this record.

Current action is documentary40021 Finalization only. Then continue the already selected `DJC-APPLE-DJ-PRESENCE-V1-20261011` from a freshly admitted reconciled main, using the existing writer and Core presence v1. No Presence source has started. Other queue items remain deferred to their own pickup. The following sections retain historical freeze points.

See the separate [Finalization snapshot](history/prompts/2026-10-13-apple-40021-main-finalization.md) and portable source receipts before declaring repository/workspace completion.


## Current Session controls and glass followup — 2026-10-12

Build40016 is local on `codex/apple-session-mood-toolbar`, based on reconciled main7900ec7. Toolbar mood/status popovers, bound End confirmation, top-right glyphs, native glass rendering and playback time labels are implemented across shared Apple UI. Full477-test run PASS; bounded native iPhone/iPad controls PASS. Physical scroll acceptance, final Mac screen proof, publication and40016 installation are pending; ordinary physical iPad/MacBook40015 remains installed. No Core/backend mutation or Store/HA release. See [current qualification](verification/SESSION_CONTROLS_GLASS_20261012.md). The previous sections below are historical delivery snapshots.


## Current Session header refinement — 2026-10-12

Owner-requested header correction is source-delivered through [PR #101](https://github.com/pcvantol/djconnect-app/pull/101), reviewed head `c5af1f07c8440a6e6f90b0a186d04aaea07f0dd4`, protected source-main `03d02a40c4caa9b5d37c8767e49f87b88cf106a3`. Both trees are `af668f407b18246157217157ceafacb7e4d51d2b`; parent is prior reconciled main `c045473`. Official Owner Authorization38210333937 and premerge CI38208915501 PASS. Source-main CI/coverage38210411713 and durable exact-SHA evidence38211003692 independently verified PASS. This separate [Finalization candidate](history/prompts/2026-10-12-apple-session-header-finalization.md) requires its own publication/protected-merge authority.

Build40015 keeps current music/artwork left and current DJ/quiet/recovery content right, including compact widths; current header stays pinned. Compact full Spotify logo/source links and at least44pt hit areas retain attribution. Native iPhone/iPad tests and actual temporary Mac AX/screenshots PASS; independent technical and bounded visual reviews GO. These Demo captures do not qualify actual artwork/Spotify provider retrieval, XXXL/long-language stress or real-provider acceptance.473 reported general tests include8 gated producer skips. Product Acceptance: `PARTIAL`.

Repository State: `MERGED_UNRECONCILED` until separately approved protected Finalization publication/merge and exact-main readback. Previous PR99/100 is completed/reconciled; the prior sections below are historical snapshots. iPad/MacBook ordinary40014 were privately installed under separate owner authority; this refinement has not installed40015. One reused Apple writer; original separate WIP and terminal #95/#96 preserved; temporary Mac test stopped. No Core changes, new install, Store release or HA deployment is authorized by this document.


## Previous bounded Apple handoff — snapshot 2026-10-12

Source [PR99](https://github.com/pcvantol/djconnect-app/pull/99), approved head
1b78af9d2aa94176ed79c0337ae3f780894edf38, is protected merged to exact
source-main0e0deed212107b8ab36a7cfa0b3d32ed2c388231. Candidate/main tree
6dae800c84d76b6dd81b430314af284c4cadc4b7 equality, official Owner Authorization,
main CI/coverage and internal exact-SHA evidence independently verified PASS.
The same sole Apple writer, closed #95/#96 and original separate WIP remain
preserved; earlier source/history PR97/98 are not reopened.

Followup delivers newest-first pinned native Session UI, honest archive
rows/refresh, separate player routes, server-owned mood revisions, localized
privacy/output handling, representative explicit Demo active/readonly previous
Sessions and the native idle welcomehero. See the
[historical PR99/100 Finalization snapshot](history/prompts/2026-10-12-apple-session-ui-demo-welcome-finalization.md)
and [portable source/native/main receipts](verification/session-ui-finalization/source-main-readback.json).
Source reconciliation is `MERGED_UNRECONCILED` until the separate Finalization
receives exact-head authority, protected publication and main/evidence readback.
Product acceptance remains `PARTIAL`; Demo voice is scripted, not microphone/STT.
Producer artwork fields, current real-provider/physical acceptance and latest
installations remain bounded/open. No new Core writer, Store/HA deployment,
next capability or implicit installation follows from this source merge.


## Previous bounded Apple handoff — snapshot 2026-10-10

SourcePR97/prior source-main65c744b delivers the selected native
conversation/history/search/paired-live slice. One original Apple writer;
#95/#96 closed; unrelated primary WIP retained. The source/main trees are equal.
See [Finalization snapshot](history/prompts/2026-10-10-apple-session-conversation-history-finalization.md)
for exact SHAs, producer pins, reviews, evidence and qualification limits.
Genuine Mac spoken-input acceptance remains open; owner-reported physical
40012voice is a separate earlier-source result. No next capability or implicit
installation/Store/HA authority follows from the source merge.

This handoff is for building native iOS, macOS, and watchOS DJConnect clients
that use the same Home Assistant custom integration backend as the ESP32
firmware.

The app should be functionally comparable to the ESP device at the integration
contract level, but it is not an ESP emulator. Use `client_type` to identify the
client family:

- iOS app: `ios`
- macOS app: `macos`
- watchOS app: `watchos`
- ESP firmware remains: `esp32`

Do not use `device_type` for DJConnect client identity. `device_type` may only
appear as playback-output metadata if returned by the backend.

## Architecture

Home Assistant is the trusted DJConnect backend for:

- pairing;
- bearer-token lifecycle;
- backend playback commands;
- Spotify OAuth and future playback backend credentials;
- Assist/STT/TTS;
- OTA/update offers for device clients where applicable;
- native Home Assistant entities.

The Apple app owns:

- native UI;
- local app state;
- local bonus games and local highscores;
- local audio recording if voice/PTT is implemented;
- local playback of returned DJ response audio, if desired;
- local notifications, menus, or widgets, if desired.

The app must not store or request Spotify OAuth secrets, refresh tokens, client
secrets, Sonos credentials, Home Assistant long-lived access tokens, or playback
backend credentials. The only DJConnect credential owned by the app is its
DJConnect bearer token issued by the integration.

## Technical Design Decisions

Keep [TECHNICAL_DESIGN_DECISIONS.md](TECHNICAL_DESIGN_DECISIONS.md) updated for
every release. It is the reverse-engineered source for code-level design
patterns, coding conventions by language, and the framework/library/license
inventory.

## First-Run Onboarding

The Apple app shows a one-time welcome screen after installation. It must use
DJConnect branding and link setup to:

```text
https://djconnect.dev/start
```

User-facing copy must make two prerequisites clear:

- setup is done in Home Assistant through the DJConnect integration;
- a supported Home Assistant-side music backend is required for playback.

The app must not request Spotify or Music Assistant credentials during
onboarding. Backend credentials belong to the Home Assistant integration.

## Unpaired Runtime UX

When the Apple app has no valid DJConnect bearer token, the main runtime UI is
blocked by a pairing sheet. The sheet must show:

- DJConnect banner/branding.
- Home Assistant setup context.
- Local Home Assistant URL plus pairing code/QR entry on iOS/macOS; Watch
  pairing shows iPhone companion status.
- Copyable app-generated pairing code.
- Pairing progress while Home Assistant calls the client API or while polling
  is active.
- A green success state after pairing, followed by a `Let's Start!` action.

The wakeword activation prompt may be shown after the user leaves the pairing
success sheet, not on top of it.

For App Store review and UI auditing, the pairing sheet may expose Demo Mode.
Demo Mode uses local sample playback, queue, playlist, output, DJ
announcement and representative native active/readonly previous Session state.
Session/conversation examples stay in memory, are visibly labeled, grant no
Profile authority and preserve ordinary chat/widget caches. It must not store a bearer token, create HA entities, or
be treated as backend validation. Demo Mode is session-only: after app restart,
an unpaired client returns to the pairing sheet. Exiting Demo Mode from
Settings must return to the initial unpaired state with Now Playing behind the
pairing sheet. The Demo Mode microphone action shows an explicitly scripted question/answer
in the native Session timeline. It requests no microphone consent and records,
uploads or plays no audio. It remains visibly local Demo and calls no Home
Assistant endpoint.

If the user resets pairing, the app should clear runtime playback/output/
queue/playlist state, navigate back to Now Playing, and present the pairing
sheet over that initial state.

## Local Games

The Apple app may include the same local bonus games as the ESP client:

- Paddle Rally
- Meteor Run
- Sky Dash
- Maze Chase

Games are local-only UI features. They must not call Home Assistant, create HA
entities, affect pairing state, require Spotify playback, or send DJConnect
status/command payloads. Highscores may be stored in app-local preferences and
may be cleared by app reinstall or local app data reset. Games should remain
available in Demo Mode because they are not backend validation. Games should
lazy start behind a tap-to-play overlay, and leaving the Games page should stop
the local loop and reset every game to its idle overlay. When a game is active,
keyboard arrows and space should be handled by the game surface and should not
trigger sidebar, tab, or page navigation. On iPad landscape, cap the game canvas
height so the movement/action buttons remain visible below the playfield; keep
portrait sizing unchanged.

## Identity

Use a stable `device_id` per app installation.

Suggested format:

- iOS: `djconnect-ios-<stable-install-id>`
- macOS: `djconnect-macos-<stable-install-id>`

The suffix should be stable across app launches, but should reset if the user
explicitly resets DJConnect pairing in the app. Avoid exposing Apple account,
device serial, hostname, WiFi SSID, or other private identifiers in the id.

Recommended iOS fields:

```json
{
  "device_id": "djconnect-ios-8F3A2C91B45D",
  "device_name": "DJConnect iPhone",
  "client_type": "ios",
  "firmware": "3.2.22",
  "app_version": "3.2.22",
  "platform": "ios"
}
```

Recommended macOS fields:

```json
{
  "device_id": "djconnect-macos-8F3A2C91B45D",
  "device_name": "DJConnect Mac",
  "client_type": "macos",
  "firmware": "3.2.22",
  "app_version": "3.2.22",
  "platform": "macos"
}
```

Recommended watchOS fields:

```json
{
  "device_id": "djconnect-watchos-8F3A2C91B45D",
  "device_name": "DJConnect Watch",
  "client_type": "watchos",
  "firmware": "3.2.22",
  "app_version": "3.2.22",
  "platform": "watchos"
}
```

The watchOS client is companion-only. It keeps its own Watch identity and
compact UI cache, but pairing, DJConnect bearer-token ownership, Home Assistant
transport selection, APNs registration, status refresh, Ask DJ history sync,
playback actions, follow-up actions, idle suggestions, clear history, and voice
upload are mediated by the paired iPhone over WatchConnectivity. The Watch does
not store `ha_remote_url`, does not choose local/remote transport, does not host
an inbound Web API, exposes voice through `Ask
DJ`, and keeps wake phrase detection foreground-only. When the iPhone sends a
request to HA on behalf of the Watch it preserves `client_type:"watchos"` and
the Watch `device_id`.

Ask DJ is the single Apple-client DJ interaction surface. iOS, macOS, and
watchOS expose DJ requests through Ask DJ chat/PTT and synced Ask DJ history;
Now Playing should not reintroduce a separate `DJ verzoek` block. rbpi did not
have that separate UI block, and ESP32 remains a firmware/device client without
the Apple Ask DJ rich chat UI.

Mood is backend-owned Profile/Session state under negotiated settings3. Native
Session Persona, Mood and presence quick controls edit that same authoritative
state. Ask DJ and Track Insight consume the confirmed context/style; they do not
create independent durable choices. The DJ voice editor is a Session ellipsis
popover, with text_only visibility and output rules documented in ARCHITECTURE.md.

For `Ask DJ`, the Watch may send mood, DJ style, and a Music DNA key hint, but
Music DNA itself belongs to the Home Assistant integration. This lets a user
ask for a calmer track on Watch and later ask from Mac why that track was
chosen.

Music DNA consent and settings must stay cross-device. iOS, macOS, and watchOS
show the initial opt-in prompt from both Ask DJ and the Music DNA screen. On
watchOS, the Watch asks the paired iPhone to call `/api/djconnect/v1/music_dna/*`
while preserving the Watch `device_id` and canonical `client_type:"watchos"`.
Watch Settings must expose the same Music DNA on/off control as iOS/macOS:
opting out clears learned backend Music DNA and stops future profile buildup;
opting in again restarts from the backend profile response. Settings copy must
be contextual: disabled means no profile is being built and the learned profile
has already been cleared. The separate clear-profile action should only be
visible while Music DNA is enabled. After opt-in or opt-out, clients may keep
the just-selected enabled state visible briefly while a stale profile refresh
catches up; Home Assistant remains authoritative once it returns the matching
state or the grace window expires.

Ontdek / Music Discovery on watchOS is also iPhone-proxied. The Watch shows the
backend-provided recommendation sections as a compact list, opens item details
with the backend `reason` and `reason_sources`, and uses the same Play Now
contract as iOS/macOS. Watch clients must preserve the watchOS identity and must
not generate local recommendations or reasons.

iOS and macOS Settings expose Music DNA export/import. Export must use HTTP
`POST /api/djconnect/v1/music_dna/export`, never the Home Assistant WebSocket fast
path, and save/share the exact backend JSON envelope only after the user chooses
a native save/share destination. Clients must not build the export locally from
`/music_dna/profile` and must not append tokens, bootstrap proofs, raw prompts,
raw audio, diagnostics, Home Assistant URLs, or cache fields. Import previews an
export envelope locally and uploads only while paired and connected; rejected,
stale, `401`/`403`, or `not_configured` responses use the same pairing recovery
flow as other DJConnect endpoints.

Ask DJ history is backend-synchronized and locally cached. Clients must merge
server history into the cache instead of replacing it with a bounded response
window. Backend `clear_revision` clears the local chat; backend
`history_trimmed_before` lets clients prune old cached messages when the
server-side history limit is reached. Assistant-only `message_kind: system`
messages such as ambient music facts and history-retention notices must render
without requiring a preceding user bubble. When the Ask DJ screen opens,
clients should scroll the loaded timeline to the newest message by default,
including after the first async history response. If a later history/status
sync advances `clear_revision` while a fresh local question/answer exchange is
still identified by the same `client_message_id`, preserve that exchange until
Home Assistant returns it in history.

Ask DJ output-device responses may include output `playback_actions`. Apple
clients render them as vertical speaker rows with the name on the left and an
`Actief`/`Activeer` button on the right. Tapping a row sends the backend-owned
output command and preserves the backend-returned action object where possible;
clients do not infer speaker switching from free text. Ask DJ message and
command payloads include `device_id`, `device_name`, `client_id`, and
`client_type`, with `client_id` currently matching `device_id`.

DJ announcement output mode is client-selectable, but the HA speaker entity is
not. Apple clients parse `dj_announcement` capabilities from pairing/status,
send only `dj_announcement_output`, and never send or mutate
`dj_announcement_speaker_entity_id`. Available modes are `client_device` and
`text_only` without an HA speaker, plus `both` and `ha_speaker` when HA reports
a configured speaker. Autoplay remains local and requires the auto-play setting,
a client-deliverable `announcement.audio_url`, and `delivery` of
`client_device` or `both`; `ha_speaker` and `text_only` never start client
audio. Push payloads are only wake/sync hints.

The Apple clear-history action calls
`POST /api/djconnect/v1/ask_dj/history/clear`. Home Assistant should scope the
clear to the relevant user/client/history namespace, increment
`clear_revision`, and keep returning that revision on later history/message
responses so all Apple clients can clear their local caches deterministically.

Raw backend/proxy/decode bodies, including HTML error pages, must never appear
in the Ask DJ chat UI. Keep the details in diagnostics logs and show only
localized user-facing messages such as `Ask DJ niet bereikbaar` or `Home
Assistant gaf geen antwoord`.

The HA integration currently uses `firmware` as the common client version field
for protocol compatibility checks. App clients may also send `app_version`, but
must keep `firmware` populated unless the backend contract is changed.

## Version Contract

DJConnect clients and the HA integration must share the same `major.minor`
protocol version:

- HA `3.0.z` accepts clients `3.0.z`.
- HA `3.1.z` accepts clients `3.1.z`.
- HA `4.0.z` accepts clients `4.0.z`.
- Patch versions may differ.
- `0.0.0` is reserved as a dev-client escape hatch.

If HA returns HTTP `426` with `error: "version_mismatch"`, the app must not
reset pairing or discard the token. Show an update-required state and pause
command/voice retries until the user updates the app or integration.

The Apple app also validates `ha_version` / `ha_major_minor` fields on normal
status and command responses. App `4.0.x` requires HA integration `4.0.x`
(`>=4.0.0`, `<4.1.0`). If HA is outside that range, the app must show a clear
message to update the Home Assistant integration, disable playback/output/
queue/playlist/liked/voice controls, and keep Settings plus pairing reset
available.

Expected response:

```json
{
  "success": false,
  "error": "version_mismatch",
  "message": "DJConnect Home Assistant integration and device firmware major.minor versions must match.",
  "ha_version": "3.2.22",
  "ha_major_minor": "3.2",
  "firmware": "3.2.22",
  "firmware_major_minor": "3.1"
}
```

## Pairing Flow

The app should pair with the Home Assistant DJConnect integration, not directly
with Spotify or any playback backend.

The app needs:

- Home Assistant local base URL;
- DJConnect pairing code shown by Home Assistant and entered/scanned by the
  app;
- DJConnect bearer token returned/stored by the integration.
- `ha_local_url` returned by the integration after pairing.
- Optional `ha_remote_url` returned by the integration after successful local
  pairing.
- Optional `assist_pipeline_id` returned by the integration for future voice
  flow selection.

Recommended user flow:

1. User starts Apple-client pairing in the Home Assistant DJConnect setup flow.
2. Home Assistant shows a pairing code or QR code. For iOS, prefer the
   `djconnect://pair?ha_url=<local-ha-url>&pair_code=<code>&client_type=ios&pair_path=/api/djconnect/v1/pair`
   QR/deep-link payload. For Apple Watch, use the separate Watch setup flow with
   `client_type=watchos` and scan/open it on the paired iPhone.
3. The Apple app is on the same LAN and the user scans the QR code or enters
   the local URL plus code manually. Watch users do not enter URL/code on the
   Watch; the iPhone forwards the validated payload over WatchConnectivity.
4. The app posts the code and canonical client identity to local
   `/api/djconnect/v1/pair`. For Watch pairing, the posting client identity remains
   `client_type: "watchos"` with a `djconnect-watchos-*` device ID, even when
   the iPhone proxies the HTTP request.
5. Integration creates or returns a DJConnect bearer token for the app runtime.
6. App stores only the DJConnect bearer token, client identity, `ha_local_url`,
   optional `ha_remote_url`, and protocol/backend metadata in app-private
   storage.
7. App sends authenticated status and stays in a waiting state until Home
   Assistant has finished the setup flow. `not_configured`, route-missing, or
   equivalent setup-pending status responses do not count as runtime paired.
8. App starts sending authenticated status and command payloads with
   `device_id` and `client_type`.
9. iOS/macOS use `ha_local_url` first, fall back to `ha_remote_url` after
   successful local pairing when local access is unavailable, and report
   `offline` when neither URL works.

Remote pairing is not allowed. If only the remote URL is reachable during
pairing, the app must tell the user to complete pairing on the same local
network as Home Assistant. For development only, `https://*.ngrok-free.dev`
is whitelisted as an allowed tunnel URL during pairing; other remote HTTPS URLs
remain invalid for first pairing.

Fresh app installs should default the Home Assistant URL input to:

```text
http://homeassistant.local:8123
```

Users can replace it with an IP-based local URL when name resolution is unavailable.

The iOS/macOS app is an app client, not ESP hardware, and no longer exposes a
Home Assistant-callable inbound Web API or pairable discovery service. The Watch itself never
exposes a LAN endpoint, and the active Watch runtime is a WatchConnectivity
proxy rather than an iPhone-hosted Home Assistant callback endpoint.

Implemented initial app contract:

```http
POST /api/djconnect/v1/pair
Content-Type: application/json
X-DJConnect-Device-ID: <device_id>
```

```json
{  "device_id": "djconnect-macos-8F3A2C91B45D",
  "device_name": "DJConnect Mac",
  "client_type": "macos",
  "firmware": "3.2.22",
  "app_version": "3.2.22",
  "platform": "macos",
  "pair_code": "123456",
  "pairing_code": "123456",
  "pairing_token": "123456"
}
```

Expected completion response:

```json
{
  "success": true,
  "setup_pending": true,
  "device_token": "<djconnect bearer token>"
}
```

Home Assistant generates the 6-digit setup code. The app shows manual fields
for the local Home Assistant URL and that code, then posts client-to-HA with
the code as `pair_code`, `pairing_code`, and `pairing_token` for compatibility
with current HA builds. HTTP 401/403 during unauthenticated pairing means Home
Assistant rejected the entered code or setup identity; stop pairing and ask the
user to verify the code shown by Home Assistant or generate a fresh setup code.
HTTP 400 with `error:"client_type_mismatch"` means the user selected the wrong
Home Assistant DJConnect setup flow for this app. Stop the attempt, keep the
entered URL and code intact, log expected/received client types only at debug
level, and show platform-specific guidance to choose iPhone/iPad, Apple Watch,
or macOS in Home Assistant. Do not clear local token/keychain state for this
error unless an already paired runtime request later receives authenticated
401/403 stale auth.

Bearer token storage:

- iOS: app-private storage scoped to the app container.
- macOS: app-private storage scoped to the app container.
- watchOS: app-private storage scoped to the Watch app container.
- Never log the token.
- Never include the token in diagnostics exports.

## Diagnostics And Crash Reports

The app may detect that the previous session ended uncleanly. On the next
launch it shows a user-mediated crash report prompt. The prompt may:

- copy redacted diagnostics to the clipboard;
- open a prefilled GitHub issue in `pcvantol/djconnect`.

The app must not upload crash logs automatically, embed GitHub credentials, or
send diagnostics without explicit user action. Diagnostics must redact bearer
tokens, Home Assistant tokens, Spotify secrets, temporary audio URLs, and other
token-like fields.

The app may persist a local redacted rolling diagnostic logfile in Application
Support, currently `DJConnect/Logs/djconnect.log`, so logs survive app restarts
and crash investigation. The file must be bounded by retention and size limits,
loaded into the Logs screen on restart, and deleted when the user clears logs.
It must never be uploaded automatically.

## Debug Logging Contract

The app should provide consistent DEBUG-level diagnostics for:

- user actions, such as refresh, transport controls, output changes, queue item
  starts, playlist starts, Demo Mode entry/exit, pairing reset, wakeword prompt
  actions, and voice/PTT actions;
- navigation/recovery flows, such as pairing success dismissal, Demo Mode exit,
  pairing reset returning to Now Playing, and crash recovery prompts;
- Home Assistant API calls, always including the HTTP method/path and status
  code;
- iPhone-mediated Watch proxy actions, without token, prompt, or audio payload
  contents.

Do not log Authorization headers, bearer tokens, pairing codes, Spotify
tokens, Home Assistant long-lived tokens, passwords, or raw request/response
bodies that may contain secrets. Redacted response summaries are acceptable for
diagnostics.

Permission UX:

- Microphone and Speech Recognition can be requested from Settings before
  push-to-talk or foreground wakeword use.
- Because current iOS/macOS beta builds have shown crashes when directly
  invoking `SFSpeechRecognizer.requestAuthorization`, the Apple app should not
  call the Speech Recognition system prompt from the generic Settings
  permission button. If speech access is already granted, accept it; otherwise
  log a non-secret diagnostic line and keep stemactivatie unavailable until the
  user enables speech access in system settings.
- Local Network is declared for LAN access, but Apple does not provide
  a reliable explicit preflight API. The app should not fake a request button;
  iOS/macOS show the system prompt when local network work first occurs.
- iPhone permission rows should remain compact enough to scan without excessive
  vertical whitespace.

## Monkey Test Mode

Apple app Debug builds may support `--monkey-testing`. This mode is explicitly
non-destructive: it starts in local Demo Mode, skips first-run/pairing/crash
blocking sheets, avoids local Client API startup, avoids Home Assistant calls,
and is intended only for random UI navigation/tap stress tests. It must not
reset real pairing, alter locally stored tokens, call Spotify/Home Assistant, or be
treated as backend validation.

Current UI monkey coverage includes iOS and macOS smoke tests for navigation
through Now Playing, Queue, Playlists, Games, Settings, and About. Long repeated
soaks should only be recorded as release verification when they finish without
interruption.

Auth headers for app to HA:

```http
Authorization: Bearer <djconnect_bearer_token>
X-DJConnect-Device-ID: <device_id>
Content-Type: application/json
```

For raw voice audio:

```http
Authorization: Bearer <djconnect_bearer_token>
X-DJConnect-Device-ID: <device_id>
Content-Type: audio/wav
```

## Status Endpoint

Post client status to:

```http
POST /api/djconnect/v1/status
```

Minimum payload:

```json
{
  "device_id": "djconnect-ios-8F3A2C91B45D",
  "client_type": "ios",
  "ha_pairing_status": "paired",
  "firmware": "3.2.22",
  "app_version": "3.2.22",
  "state": "online",
  "status": "online",
  "battery_percent": 85,
  "language": "nl",
  "theme": "dark",
  "log_level": "info",
  "ha_local_url": "http://192.168.1.13:8123"
}
```

Optional app-specific fields:

```json
{
  "platform": "ios",
  "os_version": "18.5",
  "app_build": "30900",
  "local_audio_supported": true,
  "voice_supported": true,
  "screen_state": "on",
  "network_type": "wifi"
}
```

Status responses may include:

```json
{
  "success": true,
  "client_type": "ios",
  "device_language": "nl",
  "language": "nl",
  "backend_available": true,
  "playback": {}
}
```

Use `device_language`/`language` to update app UI language only if the app
supports remote language sync. Otherwise keep it as informational state.

## Playback Commands

Send generic playback commands to:

```http
POST /api/djconnect/v1/command
```

All command payloads must include `device_id` and `client_type`. Keep command payloads focused on playback commands and client identity. Do not
send partial device-status snapshots in `/api/djconnect/v1/command`; use
`/api/djconnect/v1/status` as the authoritative source for client status and
settings mirrored into Home Assistant entities.

Do not expose or send Home Assistant's removed Spotify override settings in
new client UI or setup flows. `spotify_source` / "Spotify source override" and
`liked_proxy_playlist_uri` / "Standaard playlist override" are no longer
client-configurable. Backend playback remains owned by the HA DJConnect
integration; clients continue to send generic playback commands only.

Examples:

```json
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"status"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"devices"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"queue","limit":100}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"playlists","limit":100}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"pause"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"play"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"next"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"previous"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"seek_relative","value":15000}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"seek_relative","value":-15000}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_volume","value":35}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_shuffle","value":true}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_repeat","value":"context"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"start_liked_proxy","play":true}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"start_playlist","value":"spotify:playlist:...","play":true}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_output","value":"Living Room","play":true}
```

For playback-changing commands, the app refreshes the rich Now Playing snapshot
immediately after the command returns. Home Assistant should continue returning
the same playback shape for the `status` command so play/pause state, album art,
progress, output, and volume can update without waiting for a later user action.

The Apple output selector should contain only a local `Geen`/`None` no-output
choice plus real backend devices from Home Assistant. Do not expose synthetic
`iPhone standaard` or `Mac standaard` output choices: they are not real
playback targets and selecting `Geen` must block playback-start commands until
a real backend device is selected.

Apple app clients may expose current-track seek controls. Use
`command:"seek_relative"` with an integer `value` in milliseconds. Positive
values seek forward and negative values seek backward. Home Assistant should
clamp the resulting position to the current track and return the usual command
response. ESP clients may skip this UI capability.

Queue loading uses `command:"queue"` with `limit:100` and should return:

```json
{
  "success": true,
  "queue": {
    "items": [
      {
        "title": "Song title",
        "artist": "Artist name",
        "album": "Album name",
        "uri": "spotify:track:...",
        "duration_ms": 213000,
        "album_image_url": "https://..."
      }
    ],
    "context": "spotify:playlist:..."
  }
}
```

The app accepts `response.queue.items` first and falls back to flat
`response.queue` arrays and `response.items`. Queue context may be returned as
`queue.context`, top-level `context_uri`, or top-level `contextUri`. Queue album
art aliases are `album_image_url`, `media_image_url`, `image_url`, and
`entity_picture`. Empty queue items are not an error. Home Assistant should
return up to 100 real backend queue items and must not pad the queue with
repeated current-track entries. Queue row playback sends
`command:"play_context_at"` with `context_uri` included when known. The app only
adds `offset_uri` for Spotify contexts that support offsets, such as playlists,
albums, and shows; artist contexts are sent without `offset_uri` to avoid
Spotify API offset errors. The app no longer sends unsupported older
`play_queue_item` or `play_uri` commands.

The app does not expose an inbound callback API. Playback and queue actions always travel from the Apple
client to Home Assistant through `/api/djconnect/v1/command` using the selected
local or remote HA transport.

Expected success shape:

```json
{
  "success": true,
  "playback": {
    "has_playback": true,
    "is_playing": true,
    "track_name": "Song",
    "artist_name": "Artist",
    "album_image_url": "https://...",
    "progress_ms": 12345,
    "duration_ms": 180000,
    "volume_percent": 32,
    "shuffle": false,
    "repeat_state": "off",
    "device": {
      "id": "spotify-device-id",
      "name": "iPhone",
      "type": "Smartphone",
      "active": true,
      "supports_volume": true,
      "volume_percent": 32
    }
  }
}
```

Command responses are transport/command success first and playback-state
second. A response with `success:true` and `playback.has_playback:false` means
the Home Assistant command route worked but Spotify has no active playback; it
is not an app error state. In that case the playback snapshot is valid but
empty, and playback fields may be `null` or empty strings, including
`progress_ms`, `duration_ms`, `volume_percent`, `device.volume_percent`,
`title`, `track_name`, `artist`, `album_name`, `uri`, `context_uri`,
`queue_context`, and artwork URLs. Clients must keep those fields optional and
must not fail decoding because no playback is active.

Backend unavailable is not an auth failure:

```json
{
  "success": false,
  "error": "backend_unavailable",
  "message": "Spotify authorization has expired or was revoked. Reauthorize DJConnect.",
  "backend_available": false,
  "playback": {}
}
```

When backend unavailable:

- keep pairing/token;
- show playback temporarily unavailable with recovery copy that says DJConnect
  retries automatically;
- throttle repeated user-facing notices so command retries and recovery polling
  do not churn the UI;
- retry backend recovery with lightweight status refreshes instead of forcing
  full collection refreshes every time;
- if the backend later reports healthy/available again, clear recoverable
  backend/Spotify authorization DJ request text and restore the default
  microphone instruction;
- do not send the user through app pairing again;
- throttle retries enough to avoid UI churn.

When HA returns 401/403 on authenticated routes:

- mark pairing stale/unauthorized;
- keep token until the user explicitly resets pairing;
- show setup-again guidance.

During unauthenticated pairing polling, 401/403 responses with pairing-code
messages stop polling and show code-mismatch recovery guidance.

When HA returns 400 `client_type_mismatch` during pairing:

- stop the current attempt;
- keep the entered Home Assistant URL and pairing code intact;
- tell the user to select the matching DJConnect setup flow for this platform;
- log expected/received client types only as debug metadata;
- do not clear local pairing credentials unless a paired runtime request later
  receives authenticated 401/403 stale auth.

When HA returns 404:

- treat as integration route missing or stale pairing;
- do not erase the locally stored token automatically;
- show integration/setup recovery.

## Voice/PTT

If implementing push-to-talk:

1. App records mono PCM WAV.
2. App uploads raw WAV to HA:

```http
POST /api/djconnect/v1/voice
Content-Type: audio/wav
Authorization: Bearer <djconnect_bearer_token>
X-DJConnect-Device-ID: <device_id>
```

3. HA owns STT, Assist, playback action and TTS.
4. HA returns DJ text and optional audio URL.
5. App displays text and may play returned WAV/MP3 audio locally.

Canonical voice examples live in
`pcvantol/djconnect/examples/voice_intents.json` and
`pcvantol/djconnect/VOICE_INTENT_DATA.md`. Current HA-handled families include:

- `current_track`: `Welk nummer draait er nu?`, `Welk nummer speelt er nu?`,
  `Wat draait er?`, `Wat speelt er?`, `Wat is dit?`, `What song is playing?`,
  `What track is playing now?`, `What's playing?`, `Which song is this?`
- `playback_control`: `Stop muziek`, `Start muziek`, `Zet harder`,
  `Zet zachter`, `Volgende nummer`, `Vorig nummer`, `Stop music`,
  `Start music`, `Turn it up`, `Turn it down`, `Next song`,
  `Previous song`
- `favorite_current_track`: `Voeg dit nummer toe aan mijn favorieten`,
  `zet dit nummer bij mijn favorieten`, `like dit nummer`, `sla deze track op`,
  `bewaar dit nummer`, `add this song to my favorites`, `like this track`,
  `save this song`, `add the current track to liked songs`
- `output_devices_info`: `Welke speakers zijn er?`, `Welke output devices
  zijn beschikbaar?`, `Waar kan ik muziek afspelen?`, `which speakers are
  available?`, `what output devices do I have?`
- `current_output_info`: `Waarop wordt nu muziek gespeeld?`, `Op welke
  speaker speelt dit?`, `Waar speelt de muziek nu?`, `where is music playing
  now?`, `which speaker is active?`
- `personalized_mood_playback`: `Ik voel me moe en geprikkeld, zet wat rustige
  muziek op die ik fijn vind`, `Doe iets ontspannends, ik ben overprikkeld`,
  `Zet iets op waar ik rustig van word`, `Ik wil even kalme muziek zonder
  vocals`, `I am tired and overstimulated, play relaxing music I will enjoy`,
  `play something calming that I usually like`, `put on something low energy`
- `change_music_context`: `Ik wil wat anders horen`, `Doe maar iets anders`,
  `Zet iets anders op`, `Verras me met iets heel anders`, `Ik ben dit zat,
  draai wat anders`, `I want to hear something else`, `play something
  different`, `put on something else`, `surprise me with something completely
  different`
- `personal_music_profile_analysis`: `Omschrijf eens waar ik zoal naar
  luisterde de afgelopen maand`, `Wat zegt mijn muziek van de laatste twee
  weken over mijn stemming?`, `Welke genres luister ik de laatste tijd veel?`,
  `Maak een profiel van mijn muzieksmaak dit jaar`, `describe what I have been
  listening to over the last month`, `what does my music from the last two
  weeks say about my mood?`, `which genres have I been listening to lately?`
- `personal_music_recommendations`: `Geef me muziek aanbevelingen op basis van
  mijn luisterprofiel`, `Wat zou ik nu leuk vinden om te luisteren?`, `Raad me
  iets nieuws aan dat past bij mijn smaak`, `Welke artiesten of albums moet ik
  eens proberen?`, `Geef me vijf nummers die passen bij wat ik de laatste tijd
  luister`, `recommend music based on my listening profile`, `what should I
  listen to now?`, `recommend something new that fits my taste`, `which artists
  or albums should I try?`
- `dj_announcement_request`: `Geef me een leuke aankondiging voor het volgende
  nummer`, `Kondig het volgende nummer alvast aan`, `Doe een radio intro voor
  wat er nu speelt`, `Zeg iets leuks over dit nummer`, `give me a fun
  announcement for the next song`, `do a radio-style intro for what is playing
  now`, `say something fun about this track`
- `track_context_info`: `Vertel iets over dit nummer`, `Wanneer kwam dit uit?`,
  `Waar komt deze artiest vandaan?`, `Welke samples hoor ik?`, `Heeft deze
  artiest binnenkort concerten in Nederland?`, `Waarom koos je dit nummer?`,
  `Wat is de connectie met het vorige nummer?`, `tell me about this song`,
  `what year was this released?`, `where is this artist from?`, `what samples
  are used?`, `does this artist have concerts in the Netherlands?`, `why did
  you choose this track?`
- `track_insight`: `Geef Track Insight voor dit nummer`, `Analyseer deze track`,
  `Hoe is deze track opgebouwd?`,
  `Welke instrumenten hoor je hierin?`, `Hoe zit intro, couplet, refrein en
  breakdown in elkaar?`, `Give me a Track Insight of this song`, `How is
  this track built up?`, `Why does this track work so well?`

The app does not hardcode these intent families or validate spoken text
client-side. It records/uploads voice audio and lets Home Assistant handle STT,
Assist correction, current playback lookup, direct playback controls, Spotify
credentials, output-device lookup, current-speaker lookup, favorite-track
mutations, personalized mood playback, DJ announcement generation, and DJ
response generation.

For `personal_music_profile_analysis`, Home Assistant should summarize the
user's listening profile over the requested or inferred period without changing
playback. It should use Music DNA, recent tracks, likes/skips where available,
timestamps, mood values, playlist choices, and current playback context to
describe recurring genres, artists, energy, moods, listening situations, and
notable taste shifts. If no period is given, default to a recent window such as
the last 30 days and say so. If memory is too sparse for the requested period,
return an honest DJ response instead of inventing history.

For `personal_music_recommendations`, Home Assistant should recommend concrete
tracks, albums, artists, or playlists from Music DNA plus Spotify recently
played/top data where available. It should explain why recommendations fit the
user's known taste, mood, energy, and recent listening. This intent is
informational by default: do not change playback unless the user explicitly asks
to play, queue, save, or create something from the recommendations.

For `track_context_info`, Home Assistant should enrich the current playback
context with album art, title, artist, release year, genre, DJ commentary,
artist origin, trivia, samples, related artists, upcoming Netherlands concerts,
festival appearances, new releases, why the track was chosen, relation to the
previous track, energy flow, and shared producer or label connections
when those details are available.

For `track_insight`, Home Assistant should explain instrumentation,
arrangement, rhythm/groove, energy curve, sound design, production techniques, mix/mastering
impressions, and why the composition works. This is an informational/read-only
intent for iOS, macOS, watchOS, Raspberry Pi, and Windows Ask DJ clients: never
start, pause, skip, queue, save, like, transfer output, or otherwise mutate
playback from this intent. ESP32 remains outside the Ask DJ chat/history UI.
Direct Track Insight endpoint calls include the same canonical `client_type` as
status/command payloads. Missing or unsupported client types should be returned
as `invalid_client_type`; clients localize the message and keep pairing state.

VibeCast is a first-class iOS/macOS streaming surface. Apple clients poll
`GET /api/djconnect/v1/vibecast` while the VibeCast surface is visible, or use the
optional local WebSocket route `djconnect/vibecast` when HA advertises it. The
response is backend-neutral structured JSON with `enabled`, disabled `reason`,
`revision`, `ttl_seconds`, `poll_after_seconds`, current-track `context`, and
feed `items` using safe rich-text segments (`text`, `strong`, `emphasis`,
`emoji`, `magnify`, `accent`, `line_break`). Clients advertise `emoji_safe`
when emoji can be shown inline, render unknown item/segment types as plain text,
do not parse HTML/Markdown, and do not show raw provider/cache/decode errors.
While VibeCast is active, iOS/macOS client-side Track Insight
enters an "auto analyze on next track start" mode: it requests Track Insight for
the current playing track and once for each new playing track with `open:false`,
dedupes repeated snapshots for the same track, and stops the mode when VibeCast
is closed.
iOS AirPlay VibeCast renders a local MP4 before handing it to AVPlayer/AirPlay.
The renderer must resolve album art before frame encoding, using Track Insight
artwork first and the current Now Playing artwork URL as fallback. Do not rely on
async image loading inside the SwiftUI frame renderer, because the placeholder
would otherwise be baked into the video.

The response may include `analysis` metadata with `mode`, `confidence`,
`measured`, `inferred`, `limitations`, and `sources`, plus optional compact
`items[]` such as `kind: "energy"` or `kind:
"arrangement"` for structure notes. Clearly separate measured/provider-backed
facts from inferred musical commentary. Unless the backend adds a real
audio-analysis pipeline or uses a trusted source, it must avoid claiming exact
timestamps, stem separation, exact chord transcription, or definitive instrument
lists.

Expected response:

```json
{
  "success": true,
  "text": "Daar gaan we.",
  "dj_text": "Daar gaan we.",
  "audio_url": "http://homeassistant.local:8123/api/djconnect/v1/tts/token.mp3",
  "audio_type": "mp3"
}
```

Rules:

- For local latency wins, use only the opt-in DJConnect WebSocket fast path on
  Home Assistant `/api/websocket`: authenticate the HA WebSocket with a valid HA
  auth token/mechanism first, request `djconnect/capabilities`, and send only
  advertised `djconnect/command`, `djconnect/ask_dj/message`,
  `djconnect/ask_dj/history`, `djconnect/ask_dj/history/clear`, or
  `djconnect/track_insight` actions. The paired DJConnect `device_token` is
  required inside DJConnect payloads after HA auth succeeds, but must never be
  treated as HA WebSocket auth. Missing capabilities or any WebSocket failure
  must fall back to the canonical HTTP route once.
- Do not connect directly to Home Assistant Assist WebSocket from the app for
  DJConnect PTT unless the backend contract is explicitly changed.
- Do not call OpenAI or Spotify directly from the app for DJConnect commands.
- Do not log temporary `audio_url` tokens.
- If returned audio cannot be played, show text-only response.

## App Settings

The ESP has device settings such as screen brightness, LED and speaker cue
volume. The iOS/macOS/watchOS app should not copy those settings blindly.

Suggested app-owned settings:

- HA URL selection;
- pairing reset;
- language;
- theme;
- voice/PTT enabled;
- local response audio enabled;
- diagnostics export;
- log level.

If app settings should be mirrored into HA entities, post them in status under
clear app-specific keys. Avoid reusing ESP-only settings like
`screen_brightness` unless the app truly implements equivalent behavior.

## Public Releases And What's New

Release tags in the private app repo should publish unsigned macOS and iOS
diagnostic builds to `pcvantol/djconnect-app-releases` through GitHub Actions.
The workflow requires private repo secrets named `PUBLIC_RELEASES_TOKEN` with
write access to that public releases repo and `WEBSITE_RELEASE_NOTES_TOKEN`
with write access to `pcvantol/djconnect-website`.
After publishing, the workflow keeps the newest platform-specific public iOS
release and the newest platform-specific public macOS release, then removes
older public app releases/tags for those platform namespaces.
The workflow runs Swift tests before it publishes either unsigned artifacts or
static What's New files. If that job fails, the source GitHub release can exist
while `djconnect.dev/release-notes/.../vX.Y.Z.json` and the public
`ios/vX.Y.Z` / `macos/vX.Y.Z` releases are still missing.

The Apple apps persist the last seen app version locally. When a newer app
version starts, they fetch platform-specific static release notes from
`djconnect.dev` using the current app language first: iOS reads
`/release-notes/ios/{en|nl|de|fr|es}/vX.Y.Z.json`, macOS reads
`/release-notes/macos/{en|nl|de|fr|es}/vX.Y.Z.json`. The older
`/release-notes/{ios|macos}/vX.Y.Z.json` path and GitHub release metadata
remain fallbacks. The release body is shown once in a native
`Wat is er nieuw` / `What's New` sheet. This request sends no DJConnect token,
Home Assistant URL, Spotify token, diagnostics, or user data.

## UI Parity Goals

Functional parity with the ESP device should include:

- pairing/setup state;
- Home Assistant connection state;
- playback now-playing view;
- play/pause, previous-track, next-track;
- volume 0-60;
- shuffle toggle;
- repeat triple state: `off`, `track`, `context`;
- output selector;
- queue view;
- playlists/liked proxy start;
- DJ/voice response view with PTT WAV upload;
- backend unavailable and version mismatch states.
- About screen with a full-width DJConnect app banner, version, identity,
  pairing state, and Home Assistant URL details.

iOS/macOS-specific UX may add:

- menu bar control on macOS;
- lock screen/live activity on iOS if appropriate;
- media key integration, if it maps cleanly to DJConnect commands;
- widgets/shortcuts later.

## Security And Privacy

Never log:

- DJConnect bearer token;
- Home Assistant tokens;
- Spotify refresh token;
- OAuth client secret;
- WiFi password;
- temporary TTS/audio URLs.

Diagnostics must redact:

- `Authorization`;
- `device_token` and DJConnect bearer tokens;
- any `token`;
- `audio_url` query strings;
- private HA URLs if the user chooses anonymized export.

## New Repo Suggested Shape

Suggested top-level structure:

```text
DJConnectApple/
  Package.swift or DJConnectApple.xcodeproj
  Sources/
    DJConnectCore/
      DJConnectClient.swift
      DJConnectModels.swift
      DJConnectPairing.swift
      DJConnectKeychain.swift  # token-store abstraction; retained filename
      DJConnectVoice.swift
    DJConnectIOS/
    DJConnectMac/
  Tests/
    DJConnectCoreTests/
  README.md
  PRIVACY.md
```

Core module responsibilities:

- build authenticated requests;
- serialize status/command/voice payloads;
- parse playback responses;
- classify errors: backend unavailable, auth stale, version mismatch, not
  configured, network;
- store and clear bearer token via an app-storage abstraction.

Do not put SwiftUI view logic into the HTTP client.

## iOS UI Test Fixture

`DJConnectIOSUITests` launches the iOS app with `--uitesting`. In that mode the
app uses isolated `UserDefaults`, an in-memory token store, and
`DJCONNECT_UITEST_HA_URL` for deterministic Home Assistant URL seeding. The
current UI tests cover first-run welcome dismissal, manual pairing form wiring,
Demo Mode entry/exit, compact permission rows, primary navigation, jump URLs,
Settings URL wiring, local Games menu choices, hardware-keyboard game input,
safe monkey navigation, screenshot capture cleanup, and source-level regressions
for layout constraints that are expensive to exercise reliably in every
simulator matrix. Full successful pairing, output, queue, playlist, liked proxy,
stale-auth, backend-unavailable, version-mismatch, Ask DJ, and voice/PTT UI
tests should build on this target with a real or recorded mock Home Assistant
server.

## Acceptance Criteria

- App pairs with the existing `djconnect` HA integration.
- App status posts include `client_type` as `ios` or `macos`.
- App command posts include `client_type` as `ios` or `macos`.
- HA backend playback commands work without any Spotify credentials in the app.
- Playback-changing commands trigger an immediate rich Now Playing refresh.
- Successful local pairing stores `ha_local_url` and optional `ha_remote_url`.
- Backend unavailable does not reset pairing.
- HTTP 426 version mismatch shows update-required UI and keeps pairing.
- Authenticated 401/403/404 show stale pairing/setup recovery and keep token
  until user reset.
- 401/403 during unauthenticated pairing stops the attempt and asks the user to
  verify the 6-digit code shown by Home Assistant.
- Voice/PTT uploads raw WAV to `/api/djconnect/v1/voice`.
- Local Games show Paddle Rally, Meteor Run, Sky Dash, and Maze Chase without
  HA/backend traffic, render the Maze Chase player mouth and ghost eyes, and
  reset to tap-to-play when leaving the screen.
- iOS/macOS do not host an inbound Home Assistant callback HTTP API.
- Wakeword listening and local progress timers stop when the app leaves the
  foreground and resume only when the app becomes active again.
- Automatic resume/startup refreshes and backend collection refreshes are
  throttled; explicit user refreshes remain immediate.
- Artwork loading reuses the shared 24-hour app cache for Now Playing, queue,
  playlists, and dominant-color sampling.
- Monkey Test Mode can navigate the UI without destructive backend, pairing, or
  token side effects.
- No secrets appear in logs or diagnostics.
- iOS and macOS clients can coexist with ESP32 clients in the same HA backend.
