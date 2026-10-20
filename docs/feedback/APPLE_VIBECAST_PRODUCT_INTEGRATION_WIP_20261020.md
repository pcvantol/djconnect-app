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

**Still missing:** shipping JOSE encryption, durable genuine App Attest key/
enrollment/assertion adapter, exact original client_data binding and submission,
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
