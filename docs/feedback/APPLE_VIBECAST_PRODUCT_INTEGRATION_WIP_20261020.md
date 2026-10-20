# VibeCast product integration — WIP, 20 October 2026

Owner requested the real iOS integration and coordinated simulator qualification
in the existing API chat. This is **not complete**, not merge admission and not a
physical App Attest, public service, A→B or installed HA acceptance receipt.

## Current product source

The shipping scanner distinguishes closed TV JSON capabilities from pairing
URLs, preserving the paired owner on malformed TV JSON. Settings exposes the TV
scan flow without requiring an active Session. The one saved HA installation
requires explicit selection/confirmation. TV scanning reports detection only;
it does not play pairing success feedback before validation.

The QR parser rejects decoded duplicate keys, unknown fields, aliases, unsafe
numbers, noncanonical tokens and non-v4 UUIDs. It retains the original remaining
120-second wall/monotonic lifetime and rejects clock rollback. Public inspect
uses only the fixed API origin, no HA credentials, redirects, cookies or cache,
and bounds streamed JSON. The returned exact RSA2048/e65537 JWK must match the
QR's transaction ID, RFC7638 thumbprint, generation and original deadline.

Supported-path preparation reads the selected HA's authenticated transport
installation context, then its owner display context. Those are bounded
no-redirect reads with owner/token rechecks before and after suspension. Only
the current paired owner response can supply the canonical public HTTPS display
URL/issuer epoch; QR/local historical destinations are not authority. Background,
changed pairing and changed configured routes invalidate the scanned capability,
including an away-and-back route change.

The product preparation now encrypts the closed destination with pinned
JOSESwift 3.0.0/c2664a902e75c0426a1d43132bd4babc6fd173d3, RSA-OAEP-256 and
A256GCM. The library supplies crypto/JOSE serialization; no custom primitives or
algorithm fallback. Apache 2.0 notices ship with the app and native Legal view.
Typed service endpoints and strict enrollment/submit challenges retain original
request deadlines. All eleven captured submit client_data fields are compared;
SHA256 uses the original decoded bytes, which are retained for exact echo.

**Still missing:** durable key generation/active-key lifecycle and complete
product enrollment/assertion/submission orchestration (source-only enrollment
adapter progress is recorded below),
complete lifecycle/adversarial review, current paired HA/runtime acceptance and
positive genuine browser handoff. A prepared route currently ends with an
explicit not-ready message. No success or display consent is inferred.

## Evidence and limitations

- Six Core test functions passed, including 13 malformed-QR parameter cases,
  10 destination rejections and inspect key/revision/deadline counterexamples:
  `/tmp/djc-rendezvous-product-preflight.log`.
- Seven functions including actual AppModel routing/unsupported stop passed:
  `/tmp/djc-rendezvous-product-routing-final.log`. Final seven-function pass
  after owner pre-I/O callbacks, route ABA/background invalidation and shared
  scanner presentation changes: `/tmp/djc-rendezvous-product-scanner-final.log`.
  The intermediate owner guard run passed separately; SwiftPM serialized the
  final run behind its scratch lock, so those runs did not execute concurrently.
- Generic iOS simulator `build-for-testing` passed:
  `/tmp/djc-rendezvous-ios-simulator-build.log`.
- Actual simulator XCTest ran **one passed, zero failed, zero skipped**:
  `DJConnectIOSRendezvousTests/testSimulatorUsesProductQRAndStopsWhenAppAttestUnsupported`.
  It drove the real app's injected raw QR, disabled-until-selected confirmation,
  explicit selection, then the actual SDK `isSupported == false` finite stop.
  No API/HA/key/attest/assert operation is reached on that branch.
  `/private/tmp/djc-rendezvous-ios-first.xcresult`,
  `/tmp/djc-rendezvous-ios-first-test.log`; exported screenshot visually inspected.
  This uses an isolated test preference domain and in-memory token store,
  a synthetic QR and existing unused iPhone Duo simulator. It is not optical
  camera proof, a real selected installation, App Attest proof or positive handoff.
- The simulator binary predates subsequent supported-path owner rechecks and
  scanner presentation changes; do not claim it qualifies those source deltas.
- First UI compilation failed due to the file-private localization helper; fixed
  by using the canonical localization API. Failure log retained separately at
  `/tmp/djc-rendezvous-product-first.log`.

API's local HTTP target is finalized at protected 828fbaf; its bounded Apple
HTTP/software interop result is recorded below. Genuine verifier defaults are unchanged;
no simulator/40381/debug trust grant was added. Existing PRIVATE40381 remains
PREPARED_ONLY. No physical device action, public deployment or credential transfer.

Forecast PR162 stays preserved on its own branch; this API-lane request has priority.

## Independent review of 8db4cce and current corrections

P1/4323902925 found the direct owner-context helper accepted only installation ID
and version before issuing a local plaintext owner request. The actual client
counterexample with a synthetic URLProtocol response reproduced **two failed
assertions**: the legacy route was accepted and two requests were sent. Log:
`/tmp/djc-rendezvous-local-policy-negative.log`. The correction checks the
explicit paired local origin before any probe, then the complete existing
`DJConnectHybridLocalPolicy`, operation lifetime/epoch and server clock before
owner context. The corrected client rejects legacy policy after one request,
accepts complete qualified policy with two requests, and sends zero requests
without the selected local origin. `/tmp/djc-rendezvous-policy-positive-final.log`
passed ten functions, including this same actual-client regression.

P2/4323902933: denied/restricted camera access now exposes the existing Settings
recovery action. P2/4323902941: purpose text includes VibeCast TV linking in the
XcodeGen source, generated Info.plist and all five localized InfoPlist strings.
Actual denied-camera Settings interaction remains unqualified.

Protected API runtime handoff was read independently at
828fbaf300ca369dcc753b676295e84094d5e8c6; runtime file SHA256
27e9f5ae2a7b7350f3ae51352cf4efb023ec17f79bc8f42968cc3bdfbfe34854
matches. The initial read-only intake was later followed by the explicitly
bounded local HTTP/software execution below.
Its local HTTP derivative retains the genuine verifier; no fake/simulator/40381
trust grant or public activation is inferred. Finalization:
https://github.com/pcvantol/djconnect-api/issues/90#issuecomment-6288860618

## Latest bounded checkpoint

- Eleven targeted functions PASS after typed service/challenge additions and
  final credential-release guard: `/tmp/djc-rendezvous-dispatch-final.log`.
  The actual client also rejects owner invalidation across the transport budget
  actor hop before any HTTP dispatch. Existing artwork callers retain their
  prior behavior; the optional guard is supplied only by this owner operation.
- Latest unsigned iOS simulator build-for-testing PASS:
  `/tmp/djc-rendezvous-ios-dispatch-build.log`.
- Latest actual iOS simulator test: **1 passed / 0 failed / 0 skipped**,
  `/private/tmp/djc-rendezvous-ios-dispatch-final.xcresult` and
  `/tmp/djc-rendezvous-ios-dispatch-final-test.log`. Same explicit selection and
  genuine unsupported finite stop; no genuine key/attest/assertion effect.
- SwiftPM and Xcode lockfiles resolve exactly the pinned JOSESwift revision.
  Built Core framework license bytes match source SHA256
  `6cf63d87586c7c25c3ab8e62eef5c75bbaa982b0a6f9c00c59e2720255aac9ec`.
  Xcode's first dependency build exposed SwiftPM-only Bundle.module access;
  fixed with the existing framework-bundle-token pattern. Failed build log
  retained at `/tmp/djc-rendezvous-ios-policy-jose-build.log`.
- Localization validator PASS, 1345 keys on this branch. This is separate from
  the unmerged Forecast branch's localization count.

The complete App Attest product wiring and final submit orchestration remain open. The
separate Core B owner resolve/approve consumer also needs its own native wiring
and explicit current-Session consent. Existing six-digit Session handoff is
preserved and is not promoted into a B contract substitute. Nothing here starts
a Session, grants B display access, admits a physical SDK run or activates API.

## Actual native HTTP / software JOSE interop

The protected API828 real-root local derivative was executed read-only with its
qualified dependencies and genuine verifier defaults unchanged. A Node software
RSA recipient created one transaction; the actual native Mac Swift service sent
inspect, shipping JOSESwift encrypted the destination, and API's provenance-checked
JOSE 6.2.12 independently decrypted and compared all eight plaintext fields and
exact protected headers/digest. The transaction was then cancelled. Actual POSTs:
create 201 → inspect 200 → cancel 200. No enrollment, submit or SDK call occurred.

This exposed a real Apple defect: inspect accepted only five fields, omitting the
released transaction_id. An actual HTTP 200 with the released six-field response
and a pure released-schema fixture both failed before correction. The parser now
requires exactly six fields and binds transaction_id to the original QR. Missing,
wrong and unknown fields are rejected. Negative logs:
`/tmp/djc-native-api-http-schema-negative-confirmed.log`,
`/private/tmp/djc-rendezvous-http-CzOQ6R/native-test.log`,
`/tmp/djc-rendezvous-inspect-released-schema-negative.log`.

Success receipt: `/private/tmp/djc-rendezvous-http-JCzSK8/receipt.json`;
`/tmp/djc-native-api-http-final.log`. Targeted regression log:
`/tmp/djc-rendezvous-http-schema-final.log` (eleven executed functions plus one
opt-in skip; the opt-in test executed separately against the real local target).
Earlier setup/Swift concurrency/path-normalization failures are retained and are
not product counterexamples. Canonical private-root/owner/permission/symlink
checks remain; Foundation may normalize /private/tmp to /tmp.

Reproduction: precompile the current Swift tests, then explicitly run
`Tools/qualification/vibecast-product/run_api_http.mjs` with the exact clean
API828 checkout, prepared Swift scratch and the provenance-checked JOSE package.
The runner uses a new private capability/ephemeral server and closes it in finally;
it does not start the public service. Its test-only URLProtocol translates only
the locator/response URL metadata to loopback. Body/status/crypto are unchanged.
This is Mac native Swift HTTP plus software crypto with a synthetic HA route. It
is not public TLS/edge, browser UI, positive iOS App Attest, physical or full-chain
acceptance. Existing simulator unsupported evidence remains separate.

## Journal-to-SDK enrollment adapter (source only, not wired to product UI)

`RendezvousAppAttestAdapter` now connects an already-admitted existing key and
original typed challenge to the genuine iOS `DCAppAttestService.attestKey`.
Its public initializer always selects Apple's SDK; the provider seam is internal
and used only by synthetic tests. It creates no key, adopts no active lease,
allocates no challenge and performs no HTTP by itself. Product preparation still
reports not ready; this component is not permission for a physical run.

The adapter acquires the shared complete per-key queue, persists the existing
journal's consumed reservation before SDK I/O, then checks owner/QR/challenge
again after the storage actor hop. Key, attempt, original challenge ID, original
nonce hash and deadline must match. The journal exposes the stored challenge ID
in its reservation; its durable schema/bytes are unchanged. A required caller
registration-completion closure stays inside the same key slot through its
outcome reconciliation. That future orchestrator must use original saved request
bytes, revalidate before HTTP and avoid recursively taking the same slot.

Single-shot callback handling bounds the wait by both original monotonic
QR/challenge deadlines and remaining wall time. Cancellation, timeout and late
or duplicate callbacks cannot renew a reservation. Proof is saved only while
context remains current; failed/uncertain writes stop progression. Only Apple's
specific serverUnavailable error permits the existing same-key/hash journal
backoff, without scheduling an automatic retry. SDK error metadata is not logged
or propagated. No recovery/registration namespace is reset or reused for a new
key or new challenge.

Synthetic tests exercise failed and commit-then-error storage, restart with an
occupied reservation, different challenge/same nonce, changed context across
storage and callback, cancellation, missing/late/duplicate callbacks, original
deadline bound, immediate retry denial and held registration blocking a second
same-key SDK call. These are injected providers and memory stores, not real SDK
proof. The public adapter's iOS system branch is compiled separately below.

Remaining: durable generation/active-key admission and complete 24h/two-handle/
30-day/day27 lifecycle, assertion/submit accounting and final product orchestration,
plus the independent Core B consent consumer. Do not bridge these gaps with an
old diagnostic handle, an unqualified server fixture, a fake verifier or a local
active-key assertion. All genuine/installed/physical acceptance remains open.

Final source validation for the adapter increment:

- Ten adapter/callback functions plus QR/enrollment original-deadline functions
  PASS (12 total): `/tmp/djc-rendezvous-sdk-completion-final.log`.
- 23 existing registration-journal XCTest cases plus nine adapter functions
  passed before the final completion-uncertainty case was added:
  `/tmp/djc-rendezvous-sdk-registration-final.log`.
- Final serial full suite: **73 XCTest / 2 skipped / 0 failed**, plus
  **926 Swift Testing cases / 10 suites / 0 failed**:
  `/tmp/djc-rendezvous-sdk-final-full-regressions.log`.
- Final unsigned iOS simulator build-for-testing PASS, including the genuine
  system SDK branch: `/tmp/djc-rendezvous-ios-sdk-adapter-final-build.log`.
- Earlier intermediate compile failure exposing the journal's private challenge
  ID was fixed with file-scoped access only; the failed logs remain separate.
  The earlier 924-case full run predates the final registration closure and
  completion-uncertainty case; only the 926-case run qualifies this final source.

No genuine SDK/key call was executed. The existing unsupported simulator UI
receipt predates this unwired component and is not promoted to positive proof.
Exact-head review/CI and separate security review remain delivery gates.


## Install-local key lifecycle accounting (source only)

The resumed six-hour Apple window adds `RendezvousKeyLifecycleJournal`, using
one fixed Keychain address and a stable, independently qualified app/environment
context digest. The released API828 implementation contract and its Apple ACK
already close the generic local 24-hour/two-handle/day27-day30 policy question;
older candidate headers do not reopen it. This increment introduces no contract
change, genuine SDK call, HTTP call or runtime admission.

A generation reservation is persisted before a future caller may invoke the SDK.
Unknown callbacks keep their slot occupied after restart. Bare generated handles
cannot become active: the caller must supply an independently validated server
registration/recovery receipt with an immutable original expiry. Replacement
requires the original recovery pause plus24hours, explicit foreground retry and
the retained one-replacement-per24-hour allowance. A pending replacement and the
old handle consume both slots; recovering the old key cannot discard the pending
slot and enable a third key. Day27 foreground rollover and day30 absolute expiry
are separate. Acknowledged replacement retires old local references only; local
expiry disposal is not remote revocation or hardware key erasure.

Failed and commit-then-error storage writes never return a reservation/active
key. Repeated pauses preserve their original timestamp. Malformed records,
changed context, clock rollback, contradictory phases, extended leases and
out-of-range persisted timestamps fail closed, with bounds checked before
arithmetic. Tests use synthetic handles, injected memory storage and supplied
clocks; they neither read nor write real Keychain state.

The component remains UNWIRED. An empty lifecycle row is **not** proof that older
registration/recovery/repair journals or hardware handles are absent. Before any
initial generation the future orchestrator must reconcile that occupancy and
qualify the stable context digest and server-time source. Existing immutable
attempt journals cannot be reset or silently repurposed for rotation. This
increment does not solve generation SDK admission, actual cadence/throttle/fraud
qualification, assertion/submit accounting, final enrollment orchestration or
Core B resolve/approve and explicit current-Session consent. Product preparation
still reports NOT READY. No physical test or merge admission follows.

Validation:

- Full serial suite before the final stored-timestamp hardening:73 XCTest,
  2 intentional skips,0 failures;941 Swift Testing functions in10 suites PASS:
  `/tmp/djc-key-lifecycle-full-regressions.log`.
- Final targeted lifecycle suite:16 functions PASS, including six overflowing
  stored-timestamp cases and five forged-history cases:
  `/tmp/djc-key-lifecycle-overflow-final.log`.
- Final unsigned iOS simulator build-for-testing PASS:
  `/tmp/djc-key-lifecycle-ios-build.log`.
- Canonical XcodeGen project registers the new source/test files. No unchanged
  unsupported-UI or local HTTP probe was rerun; their historical evidence remains
  separate. Exact new-head code/security review and CI remain pending.


## Initial-generation SDK bridge (unwired source)

`RendezvousInitialKeyAdapter` adds the genuine iOS generateKey bridge for an
independently admitted initial-generation operation. The public initializer fixes
the Apple provider and the real historical-state check; injection remains
internal and synthetic. It is not connected to product preparation and executes
no genuine effect in this qualification.

One fixed installation operation slot spans registration/recovery/repair journal
occupancy checks, lifecycle reservation, the SDK callback and the required
caller enrollment-completion closure. Any occupied, malformed or unreadable
older journal stops initial generation. The stable historical binary-host attempt
namespace also blocks on any item, including a broken link or unexpected parent
link. Its contents are never read, migrated, deleted or reset. This does not
prove hardware inventory absence; qualified app/environment, foreground consent,
legacy reconciliation and the physical effect grant remain caller prerequisites.

After the durable reservation write, admission/cancellation/QR validity is checked
again immediately before the SDK. Callback waits use the original QR monotonic
expiry and remaining wall time, via the existing single-completion gate. Unknown,
failed or malformed results preserve an occupied generation-unknown slot; no
retry creates another key. A known key callback is persisted even if the UI owner
was lost, but does not proceed to enrollment in that context. Failed/uncertain
completion persistence prevents enrollment. Callback handles are not active
leases. Enrollment failure retains the existing generated handle and cannot
restart initial generation. The existing enrollment adapter separately holds the
canonical per-key slot; the initial installation slot is a distinct namespace.

This is initial-only: replacement/rollover SDK wiring, qualified context/time and
full enrollment/assertion/submit orchestration remain open, along with Core B
explicit current-Session consent. The UI continues to report NOT READY. No
physical SDK call, ordinary app update or public activation was executed.

Synthetic tests cover durable-before-SDK observation, restart/unknown result,
unsupported/missing admission, failed and commit-then-error writes before SDK and
at callback completion, owner loss during persistence/callback, enrollment failure,
malformed callback, valid older enrollment occupancy, three malformed legacy
journals, historical occupancy/unreadability and real filesystem presence/link
checks confined to a freshly created synthetic temporary subtree. No real
Keychain or private historical contents were read by tests.

Read-only new API source intake: protected379d70b558508f747d578d7b7d90a665bad7ffc8
changes only the existing unusable-enrollment-policy branch to the existing
service_unavailable503. A postcommit503 can leave one installed server key with
its original expiry, so it is an unknown outcome, never evidence for another
initial generation, fresh challenge or automatic retry. The released policy
predicate, crypto/deadlines/budgets and runtime helper remain unchanged. Exact
source/docs/helper hashes are recorded locally in
`build/qualification/vibecast-product-integration/api-policy-379-intake.json`.
The earlier API828 HTTP evidence remains historical and was not rerun/promoted.
No consumer ACK or API change was requested.


Final initial-generation increment validation:

- Final36 targeted lifecycle/enrollment/generation functions PASS:
  `/tmp/djc-initial-generation-final4.log` (including the new synthetic
  historical-path filesystem checks).
- Final serial full suite:73 XCTest,2 intentional skips,0 failures;
  955 Swift Testing functions in10 suites PASS:
  `/tmp/djc-initial-generation-full.log`.
- Final unsigned iOS simulator build-for-testing PASS, compiling the genuine
  generateKey branch without executing it:
  `/tmp/djc-initial-generation-ios-build.log`.
- No actual SDK, hardware-key, Keychain or HTTP call was made by these tests.
  Prior76bc8ea code review receipt6291346854 and CI/Trusted Delivery are green;
  they qualify that predecessor, not this new source. New exact-head code and
  separate security reviews/CI remain pending. No merge admission.


## P1 review correction: shared installation admission boundary

Exact64cfdc2 review5585494047 raised P1/4325336580: initial generation held an
installation slot, but the older journal creation methods did not acquire that
slot. A legacy writer could therefore occupy a journal between separate snapshot
awaits and the SDK call. A separate no-major-issues receipt and green64 CI do not
supersede this concrete finding; do not describe64 as an unqualified clean review.

The four existing creation entry points now acquire the same process-wide
installation slot: registration beginAttestation/prepare, recovery begin and
repair beginPause. Their private actor-isolated bodies and durable schemas remain
unchanged. Initial generation holds that shared boundary through all occupancy
checks, durable reservation, SDK callback and storage of the generated handle.
It releases the installation boundary **before** invoking the caller enrollment
closure, because that closure must create the registration journal through the
same boundary. The persisted lifecycle row already blocks repeated initial
creation. Admission/QR/cancellation is checked again after release and after
completion; canonical per-key sign/submit sequencing remains separate. No
installation→per-key nested lock dependency is introduced.

The old claim that the installation slot spans the complete enrollment closure
is superseded by this correction. These are process-local serialization and
source-only accounting, not proof of cross-process hardware inventory or genuine
runtime admission. Product preparation remains unwired/NOT READY.

A focused test holds the actual shared boundary while all four real journal
creation entry points attempt writes: each waits with no bytes written, then all
complete after release. A second bounded test runs the actual initial adapter and
creates its registration journal from the enrollment continuation, proving that
this handoff does not recursively deadlock. All15 selected initial/boundary tests
PASS: `/tmp/djc-install-serialization-final2.log`.

The first new bounded test used a task-group closure that hit a Swift region
isolation-checker compile error; it was replaced with a cancellable watchdog and
the failure log is retained separately. An optional old-source counterrun was
not executed: automatic approval rejected temporarily overwriting uncommitted
journal changes with HEAD because of possible WIP loss. No alternate overwrite,
checkout or worktree bypass was attempted. The current-source boundary tests
above were used without changing the saved implementation.


Final correction qualification: full serial73XCTest(2 intentional skips/0 failures)
plus957SwiftTesting functions in10suites PASS:
`/tmp/djc-install-serialization-full.log`. Final unsigned iOS simulator
build-for-testing PASS: `/tmp/djc-install-serialization-ios-build.log`.
The new bounded concurrency tests use memory journals and a synthetic SDK; no
real SDK, Keychain or hardware effect was executed. New exact-head review/CI is
required; no merge/physical/product admission is implied.
