# Apple follow-up: API 0.3.0 draft, signing, extensions and receipts

Assignment: DJC-APPLE-VIBECAST-OWNER-SCANNER-V1-20261016. Same sole writer,
`codex/apple-dj-presence-v1`, pickup source b5e8f8f03d62de19555cee27e3a42d1be542eb62.
User explicitly requested this bounded review/experiment, no second writer and no
scanner runtime. API handoff6230002470 and audit6230000412 read fresh; API94 head
**48a025d6b6343dd3220aa06d9f7a63c4f76a37bd**, OPEN, **NOT_FROZEN / NO_RUNTIME_GO**.
The copied-active-QR limitation was already accepted and is not reopened.
Earlier e6f7efd feasibility remains historical evidence, not the current API pin.

## Actual identity and evidence boundary

Fresh public signing/provision readback of the existing signed local iOS product:
4.0.0, build40210, bundle `dev.djconnect.ios`, App ID
`ZEML4LPXH4.dev.djconnect.ios`, prefix/team `ZEML4LPXH4`, get-task-allow true,
minimum OS26.0, SDK iPhoneOS27.1. Provision expiry2027-09-23. Both signed and
profile App Attest environment entitlements are absent. See signing-current.json.
This is a signed development artifact, not installed-build, TestFlight, App Store,
production admission or real App Attest proof. No signing/account policy changed.

There is **no demonstrated signing/entitlement failure**. Apple's preparation
page says development defaults to sandbox; absence of the entitlement is not by
itself a blocker. TestFlight/App Store/Enterprise distribution uses production.
Do not infer App Attest environment from APNs or get-task-allow. The environment
of an actual key must be checked using its verified attestation, which is absent.

No real app-bound attestation/assertion fixture is available. The existing app
has no capture path, and this exact API handoff explicitly forbids generating
keys, collecting receipts or changing signing/account policy. Therefore no such
capture was performed; do not manufacture an entitlement blocker. A future
separately admitted capture needs this actual app identity, runtime isSupported,
a controlled development challenge and qualified verifier. An XCTest runner or
other bundle's proof does not establish this app's identity. Production enrollment
and receipt-metric calls are not authorized by this review.

## OS and app-extension applicability

| Surface | Current evidence / disposition |
| --- | --- |
| Native iPhone/iPad app | DeviceCheck API available from iOS14; Physical iPhone27.0.1 returned isSupported=true in the isolated XCTest runner; this is device capability, not DJConnect app enrollment. Selected v1 remains iPhone-oriented; API availability alone does not admit another device. |
| Mac, Catalyst, iOS-on-Mac | Current isSupported documentation and installed SDK header say false on Mac, including Catalyst/iOS-on-Mac. The newer server guide also describes macOS signing-ID and ACL validation; this documentation-scope difference does not justify claiming Mac support. No borrowed phone assertions. |
| Widgets/Activity and ordinary app extensions | Not admitted. The SDK says most extensions cannot generate keys, even when isSupported is true; do not give them scanner enrollment or share a private key handle as a workaround. |
| Watch | SDK/API describes watchOS9 availability and a WatchKit-extension exception. Not qualified/admitted for this scanner policy; a Watch proof must not masquerade as the iPhone app identity. |

The read-only physical iPhone support query passed on iOS27.0.1, under runner
`dev.djconnect.ios.physicalprobe.xctrunner`; see device-support.json and the retained
DeviceSupportProbe.swift. It did not call generateKey, attestKey or generateAssertion.
DJConnect was reactivated afterward. There is no app-bound crypto or Watch support
measurement. No product app target/dependency was added.

## Authenticator/certificate extensions: concrete verifier gates

Apple's current server guide calls for attestation fields
`apple_validation_category_01` (UInt32) and `apple_bundle_version_01` (String),
and refers to assertion fields as `validationCategory` and `bundleVersion`.
The published example is an illustration, not our real fixture. Do not normalize
names, decode hexadecimal samples as decimal prose, accept ED tails by ignoring
them or silently permit absent fields across all OS versions.

A future verifier must strictly parse signed authData including flags, lengths,
CBOR map types/duplicates/trailing data, and enforce an explicit measured
OS/distribution/version policy. Development category3, TestFlight2, App Store4
and Enterprise/ad-hoc5 are documented categories; the current artifact's category
is **expected from distribution, not measured in authData**. Bundle version must
be compared to a server-controlled allowlist/minimum after actual fixture binding;
a client-supplied version cannot authorize itself. Exact field presence/names and
version semantics across supported OS releases remain a real-fixture gate.

The current docs also differ on development AAGUID spelling: preparation names
`appattestsandbox`; server validation/its guide names `appattestdevelop`.
Do not quietly accept both or claim an observed environment. Resolve using
controlled genuine fixtures and an explicit versioned producer policy before
freeze. Production's documented fixed AAGUID does not repair this sandbox gap.

Nonce certificate OID1.2.840.113635.100.8.2 and complete root/path/time/constraints
validation still apply. The additional OID1.2.840.113635.100.8.6 ACL restriction
is explicitly macOS-scoped in Apple's guide, not an invented iPhone requirement.
The API's unmodified node-app-attest reference remains REJECTED_FOR_RUNTIME;
its synthetic parser/counter findings are not genuine Apple certificate tests.

## Fraud receipts: separate producer policy required

The accepted copied-QR product limitation does not waive app authenticity.
For this limited-A design, following Apple's documented attestation procedure
requires independently verifying and storing the accompanying Apple receipt at
successful enrollment. The draft's short operation receipts cannot satisfy that.
Calling Apple's fraud-metric refresh endpoint is a separate optional assessment;
it is not performed or implicitly authorized here.

The API producer must explicitly specify receipt verification and bounded private
storage before runtime admission: signature and Apple receipt trust chain (Apple
Root CA-G3, distinct from assuming the attestation root), strict ASN.1, App ID,
attested public-key binding and creation freshness (documented five-minute check).
Keep sandbox/production separated. Distinguish initial ATTEST receipts from
refreshed RECEIPT metrics; metric refresh has not-before/expiry and separate
server credentials. No client receipt persistence, ordinary analytics/logging,
HA/Profile identifiers or new cross-device index is justified by this review.

KEY-STATE currently does not define a fraud-receipt record. Add its ownership,
minimal data, access controls, retention and revoke/expiry/cleanup behavior to the
existing finite key policy; do not silently introduce indefinite retention or
change operation-receipt semantics. Receipt verification must occur while fresh,
not be postponed to a later monthly rollover. No receipt was collected or stored.
These are concrete producer contract gates, not a new request to the human to
re-accept the copied-QR limitation.

## Key rotation and recovery

Day27 rollover is eligibility on a relevant foreground action, not guaranteed
background work; day30 hard expiry cannot be extended locally. Retain one active
and one pending replacement in the normal state. Persist the exact enrollment
operation privately; Apple serverUnavailable retries the same key/hash, never a
key-generation loop. Challenge expiry after attestation or lost registration
needs bounded explicit unknown-key recovery, not blind re-attestation/replay.
Serialize assertions per key across submit/delete; preserve saved exact clientData
and generation/route/Profile fences after every await. Missing counter state is
an error, not zero/NaN; uint32 exhaustion/reordering cannot wrap/reset counters.
No public SDK deletion API proves Secure Enclave erasure; server purge and local
handle retirement remain accurately distinct. The draft's at-most5s returned
cross-DO authorization window remains visible, not instantaneous cancellation.
The existing e6f7efd lifecycle review remains applicable; no operational monthly
cadence, DO-crash or real Apple throttling PASS is inferred.

## Executed isolated experiment and acceptance

15 additional Mac JOSESwift3.0.0/Node jose6.2.12 checks PASS: exact Unicode/NUL,
8192/16384-byte crypto roundtrips,12 distinct native JWE/IV observations and
malformed IV/tag/encrypted-key/ciphertext rejection. Sizes test byte fidelity,
not wire-size admission; finite uniqueness is not an RNG certification. A changed
header test proves authenticated-byte integrity, not duplicate-key parser safety.
A valid extra protected field still decrypts in generic JOSESwift: strict closed
profile admission remains unimplemented. No custom OAEP/GCM/ASN.1 crypto adapter.

Original19 Mac/Node cases and5 actual Chromium cases rerun PASS. Exact current
schema/corpus hashes match the earlier pin; freshly fetched current validator
passes89 cases plus exact clientData example. The first validator invocation used
an incorrect staging location and failed to find its files; corrected exact
scripts/docs layout passed. No failure was reclassified as security proof.

No App Attest key/receipt/attestation capture, iOS/WebKit/TV crypto, scanner UI/runtime,
DO service, dependency/lockfile/app source/signing change, install, push, merge,
contractfreeze or production GO. This review closes the requested Apple assessment
and adds measured experiment evidence; real fixtures and verifier/producer policy
remain explicit blockers for later implementation.

## Sources and reproduction

Official pages retrieved2026-10-17; URLs/hashes and exact API file hashes in
readback-manifest.json. Prior harness/library pins are unchanged. Run the retained
jose-followup.mjs with Node and the staged JOSESwift CLI/jose artifact from the earlier
local-harness-manifest. DJC_SCANNER_JOSE_ROOT and DJC_SCANNER_RESULT_PATH override
the isolated staging/output paths. Results contain no keys, ciphertext or real routes.
Physical support evidence: /private/tmp/djc-scanner-profile03-support.xcresult and
/private/tmp/djc-scanner-profile03-support.log; this is a device query, not enrollment.

- https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service
- https://developer.apple.com/documentation/devicecheck/dcappattestservice/issupported
- https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
- https://developer.apple.com/documentation/devicecheck/attestation-object-validation-guide
- https://developer.apple.com/documentation/devicecheck/assessing-fraud-risk
- https://github.com/pcvantol/djconnect-api/blob/48a025d6b6343dd3220aa06d9f7a63c4f76a37bd/docs/rendezvous/VERIFIER_REFERENCE_AUDIT_V1.md
