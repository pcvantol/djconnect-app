# VibeCast native qualification (API0.4 draft)

The historical cases below retain their original evidence scope. The separate
[API-issued binary SDK intake](API_BINARY_INTAKE.md) adds12 pure intake/dispatch
cases (22 package cases total), a direct DeviceCheck hosted path and a concrete
signed build40380 profile **proposal**, not API admission or a live proof.
Source permission is now the released djc-rendezvous/1-implementation.1; historical
draft labels here do not override that source release or grant runtime GO.

Assignment `DJC-APPLE-VIBECAST-OWNER-SCANNER-V1-20261016`, existing Apple writer.
This directory is isolated qualification tooling. It is not imported by shipping
Sources, root Package.swift, project.yml or the checked-in Xcode project.
**NOT_FROZEN / NO_RUNTIME_GO** remains the producer gate.

## Reproduce pure native binding tests

```sh
swift test --package-path Tools/qualification/vibecast-native \
  --scratch-path /private/tmp/djc-vibecast-binding-build --jobs 2
```

The original ten tests cover every captured submit/delete-key/recover-key field, exact
original-byte SHA256 and canonical base64url decoding (no reserialization), decoded duplicate JSON keys, malformed
UTF8/JSON/types/limits, expiry equality, original transaction and context mismatch,
monotone cancellation/rotation/background/pairing/Profile/route ABA, key changes
and expiry during suspension, bounded proof output, no signer call for invalid
input, single-flight submit assertions and recovery of the local gate after errors.

The flat object recognizer accepts only bounded flat string/nonnegative integer
objects required for these test schemas. Foundation handles JSON string decoding;
escaped duplicate names are rejected before dictionary formation. It is NOT a
general JSON parser or independently reviewed production parser. Trusted expected
context is supplied by the harness; these tests do not obtain real HA authority.
Flow invalidation still needs integration into every actual app lifecycle/change
source. The submit orchestrator does not claim a production management-key queue.

## Fresh API generator / native JOSE exchange

Exact API pin `fbe118b3b62b53793ec4d1bbc0aa8adcdff69ba4`, generatorSHA256
`15533bbd9e74c6557508ac11bbda26c4d851c3a62172c0790733b4b0c4891001`.
JOSESwift3.0.0 source `c2664a902e75c0426a1d43132bd4babc6fd173d3` is an isolated
local test dependency, never added to the app. All199 original Git blobs were
rechecked. API's own loader validates the complete isolated jose6.2.12 package.
No custom OAEP/AES primitives, negotiation or fallback.

Build an isolated Swift executable from Binding.swift, DestinationJOSE.swift and
InteropMain.swift with that local JOSESwift package; the executed package/build
inputs remain at /private/tmp/djc-vibecast-native-20261018/interop.
Then invoke the bounded exchange:

```sh
node Tools/qualification/vibecast-native/run_interop.mjs \
  /private/tmp/djc-vibecast-interop-build/debug/Interop \
  /Users/pcvantol/Documents/GitHub/djconnect-api/qualification/rendezvous/generate_destination_vector.mjs \
  /private/tmp/djc-scanner-profile03-interop/node/package \
  /private/tmp/djc-vibecast-native-20261018/interop-result.json
```

The Swift process creates a fresh in-memory software RSA key and publishes only
its public JWK/thumbprint. API generator encrypts reserved example-domain bytes
to it. Swift decrypts using its original in-memory key. For the other direction,
Node creates a fresh pair with a nonextractable private CryptoKey; Swift receives
only its public JWK. No private DER/key JSON files or private-key transfer.
33 checks pass: exact bytes/header, RFC7638, randomness, mutations of all five
segments both ways, wrong recipients, valid crypto with hostile headers, all eight
plaintext context mismatches, expiry and compact serialization aliases.

This is real Mac software interop against the new producer, not a Chromium/WebKit
crossrun or supported signed-iOS result. Expected plaintext is a trusted synthetic
test oracle, not an HA route/ownership validator. The producer's original service
challenges, full verifier/storage/action composition and joint freeze remain open.

## Actual iOS host

HostedQualification.swift and the same BindingTests.swift can be added to a
**temporary** iOS bundle.unit-test target hosted by the ordinary dev.djconnect.ios
app. Add JOSESwift only to that temporary test target. Source must be a clean
manifest-selected snapshot so recovery duplicates never enter a build. Keep
normal product dependencies, identity, signing, entitlements and pairing intact.
The executed isolated XcodeGen spec/build logs stay under
/private/tmp/djc-vibecast-native-20261018; see the dated qualification receipt.

The ordinary hosted test exercises software RSA/JWE inside the actual app process.
A separate `DJC_CAPTURE_BOUND_ACTIONS=1` opt-in enables at most one bounded attempt
using the already-existing development App Attest handle in the protected app
container. It generates **no new App Attest keys/attestations**, does not contact
API/HA or change existing capture state. It signs three fresh, locally generated
action-shaped synthetic clientData inputs (submit/delete-key/recover-key).
These are explicitly NOT API-issued challenges or live enrolled authorizations.
A complete-file-protected marker prevents automatic retry after uncertain failure.
Inputs/proofs stay in DJConnect/BoundActionQualification20261018, outside logs,
ordinary state, analytics and repository. Do not attach raw proofs/handles.
Independent signature/environment/counter checks and API's composed verifier
remain necessary; never relabel SDK output as server acceptance.

Build/signature checks are not execution. A locked iPhone must be unlocked by its
owner. After any actual diagnostic run, restore/read back the ordinary app and
confirm no qualification bundle is embedded. No TestFlight/App Store/publication,
service configuration, Developer account changes or contractfreeze follows.
