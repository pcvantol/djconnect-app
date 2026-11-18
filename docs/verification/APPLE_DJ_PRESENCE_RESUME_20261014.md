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


## Native confirmation and owner-approved build40057 installation

Mac isolated all-five Presence case finally PASS39.718s, one test, zero failures,
using c076e16 AX-value/readiness runner and unchanged00ba403 proofapp. Pending,
five confirmed choices/revisions and paused-session noninterference checked
against frozen Core SDK fixture. Evidence retained in
`/private/tmp/djc-presence-mac-c076e16-axvalue.{log,xcresult}`. This is isolated
native qualification, not production Core acceptance. Existing restoration
case PASS15.567s remains separately qualified.

Owner explicitly approved latest installation on Mac mini, MacBook and iPhone.
Signed Mac/iOS build40057 succeeded; full519 tests PASS57.233s on c076e16 input.
All three actual installed bundle readbacks show4.0.0/40057. Both Macs opened
with visible main windows; after owner unlocked iPhone, real devicectl launch
succeeded (process3847), with no fixture arguments. App backups and preference
exports retained under existing40057 backup roots. No uninstall, pairing reset,
HA update or forced quit performed during these installs. MacBook transferred
artifact SHA2564938a917b17e125789f1f7e790b1b80c059729547f729df4c9678c5732ecb386
matched; mini installed payload36files/symlinks matched build. Preference
backup does not imply independently verified pairing equality: standard-plist
comparison had zero selected keys and supplies no such proof.

MacBook desired-state verification reported required development-tooling drift;
no repairs were made. It was an app-consumer install, with no source mutation
or build there. Mini development host verification MATCH.

Production Core Presence capability/selected_presence/revision absence remains
a separate owner deployment dependency. No merge or Finalization is implied by
private installation. Draft107 still has separate protected-delivery gates.

## Mac presentation followup (owner requested)

Hide native window toolbar throughout splashscreen and reveal only after splash
fade removal completes. Keep root content mounted for startup work. Standardize
Mac outer top inset to12points for playlist/queue rows, saved sessions, Ask DJ,
settings, logs and active/idle session views; remove duplicate outer insets and
move Ask DJ top anchor out of stack spacing. Existing hero screens, About,
Legal, Privacy, Games and Now Playing already use12points. Card-internal
padding remains intentional. Mac saved-session ScrollView removes native List
header reservation; iOS List and its native refresh bridge remain mounted.
Verification: Mac unsigned build40058 PASS; device installation remains40057.

Final source verification for this presentation followup: unsigned Mac and iOS
build40058 both BUILD SUCCEEDED;519 package tests PASS58.074s; git diff --check
PASS. Independent technical source review GO, no concrete P1/P2. Native visual
splash/padding, jump-top and archive keyboard-layout qualification has not
been executed for this followup. Do not infer these checks from prior Presence
native probes or installed40057. Installation checkpoint registered at Apple87
comment6172022791.


## Mac layout native checkpoint (continuation)

Fresh canonical host verify MATCH. Same writer; productbc280fd includes80639f8
layout plus DEBUG/--uitesting-only6s observation hold and splash AX marker.
Normal minimum stays1.5s. Native unsigned build-for-testing and iOS build PASS.
Existing release/bundle regression PASS; prior519 full-suite remains bound to
80639f8 layout, not inferred as a new full-suite run for the probe-only change.

Initial test configuration failed before execution because __TESTROOT__ resolved
relative to copied .xctestrun; fixed to absolute own build-product paths. First
actual native route run captured correct splash and seven screens, then failed
at Queue: actual hierarchy and screenshot prove Music DNA opt-in sheet remained
open. No Queue product fix invented. Test driver now declines native opt-in via
Niet nu and requires enabled/hittable controls; ordinary app/preferences untouched.

Final isolated native test PASS79.616s, one test, zero failures. Confirms toolbar
hidden during observed splash and visible only after removal; waits on each of
15 real screen IDs before capture; opens readonly demo archive, returns and
asserts archive timeline disappears. Proof app bc280fd unchanged; test-driver
opt-in correction is separately tracked. Test-only synthetic demo data, no live
HA/pairing/Profile mutation. Actual Mac window960x899. Evidence retained:
`/private/tmp/djc-mac-layout-native-optin.{log,xcresult}` and attachment manifest
`/private/tmp/djc-mac-layout-optin-captures/manifest.json`. No explicit Ask DJ
search/jump-top assertion was performed; these are not promoted from route proof.

Independent first-seven visual review GO: consistent narrow outer top gap,
intentional demo headers, no clipped firstcard or toolbar overlap. Remaining
captures submitted for visual review. Installed devices remain40057; no new
installation or protected merge/Finalization performed during this followup.

Actually read latest handoffs: Apple6171716530 pushfinding and6171961379 final
Core dialogue pin; Core6171726870 matching pushownership audit. Keep push diagnosis
separate from layout/Presence candidate, with no testpush or provisioning change.
Core dialogue producer delta is now published at7698961, superseding the earlier
preliminary-baseline-only status; native Apple adoption remains separate. Downloaded
final fixture bytes SHA2569be892d55c8aaee4871e54ac68ed04945fb0676ce5472e2091a83ee66b2151a8
matches handoff; this read/checksum is not consumer acceptance or HA deployment.

Remaining native visual review GO: Queue, Playlists, Games, Settings, Logs,
About, Legal, Privacy and archive-return inspected from final captures. Narrow
outer top inset consistent; no toolbar overlap/clipped first card. Long content
continues inside scroll areas. This is native demo qualification at the tested
window size, not physical-iPhone/production acceptance or VoiceOver traversal.


## Post-merge40058 receipt and bounded glass-banner followup

Owner specifically authorized88fd6e9760b4c7fde4381593897c74d88bddf547 and protected
merge. Owner Authorization38601665444 PASS artifact verified; mandatory checks
PASS, no admin bypass. PR107 MERGED as e2f96120ae25cd975da3bb3ec7f77711cc2a9b0b.
Signed40058 actually installed/readback/launched on mini, Book and physical
iPhone. Both Macs matched42payload entries and retained four pairing fields;
iPhone retained four configuration fields (Keychain equality not independently
tested).155code/testinput files equal merged main. Backups/40057 originals kept;
normal Mac quits, no force/uninstall/pairing reset/HA update. Source/DAG checkpoint
registered Apple6173714222/Core6173714763. Finalization explicitly excluded.

The post-merge coverage job of38601880410 FAILED one of519 tests while ordinary
CI PASSED. Actual failure at SessionHistoryContractTests2033: an active-read
fixture advanced contradiction4→older3→newer5 for every request. Broadcast HTTP
recovery legitimately performs another active-read. Exact Xcode coverage red
reproduction retained in `/private/tmp/djc-presence-coverage-diagnose.{log,xcresult}`:
reads3, floor5, confirmedoccasional at the second assertion. Product correctly
accepted the newer confirmed state; this is a fixture-readrace.

Separate test-only fix62a0265 holds explicit server phases using existing
PresenceReadPhase; original floor/confirmation assertions and real model/HTTP/
recovery routes remain.25Xcode-coverage repetitions PASS, then full519coverage
PASS53.263s (`/private/tmp/djc-presence-full-coverage-phase-fixed.{log,xcresult}`).
No productguard, transport, workflow or threshold changed. Independent source
review GO; old failed post-merge run remains FAILED, not rewritten as PASS.

New owner request: put About banner in glass card. Separate a9809d1 replaces
AboutBanner's opaque gradient/multiply overlays with shareddjSessionFrostedSurface;
icon/text/padding/layout stay. Shared banner includes About and Privacy. Unsigned
Mac/iOS40059 builds PASS; bounded technical source review GO.

First native15route PASS70.138s is NOT new glass visual proof: inherited target
DYLD_FRAMEWORK_PATH loaded old UI module from prior runner products. Independent
visual review caught the still-dark banner. Old captures preserved/unqualified.
Correct own test configuration now binds to proofapp's embeddedUI/Core modules;
actual lsof loaded-image paths confirmed, retained in
`/private/tmp/djc-about-glass-loaded-frameworks.log`. No product workaround.

Correct bound native case PASS69.549s, one test0failures; actual About/Privacy
captures independently reviewed visualGO: frosted fill, visibleborder, readable
text and proper icon containment/spacing. Evidence:
`/private/tmp/djc-about-glass-native-embedded-frameworks.{log,xcresult}`; correct
attachment manifest `/private/tmp/djc-about-glass-native-correct-captures/manifest.json`.
This is isolated native demo qualification;40059 not installed or protected
merged. Existing writer integrated the already-protected main via ordinary
merge, without resetting history/WIP. Two untracked projectcopies remain.

## PR108 protected merge and bounded UI/output follow-up

PR108 exact candidate442db204fadc0c6dd026463a4eba119bc2182744 was owner-authorized
(run38607061008) and protected merged as aa65e902d8f5c05b9044708edca9730ac884e8d7.
Main run38607375724: Post-merge coverage evidence SUCCESS; ordinary CI FAILURE
at queueSelectionWaitsForOlderQueueReadThenFetchesFreshRows loadingQueueItemIndex
assertion. The original Presence coverage failure is repaired; ordinary CI is
not declared green. Failed receipts remain preserved.

The queue test previously stopped when fresh rows became visible, before the
command refresh task's cleanup. Its wait now requires both the new rows and
loading completion, without removing any final assertions or changing product
queue scheduling. An intermediate full520 coverage run passed52.793s; full521
passed52.495s; the final expanded suite is recorded below separately.

Additional direct user findings handled in this bounded follow-up:
- Mood marker: fixed28pt circle and symbol overlay; animate horizontal offset
  only, disable symbol baseline interpolation. Native motion proof is separate
  from source geometry review.
- About/Legal/Privacy: outer card gaps consistently24pt (previous28/20/24).
- Archive context bubble: use the same root-selection path as sidebar Ask DJ,
  withdrawing the pushed archive before replacing its root. Native assertion
  requires archive disappearance, Ask DJ visibility and selected context.
- Outputs: explicit device active flags outrank an older playback snapshot.
  Reproduced double-active state and wrong selectedOutput in
  /private/tmp/djc-output-stale-red.xcresult before product correction.
  Accepted set_output immediately reads devices; acceptance itself does not
  manufacture confirmation. Both empty acknowledgement and acknowledgement
  containing old devices are covered.
- Rapid output switching: fence response/error application and each transport
  attempt to the originating output-selection generation. Reproduced late-A
  replacing confirmed B in /private/tmp/djc-output-late-red.xcresult, and a
  superseded A remote-fallback write in
  /private/tmp/djc-output-fallback-red-compiled.xcresult. Subsequent read/write
  attempts for a superseded selection cancel before dispatch.

Sole writer remains codex/apple-dj-presence-v1 in the existing recovery source;
ordinary merge e64bed6 integrated approved main without resetting WIP.
Fresh authoritative host verification MATCH in
/private/tmp/djc-pr108-followup-host-verify.log. Restricted verification could
not see Docker/network state; it was not treated as authoritative host drift.
No ordinary installation, pairing change, HA mutation or Finalization occurred.
Installed build remains40058 on the three previously verified devices.

Native first follow-up attempt failed because its copied xctestrun retained
UITargetAppBundleIdentifier=dev.djconnect.mac.aboutglassproof despite a new
proof-app path. The fixture configuration is corrected, old failed receipt
retained; this run is not native acceptance.

Final follow-up validation:523 Core tests PASS52.679s with Xcode coverage
(/private/tmp/djc-apple-followup-final.xcresult); unsigned final iOS build PASS
(/private/tmp/djc-apple-followup-ios-final.log); Mac build-for-testing PASS
(/private/tmp/djc-apple-followup-native-final-build.log). Independent technical
review source GO after closing both output races.

Corrected native proof PASS77.168s,1test0failures
(/private/tmp/djc-apple-followup-native-final.xcresult). It exercises15root
screens, archive overview return, then the actual archive bubble action:
archive disappears, Ask DJ appears, selected context remains visible.
Loaded UI/Core paths were read from the running proof PID and both resolve
inside /private/tmp/djc-apple-followup-final-proof.app/Contents/Frameworks
(/private/tmp/djc-apple-followup-final-loaded-frameworks.log).
This is isolated native proof, not ordinary installed-device acceptance.
Slider motion correction has source geometry review; this navigation probe
alone is not a frame-by-frame motion qualification.
