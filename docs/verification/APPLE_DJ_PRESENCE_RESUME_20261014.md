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
