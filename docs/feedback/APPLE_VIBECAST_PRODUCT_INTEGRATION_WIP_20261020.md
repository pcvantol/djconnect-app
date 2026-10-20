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
QR's RFC7638 thumbprint, generation and original deadline.

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

**Still missing:** durable genuine App Attest key/enrollment/assertion adapter,
SDK attempt accounting integrated with the existing journals, final submission
orchestration,
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

API's new local HTTP target remains separately gated pending its protected
supplier-pin repair/final receipt. Genuine verifier defaults are unchanged;
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
matches. This is intake only: the API target has not been executed by Apple.
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

The real App Attest adapter and final submit orchestration remain open. The
separate Core B owner resolve/approve consumer also needs its own native wiring
and explicit current-Session consent. Existing six-digit Session handoff is
preserved and is not promoted into a B contract substitute. Nothing here starts
a Session, grants B display access, admits a physical SDK run or activates API.
