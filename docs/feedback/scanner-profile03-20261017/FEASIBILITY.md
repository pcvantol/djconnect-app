# Apple review of API0.3.0 — actual isolated JOSE experiment

Same `DJC-APPLE-VIBECAST-OWNER-SCANNER-V1-20261016`, existing sole Apple writer.
Input API94 **e6f7efd90f92cf64eed4f5d471e36123b1b21514**, KEY_STATE/WIRE_PROFILE
and schemas/cases at that pin; Core candidate6e560061 for current paired route.
This is the targeted consumer feasibility response, not implementation of the
unfrozen scanner, contractfreeze or source/distribution approval.

The human additionally confirmed **“Ja dat accepteer ik”**, quoting the exact
copied-active-QR/genuine-other-paired-scanner risk question, then instructed
“Ga verder”. This literal acceptance is registered at
[API94/6229963840](https://github.com/pcvantol/djconnect-api/pull/94#issuecomment-6229963840).
The earlier limited product disposition stands; no repeated owner question.

## Measured interoperability, with strict evidence limits

An isolated Mac SwiftPM executable uses unmodified JOSESwift3.0.0 from
`c2664a902e75c0426a1d43132bd4babc6fd173d3`. All199 archive files were independently
checked against their exact Git blob hashes, zero mismatches. No dependency was
added to DJConnect's Package.swift, lockfile, Xcode project or app targets.

Node/Chromium use jose6.2.12's npm artifact, checked against registry SHA512
integrity. Registry gitHead is absent; the package version/SRI is proven, not
reproducible equivalence to investigation source505a55b8. Native Apple Security
and the libraries manage OAEP/GCM/key conversion; no custom crypto primitives.

Results:

- **19 checks PASS**: exact synthetic plaintext in both Mac JOSESwift→Node jose
  and reverse directions; expected protected headers, five compact segments,
 12-byte IV/16-byte tag; tampered encrypted key/IV/ciphertext/tag/protected header,
 extra/truncated serialization and wrong private key rejected on both sides.
- **5 actual Chromium checks PASS**, Chromium155.0.8059.85 in a separate headless
  session: nonextractable browser private key, Mac JOSESwift→browser jose,
  browser tag rejection, browser jose→Mac JOSESwift, native ciphertext rejection.
  Browser used a per-run WebCrypto2048-bit RSA key with exponent65537/SHA256;
  its private key never left the browser. A separate native test recipient key
  exercised the reverse direction. Loopback was a local test harness only.
- **89 producer schema cases + exact clientData byte example PASS**, using the
  exact producer validator and isolated jsonschema4.25.1. Expected schema/case
  SHA256 both match the producer handoff. This does not validate raw JSON
  duplicate handling, signatures or native flow binding.
- **3 policy-boundary characterizations**: generic JOSESwift successfully
  decrypts valid crypto with different typ, wrong kid or an extra header field.
  This is not an alleged library vulnerability: the future application adapter
  must enforce the closed profile before accepting/using it. Generic library
  decryption alone must never produce scanner success.

The CLI is Mac software, not the physical iOS app. Chromium is real browser
software, not WebKit or a TV. No App Attest key/attestation/assertion was created;
no API rendezvous/DO, HA route or native camera/owner-context flow was exercised.
No actual100-day/monthly lifecycle, real Apple server throttling or production
reliability result is inferred. All keys/payloads were synthetic; temporary
private DER files were deleted in finally blocks. No real user/HA data entered
the harness. A first Chromium harness attempt saw the DOM id `result` through
window.result and failed before interpreting crypto results; the variable was
renamed window.interopResult and the corrected run passed. No failed run is hidden.

## Finite day27/day30 lifecycle feasibility

**API-expressible candidate; production operational GO remains OPEN.** The SDK
provides generation, attestation and assertions. It does not schedule day27 work
or guarantee Apple service availability/quotas. Apple generally recommends key
attestation once per user/device, and discourages unnecessary generation.
A one-session sandbox experiment cannot establish monthly production cadence.

Concrete native requirements for this proposed policy:

1. Treat day27 as eligibility at the next relevant foreground/explicit VibeCast
   action, not a guaranteed background timer. Offline/suspended apps cannot
   promise rollover before day30. The old key can serve only inside its actual
   server expiry; at equality it is unavailable, never locally extended.
2. Keep at most one active key plus one persisted pending replacement in the
   intended normal rollover state. Persist key handle, environment, enrollment
   operation and bounded recovery status install-locally, separate from HA
   pairing. Do not create a key on every QR, retry, launch or failed request.
3. On Apple serverUnavailable, retry the **same key and clientDataHash**, with
   bounded backoff, not a replacement key. If the original API challenge expires
   while Apple is unavailable, stop that enrollment attempt; the profile needs
   explicit safe recovery rather than assuming re-attestation of an already
   attested key or silently signing a new nonce with old attestation bytes.
4. Cache a successful attestation's exact pending registration request privately
   only as required for its bounded retry. A lost API registration response
   retries the same enrollment operation; it must not automatically generate a
   new key. After its receipt/challenge expires, unknown-server-key recovery
   needs a defined fail-closed state and bounded explicit attempt. A generic
   invalid_sender_proof must not itself trigger an unbounded replacement loop.
5. Serialize assertions per key across scan/delete flows. Preserve exact saved
   action-specific clientData bytes and compare every field with local flow,
   key, challenge, original transaction/generation/browser key/envelope digest
   and expiry before hashing. Never reserialize or blindly sign server bytes.
   A cancelled/changed pairing/Profile/route flow cannot regain authority.
6. Preserve Apple's per-user/device guidance when mapping local user boundaries.
   A backend Profile is not automatically equivalent to an Apple user account;
   define the local boundary rather than sending Profile IDs to central state.
7. Server revoke and local handle retirement do not prove deletion of hardware
   keys: the public SDK has no corresponding key-delete/enumeration API.
   Say server-state revoked/purged and local handle forgotten, not physical
   Secure Enclave erasure. Monthly production key-count/fraud-metric effects
   still need actual qualification; no fraud-metric call is made here.
8. Finite state and tombstone duration are honestly declared. A returned private
   authorization can still commit for up to5s under the proposed protocol.
   Native cancel/delete UI cannot promise immediate distributed recall. Do not
   change this into an instantaneous-revocation claim in translation/recovery.

Required lifecycle vectors remain: enrollment response loss before/after server
commit, Apple unavailable through challenge expiry, old key expired while new
key is pending, max counter and counter reorder, action-separated delete,
reinstall/restore, Profile/route ABA during each await and bounded recovery.
Controlled clocks can test client policy but are not production cadence proof.

## Actual signing policy and the precise native-capture gate

Existing signed40208 iOS product and its embedded provision both explicitly bind
`ZEML4LPXH4.dev.djconnect.ios`, Team/prefixZEML4LPXH4, get-task-allow true.
Provision expires2027-09-23; no App Attest entitlement in either. This is actual
public signing-field readback, not a production policy or live support result.

**Absence of that entitlement alone is not a development blocker.** Apple's
current preparation guidance says development uses sandbox by default, with keys
separate from production; the production entitlement opts development builds into
production. No speculative portal/capability/profile change is requested here.
Never infer App Attest environment from the unrelated APNs entitlement.

There is no existing actual development-domain App Attest fixture to supply.
The present app has no SDK capture code. The exact next native evidence step is
an admitted, isolated physical iPhone/iPad diagnostic capture under this existing
signed app identity and verified development environment, not implementation of
API draft endpoints: runtime isSupported, fresh server nonce hash, generate/attest,
actual AAGUID/environment and challenge validation, then assertion/counter/error
vectors with a qualified verifier. It must preserve ordinary pairing/preferences
and avoid production enrollment. Verify actual artifact identity/environment at
capture, and retain only explicitly synthetic non-production public evidence;
key IDs/receipts/proofs are linkable security data, not routine log material.
An arbitrary XCTest-runner/other-bundle attestation is not this app-policy proof.

This review makes no new signing/account/entitlement/device-install change and
creates no hardware App Attest keys. Existing signing evidence is sufficient to
avoid inventing a generic certificate problem, but not to claim that the native
capture or verifier is already qualified. Monthly cadence, physical iOS and
WebKit/native interop, full verifier/CBOR/chain/workerd and DO crash/cleanup remain
separate qualification exits. No runtime/freeze/production GO is given here.

## Evidence and official sources

Machine-readable results and signing readback are adjacent to this file.
`local-harness-manifest.json` records local preserved harness sources/logs in
build/recovery/scanner-profile03-20261017. Temporary source/package downloads and
isolated schema environment remain under /private/tmp/djc-scanner-profile03-*.

- [Apple preparation and sandbox defaults](https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service)
- [Apple key lifecycle](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [Same-key/hash retry on serverUnavailable](https://developer.apple.com/documentation/devicecheck/dcappattestservice/attestkey(_:clientdatahash:completionhandler:))
- [Official server validation](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)
- Installed Xcode iPhoneOS SDK DeviceCheck/DCAppAttestService.h checked directly.
- [Exact JOSESwift source](https://github.com/airsidemobile/JOSESwift/tree/c2664a902e75c0426a1d43132bd4babc6fd173d3)
