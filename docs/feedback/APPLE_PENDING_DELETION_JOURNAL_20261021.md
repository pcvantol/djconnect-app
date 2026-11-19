# Preserve unconfirmed archive deletion operations

Local successor to `32ed743`. Single-session and server-snapshot bulk deletion
now retain their original operation ID and typed request parameters before I/O.
An installation-local preferences journal stores only request references and
hashed authority bindings, with no bearer token, endpoint or conversation text.
The write is synchronized and read back before dispatch; a failed write blocks
dispatch. The journal is bounded to32 owner/device records and262144 bytes.
Malformed/oversized data fails closed. Reset/suspend, view disappearance and
model reconstruction do not discard unresolved operations.

Only an exactly admitted receipt or a definitive HTTP rejection clears a record.
Timeout,503, unreadable/wrong-owner receipts and invalidated in-flight context
remain unknown. No new single or bulk operation can be created in that owner/
device scope, including after the original five-minute window. The UI states
that deletion is not confirmed and ordinary refresh only reads history. All
five locales are translated. Receipt admission, active-session preservation and
the no-automatic-replay transport remain unchanged.

This increment deliberately adds no explicit replay button or operation-status
endpoint. Typed request parameters and original identity are retained; a future
recovery implementation must reconstruct/validate the complete original wire
body and authority before any explicit same-ID attempt. Do not claim byte-for-
byte frozen authenticated wire storage, provider completion or successful
reconciliation. Expired ambiguity remains unknown; it never buys a fresh ID.

## Qualification

Imported Core1251's original archive-deletion receipt byte-for-byte as
`Tests/Fixtures/archive-deletion-core-bbb7a23d.json`, SHA-256
`79fac1e077a157df0851797c84de2f1f61bc14be08f3048c703ba9acec9f2a67`.
New tests use its exact pending503 body; only snapshot clocks are explicitly
rebased for the isolated synthetic current-time client. Existing history fixture
provides the separately declared archive/model bootstrap. This is not a new
actual-HA wire execution or individual-content deletion qualification.

Final complete run: four Swift Testing functions /23 parameter cases PASS,
0 failures,0.794 seconds. This includes unknown single/bulk preservation,
original operation ID/parameters matching the captured POST, no second POST,
model reconstruction, old/expired records, metadata changes, malformed/oversized
journals, exact success/conflict cleanup and existing active-Flow fences.
Final unsigned isolated iOS Simulator build-for-testing PASS. Localization
validator PASS1378 keys/five locales; diff check PASS.

An additional metadata regression was reproduced before correction: both pending
cases failed with16 issues and a second synthetic POST became possible because
the journal lookup key included evolving installation metadata. The stable key
now uses owner/device identity. Installation/endpoints/credentials/app identity
remain separately hashed in the stricter execution binding. The same regression
passes in the final run. This fault was in new local WIP, never installed.

One earlier combined run reported an active-timeline equality failure. Isolated
and combined diagnostic runs did not reproduce it. Final tests also require a
successfully completed, non-loading active baseline and retain the original
full post-delete equality assertion. No assertion was removed. The exact cause
of that initial observation remains undetermined; it is not erased or called
a proven product fix. Native/full-runtime stability acceptance remains open.

Earlier attempts include a test-only nested-macro compile failure and a build
rejected because test labels were edited during compilation. All logs remain
preserved. They are not claimed as product failures or completed passes.

## Producer and remaining work

Core reports source1251 `bbb7a23da015de5887eff4103efed9981f12b0bd`, separate
Final1252 `2a1197c441079896bdfdfdc5a2c732146f54ccd3`, and HA-dev installation.
Apple independently read the private installed receipt:228 matching files,
zero personal erasure requests, native/audio/user acceptance NOT_RUN. Receipt
SHA-256 `fad146553bb7113feb252147176f56f22d501cde406a615af8f6f5eb9a9afee2`.
This is producer receipt readback, not an Apple authenticated live delete.

Core's forthcoming individual-content prepare/cascade and read-only operation
status contracts are not frozen. No guessed route or capability is exposed.
Requirements were sent to the authorized Core writer: original entry/moment/
message/client_message_id, server-determined whole-exchange scope, opaque bound
confirmation, pending/committed/rejected/expired-unknown statuses, late-response
suppression and no Session-end/playback/DNA effects. Existing UI WIP remains.

No app installation, real personal deletion, model call, OS permission change,
external issue/PR publication or night-timer restart occurred. Same-ID explicit
recovery, independent review, actual native gestures, cross-process/power-loss
durability and live owner acceptance remain unqualified. Reconstructing models
from synchronized preferences is not an actual application crash test.

## Evidence

- Final tests `/private/tmp/djc-pending-deletion-journal-20261021-scope-qualified.log`,
  SHA-256 `d3bc330de500eaaf6f21a415bfea60c86d7f500bee819521d2e587f705392c40`.
- Final iOS `/private/tmp/djc-pending-deletion-journal-20261021-ios-qualified.log`,
  SHA-256 `e04634139b0ea12c2013505a44d0c0a282203bdf62763067763b92d12a57964b`.
- Preserved prefix `/private/tmp/djc-pending-deletion-journal-20261021-` includes
  mac.log, qualified.log, final.log, complete.log, active-diagnostic.log,
  baseline-diagnostic.log, scope-negative.log and earlier iOS logs.
