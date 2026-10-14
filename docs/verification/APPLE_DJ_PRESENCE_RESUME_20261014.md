# Existing Apple Presence lane — resumed execution

Assignment `DJC-APPLE-DJ-PRESENCE-V1-20261011`; sole writer remains
`build/apple-40017-recovery/source`, branch `codex/apple-dj-presence-v1`.
Resume baseline `2c19a42cad7aa9bff3ddc27b80ae8a233dd69eaf`, tree
`a9579b5663277ea02a8e7e884aa83941f3363a4a`; no tracked WIP at pickup.
Both untracked project copies, original primary-checkout WIP, binaries,
preferences, backups and private recovery receipts are preserved.

## Read assignment and admission

Fully read Apple comments: 6150506243, 6164553746, 6164451370,
6163452291, 6154408539, 6154194577, 6154234425, 6166231708.
Newest relevant Core updates read: 6167514508, 6165467841, 6164562561,
6164458373, 6163400065; causal ACK6154657387/6154316067 also read.
No later Apple instruction was present at pickup. Actual ACK/RUNNING:
[Apple6167796846](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6167796846).
Fresh canonical host/workspace verification exits0/MATCH; no build/install
was running. No reset, new writer, installation, HA update or restart.

Mac mini and MacBook installed app readback is40034, distinct from built
Mac/iOS40054. Existing40034 receipts remain authoritative for earlier
installation. Their consumed exact-process force-quit grants are not reused.
Current device discovery reports disconnected physical destinations; previous
phone receipt40034 does not establish current device availability.

## Exact installed Presence cause

Public capabilities on the existing configured route: HTTP200, version
4.0.0-rc.1, all three v1 Presence fields absent: capability boolean,
contract_versions.active_session_presence, top-level active_session_presence.
A probe linked to the existing shared Core decoder decodes successfully and
returns presenceAvailable=false. Core decoder sources are unchanged from
installed40034 source36de3c to the resume baseline.

After specific owner authorization for exactly one authenticated active read:
HTTP200/application-json, runtime_state=active, outer Session ID equals the
Broadcast Session ID. selected_presence and presence_revision are absent at
both levels, not balanced/integer0. Shared DTO decoding succeeds and retains
nil fields; confirmedPresence=nil. No private IDs, body, token or host is
retained in this public report. The two concrete UI failures are therefore
presenceAvailable=false AND confirmedPresence=nil, already at the producer
response, rather than a revision0 decoder or action-WebSocket prerequisite.

Separate installed-record/disk readback identifies source69315f43 and absent
session_presence.py/session_mood.py. Loaded HTTP response and disk evidence are
separate observations. No automatic deployment action follows this diagnosis.
Minimal sanitized readbacks and current producer-delta request were sent to
[Core6167893947](https://github.com/pcvantol/djconnect/issues/1101#issuecomment-6167893947)
and its subsequent active-read follow-up. The Core owner owns deployment/
serializer reconciliation; Apple cannot establish installed Presence support.

## Bounded client repair

The previous shared capability function collapsed fetch failure, fetching,
unsupported metadata and not-yet-loaded state into the same false Boolean.
The popover displayed the generic connection-unavailable message for them all.

AppModel now records a bounded capability status alongside the existing guarded
availability predicate. Fetching, supported, unsupported, temporary failure and
incompatible response are explicit; reset/owner epoch fences remain intact.
Runtime presence tuples are neither cleared by a capability read nor invented.
The native control distinguishes loading, transient failure, unsupported,
incompatible response, no valid active Session and invalid confirmed state in
all five languages. Opening the existing control triggers only authorized
active/capability reads; Session, owner epoch, popover identity and foreground
are revalidated between reads. No new poller or write replay.

Regression sequence: balanced/revision0 → supported → HTTP503 transient →
supported retry, with the same confirmed tuple and only GET requests. Its
pre-fix capability-handling run fails3 assertions; after repair it passes.
Additional cases cover loading plus late supported reply after newer unsupported
read, malformed Boolean metadata and preservation of confirmed state. Existing
partial events, reply races, CAS/nonreplay and owner/Session withdrawal tests
remain unchanged.18 focused Presence/Mood tests PASS2.031s; localization1090
keys PASS. Full suite, fresh native builds and connected qualification are
recorded separately as they complete, not inferred from this focused run.

## Explicit additional-finding ledger

| Finding | Disposition in the existing lane | Remaining evidence / owner |
| --- | --- | --- |
| Presence unavailable615/6164451370 | Current Presence diagnosis and bounded native presentation repair | Core deployment mismatch remains installed acceptance blocker; no automatic HA change. |
| One Ask DJ / speaker / queue actions6154408539 | Existing shared bubble and dispatcher reuse retained; immutable authorized live message adapter exists locally | Current rich response/history subset parity and actual new result_set/action contract belong to the selected dialogue adoption; current final producer delta requested. No blanket historical action enabling. |
| Unrequested playback6154194577 | Blocking dialogue acceptance finding retained | Core causal previous-question fix is local producer evidence; Apple effect-inert receive/selection and explicit action checks remain. No live playback reproduction or local intent parser. |
| Artist/result identity6154234425 | Coupled dialogue adoption / acceptance | Exact result-set action IDs, frozen order, expiry and text-choice/button parity need the final producer delta; no current-player artist substitution. |
| Direct feedback/update latency6154408539 | Coupled acceptance; existing pending and guarded state processing retained | Core projection receipt is an early baseline; native receive→reducer→render latency is not measured or claimed. |
| Intra-track Moment visibility6163452291 | Coupled blocking joint-session acceptance finding | Current card uses native admission; active timeline has showsFlow=false and retained history. Producer publication, current-only, active-flow rights and archive subset require separate same-track trace. No showsFlow blanket enable, local generator, deadline extension or archive bypass. |
| Early transport6166231708 | Read/checksum-qualified input only, not an implementation/publication pin |13 parsed real transport examples, source4f1bc49, pre-final queue/control boundary; SHA2563f2592dfdd61286a32dc233998166012c451f3c941d2c8d5c8a635056fa68006. Exact final delta awaited. |

The original hybrid transport successor remains queued, without a second writer
or new consumer implementation. Core owns the living roadmap/DAG. Requested
reconciliation: Presence consumer is in progress, producer contract/policy stays
Completed; installed/joint acceptance remains open due to the measured deployment
delta and separate intra-track finding; dialogue/transport consumers are not
promoted to Completed from early fixtures or Apple presentation builds.

## Delivery boundary

Draft source PR107 remains distinct from protected merge and separate
Finalization. Earlier105/106 exact-SHA grants are closed and not reused.
No current source-main/artifact/installed/native PASS is inferred from local
builds, older screenshots or an operational comment. Existing native acceptance
must use the exact candidate and isolated app identity, preserving ordinary
installed apps. New installation is not authorized by this resume instruction.


## Current code qualification — 5e1b2db / build40056

Product/test candidate5e1b2db8cccffbc18952b2e793f7271626536acf,
tree535890d12a66549aaa326d2288cdfdcfc07f1c84; both independent technical
and localized-copy reviews give bounded GO. The only delta from full-suite
candidatef87d43f is five unsupported-state translations naming the DJConnect
integration rather than the Home Assistant platform. Full519 tests PASS57.313s
onf87d43f;18 targeted tests PASS2.031s; localization1090 keys PASS. Exact5e1b2db
signed Mac/iOS40056 builds and unsigned native test builds PASS. No installation.

All155 tracked Sources/Apps/Tests files in the temporary qualification input
match the sole writer. Previous40054/40055 binaries and all original evidence
are preserved. Private immutable input/evidence hash receipt:
`/private/tmp/djc-resume-5e1b2db-qualification-receipt.json`.

Connected isolated native proofs use the checksum-qualified frozen Core producer,
real ordinary pairing/Profile/Session/CAS/Broadcast and synthetic music only:
NL/DE/FR/ES on iPhone Simulator and EN on iPad Simulator with largest accessibility
text all PASS, exercising five Presence positions, pending versus confirmation,
paused changes and unchanged Session/Mood/playback/HA identity. This does not
prove production deployment, physical-device installation or intra-track Moments.
Native results are bound to5e1b2db; logs/xcresults remain private in `/private/tmp`.

The first iPhone attempt failed before app interaction because fixture port18191
was mapped as18213. Only the isolated fixture was corrected; the original failed
result is retained. The subsequent connected proofs use18213 successfully.
The first iPad app.screenshot() output has the known landscape/portrait-canvas
capture defect. An additional exact-candidate connected iPad run PASS and captures
unmodified full simulator display in landscape. Independent UX review gives
bounded largest-text containment/readability GO. Capture filenames are timing
labels only: fullscreen-presenter.png visibly shows Balanced after the test
advanced, and placement is already partly scrolled. Neither is presented as
exact-state screenshot proof; functional five-position assertions are separate.

After explicit approval, exactly the new temporary Mac UITests runner and
`djc-mac-presenceproof-5e1b2db.app` were ad-hoc signed and strict/deep verification
passed. The authorized isolated Mac run fails BEFORE test execution: XCTest
Code1000, “Timed out while enabling automation mode.” Mac native qualification
therefore remains BLOCKED_HOST_AUTOMATION, not PASS or a Presence assertion
failure. No permission database, system automation setting or ordinary app was
changed. Ordinary Mac mini DJConnect PID58349 remains running40034.

PR107 remote head remains2c19a42 at this checkpoint; code5e1b2db remains LOCAL.
OwnerAuthorization is missing for the new exact source candidate; source merge
and separate Finalization are not authorized by native-test signing approval.
Core producer/current deployment reconciliation remains an installed acceptance
blocker and was handed off at Core6168147619. No newer Core-owner delta was
present on the readback following that handoff.


## Authorized Mac host recovery and executed follow-up

Owner explicitly approved only Developer Tools mode enable plus the same isolated
Presence test. `DevToolsSecurity -enable` succeeds; fresh status enabled. Same
signed5e1b2db temporary bundles are unchanged. XCTest now initializes and executes
the actual native case; it finds/taps the balanced Presence toolbar button, but
cannot find the popover or music_only choice. The run FAILS; no native PASS.
Result: `/private/tmp/djc-resume-mac-nl-5e1b2db-devtools-enabled.xcresult`;
log/evidence SHA recorded in `/private/tmp/djc-presence-mac-devtools-receipt.json`.
Ordinary Mac mini app PID58349/build40034 unchanged. No TCC reset, installation,
HA/pairing change or protected merge. Developer Tools mode stays enabled as
explicitly authorized; this does not establish the later popover failure cause.

Exported AX/video show no popup. Existing process-manager log confirms the test
app came to foreground. Independent review cannot yet distinguish scene-phase
withdrawal, toolbar reconstruction or action/presentation failure; none is
asserted as root cause. Native CUA inspection also fails at its own symlinked
writable-root bootstrap, without changing Codex configuration.

A bounded diagnostic candidate adds payload-free lifecycle trace ONLY under
DEBUG + --uitesting + explicit DJCONNECT_PRESENCE_TRACE=1. It records fixed
events and booleans (scope, scene/native activity, foreground, Session/epoch
matching), never IDs/credentials/private bodies. Existing actions/authority
checks remain unchanged. The native regression checks enabled/hittable first,
then captures full display and stops cleanly on the opening failure, preventing
secondary missing-button crashes. Independent technical source review GO.
Unsigned diagnostic Mac build-for-testing PASS; focused Presence/Mood tests are
recorded separately. Initial diagnostic compile failure/private accessor and
zero-match test-filter attempt are retained and do not count as tests passed.
These are new temporary diagnostic bundles: prior exact signing grants are not
reused; they are not run or signed without specific approval.


## Executed diagnostic proof and native restoration prerequisite

Owner continued the prepared exact b03e232 two-bundle trace step. Those two
bundles were ad-hoc signed/strict verified and the isolated native case executed.
It FAILS before any Presence activation: AX process has MenuBar but no Window;
fixture pair/capabilities/active responses all HTTP200. Result and28.016s failure
remain in `/private/tmp/djc-presence-mac-b03e232-trace.xcresult`. No console trace
was available; later diagnostic logging uses gated NSLog rather than stdout.

A separate launch of the same exact proof executable confirms its PID/path.
AppKit logs the savedIdentifier DJConnectMainWindow passed to the valid
SwiftUI.AppWindowsController restorer; completion returns window0x0/errornull,
then ordering is skipped because no restoredWindow exists. Source
WindowConfigurator assigns that same custom value to NSWindow.identifier.
This is concrete native restoration mismatch evidence, distinct from production
Presence metadata absence and from the earlier popup-not-found result. It does
not yet explain the latter popup lifecycle, which still needs its actual trace.

Bounded Apple prerequisite repair: preserve SwiftUI's native restoration ID;
assign DJConnectMainWindow only as accessibility identifier, and use that AX
marker for About/Settings centering. No saved-state deletion or forced startup
window, no Profile/intelligence/authority behavior changes. Independent source
review GO for this prevention fix, explicitly not a legacy production-state
migration receipt. Existing bad saved-state may still require native New Window;
this patch cannot rewrite a record whose WindowConfigurator never executes.

The independent native restoration case records initialWindowPresent, uses
native New Window only when needed, then tests normal Cmd-Q and ordinary relaunch
without deleting saved-state. It qualifies windowcreation/restoration only,
without Session/toggle dependencies. Review found/fixed that initial test
ordering assumption; final bounded source/test GO. The separate Presence case
continues to initialize its own Mac owner/active Session and assert a main window
before its five-position proof. New current unsigned Mac test build PASS;
23 focused Presence/Mood tests PASS2.150s after gated NSLog change. No new native
PASS, physical installation or automatic legacy-state migration is claimed.

This prerequisite stays explicitly inside the existing Apple native acceptance
work, not a new general audit or roadmap transport writer. Diagnostic code is
local; remote draft107 remains25a5e92, protected delivery/Finalization remain
separate. The ordinary Mac process58349/build40034 is unchanged. Only the manual
isolated proof process was stopped after exact executable verification.


## Executed00ba403 native cases and bounded mouse-event successor

After explicit owner approval, exactly the new00ba403 runner/proof bundles were
ad-hoc signed and strict/deep verified. Both native cases were actually run,
sequentially. Window-restoration FAIL66.789s: initialWindowPresent=false,
then native New Window interaction times out waiting for menu-open notification.
Normal quit/relaunch was not reached. Presence FAIL at its strict main-window
precondition, before any Presence click/mutation. These outcomes neither prove
restoration repaired nor establish the popup lifecycle cause. Separate xcresults,
logs and hash receipt `/private/tmp/djc-presence-00ba403-native-receipt.json`
are retained. No production installation, state deletion or settings change.

Official local XCUIElement.h distinguishes XCUIElementTouchEvents.tap from
XCUIElementMouseEvents.click. A bounded successor changes only the five menu/
button event calls in these two Mac cases to native mouse clicks; all fixture
policy/assertions and product code remain unchanged. Independent test-source
review GO; actual new unsigned build-for-testing PASS. This is a test-input
correction hypothesis, not proof that touch calls caused prior failures. The
mouse trial must qualify windowcreation, normal restoration and Presence as
separate boundaries. It reuses the unchanged already-signed00ba403 proof app;
only its new temporary runner needs signing authority. No new native PASS or
expansion of an earlier exact-bundle grant is inferred.


## Actual native mouse receipts and owner About-build request

Exact approved8fad074 temporary runner signed/verified; unchanged signed00ba403
proof app reused. Window case PASS15.567s: initialWindowPresent=false was recorded,
native New Window successfully created it, normal Cmd-Q ended the app, ordinary
relaunch restored the AX-marked main window. No saved-state deletion. This proves
future restoration after native new-window creation, not automatic migration of
existing production records. Earlier touch/menu timeout results remain retained.

The actual mouse Presence case opens the popover and completes guarded active/
capability reads. Structural trace keeps scope=true, scene/native/foreground
active, Session/epoch matching throughout; the earlier dismissal/reconstruction
hypothesis is not supported for this run. Real frozen Core confirms first
music_only change/revision1 and native screenshot shows confirmed Alleen muziek.
Full case nevertheless FAILS: Mac StaticText exposes confirmation in AX value,
while test read label; subsequent element-readiness assertion and auto-scroll
fail. No all-five native PASS is promoted from the first acknowledged choice.

Successor test driver reads AX value (label fallback/OR predicate), scopes choices
to the actual popover, waits for real enabled/hittable state, preserves the same
Core/pending/invariance assertions and fails cleanly with full capture. The
same readiness helper covers five choices and paused-balanced. Independent
bounded source review GO; new unsigned native build PASS. No coordinates,
activation bypass or product authority change. Only a new temporary test runner
requires signing; the00ba403 proof app is unchanged. Current gate remains native
all-five confirmation, separate from installed Core capability deployment.

Owner additionally requested build number in Over→Versie. Separate commit5536693
changes the shared About row to actual releaseVersion (CFBundleVersion), e.g.
4.0.0 (40056). Swift build PASS14.53s. It is source-only; ordinary Mac mini still
runs40034, no new app installation. This owner-requested presentation delta is
separate from native proofapp00ba403 and is not inferred as runtime-tested there.
