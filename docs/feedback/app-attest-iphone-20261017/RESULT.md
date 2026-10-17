# Genuine app-bound iPhone App Attest evidence

Same Apple writer, branch codex/apple-dj-presence-v1, base4fa9115; existing WIP
preserved. Direct owner instruction now authorizes actual app-bound diagnostic
capture; the older review-only prohibition does not block this new bounded work.
Current API94 is60c291a3bb21b493eaabed116483e3876be711b1,0.4.0-draft,
NOT_FROZEN / NO_RUNTIME_GO. No scanner runtime or unfrozen endpoint implemented.

## Measured on the real iPhone

Hosted XCTest uses actual main bundle dev.djconnect.ios. Signed application ID
ZEML4LPXH4.dev.djconnect.ios, TeamZEML4LPXH4, existing development profile; no
account, entitlement or signing-policy change. App Attest entitlement absent;
absence was not an execution blocker. iOS27.0.1, isSupported=true in the actual
DJConnect app process, not the previous UI-test runner.

Build40227: exactly two keys (active diagnostic and distinct replacement), two
actual attestations and two assertions per key. Unknown-key SDK call rejected:
com.apple.devicecheck.error/code3. Hosted test PASS,2.670s.
Build40228: update/process restart reuses both exact key handles, attestations
byte-identical, two further assertions per key, no new key generation. Test PASS.
Observed counter sequence0(attestation),1,2,3,4 for each distinct key. Protected
normal app data survived the app update. This is not reinstall/restore proof.

Fixture self-consistency checks using cbor2==5.6.5/cryptography: exact App-ID RP hash,
leaf-public-key credential/handle match, actual assertion signatures and changed
clientData rejection. The first inspection used the wrong assertion verification
input and failed; corrected to Apple's nonce procedure, then all8 signatures
passed. An initial JSON diagnostic also failed on byte-valued extensions; fixed
by reporting only explicitly known public fields. Failed attempts are not PASS.

Actual marker: appattestdevelop. Actual signed authData extension fields in BOTH
attestations and ALL assertions: apple_bundle_version_01 (40227/40228 respectively)
and apple_validation_category_01 as bytes03000000. Do not substitute documented
camelCase assertion names without an explicit measured/versioned policy. Two
certificates and an initial Apple receipt are present per attestation. This is a
captured environment marker and leaf-signature consistency, not qualification of
Apple chain/nonce-certificate/fraud-receipt trust or distribution admission.

## Policy acknowledgement and remaining API gates

Apple accepts0.4's action-separated exact-byte recovery, original120s deadlines,
challenge coalescing, bounded same-key retry, persisted paused repair/max2 explicit
attempts at least60s apart,24h replacement bound, day27 eligibility/day30 hard
expiry, one active/one replacement, serialized assertions and unsigned32-bit
counter semantics. Diagnostic key handles do not grant enrollment or HA authority.
No Secure Enclave erasure claim; no default-zero missing server counter.

API must independently qualify real chain/path/time/nonce/receipt validation,
strict CBOR/ASN.1/extensions policy, wrong App-ID/environment/key/signature,
replayed/reordered/max/missing counters, unknown enrollment/recovery/revoke,
crash ordering and workerd integration. No API runtime endpoint currently exists;
those cases cannot honestly be labeled executed by Apple. No production enrollment,
receipt-metric refresh call, fraud credentials, server counter update, monthly
rotation, HA pairing mutation or scanner/TV acceptance performed.

## Private fixture handling and ordinary app restoration

Raw CBOR/input/key-handle/receipt files are private only:
/private/tmp/djc-appattest40227-private/{device-evidence,reuse-evidence}.
Only sanitized reports/source are in this repository. No proofs/handles/receipts
in standard app logs or test attachments; no raw fixture GitHub upload. Limit this
local diagnostic evidence to qualification needs; review/delete by2026-11-16,
not an indefinite registry. This is a retention instruction, not an automated
cleanup claim. A private handoff can let the existing API writer independently
consume these exact files; public comments contain only sanitized observations.

Restore the canonical project (without test overlay) and ordinary build40229,
verify no AppAttestQualification.xctest/dSYM remains, strict signature, install
and read back iPhone version. Existing app key handles are retained privately
for subsequent approved same-key verification; no forced server enrollment.

Official procedure: https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
Development default: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.devicecheck.appattest-environment

Final restoration executed: ordinary iPhone40229 build PASS, strict signature PASS,
no diagnostic test bundle/dSYM inside app, installation and fresh CoreDevice
version readback PASS. iPad not used for key capture; its prior40226 remains.
Sanitized lane report posted and exact-body read back:
https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6231637013
Raw proofs/handles/receipts remain private. No protected source delivery claimed.

## Continued qualification — SDK hash-input boundary

The existing API task "Implementeer VibeCast-rendezvous" explicitly acknowledged
and picked up the private genuine captures for server qualification. Same writer;
no second API or Apple writer. Contract remains exact0.4/60c291a3, unfrozen.

Additional hosted native test40230 used the existing active handle, no new key or
attestation. Empty clientDataHash was rejected with DeviceCheck/code2;31 zero bytes
were accepted. The test FAILED its explicit assumption that both were rejected.
This result remains a native test failure/finding, not retroactively a green test.
The accepted31-byte input produced genuine counter5 and a locally verified
signature. A valid SHA256 challenge then produced counter6: no reset. Current
active sequence1,2,3,4,5(nonstandard input),6; replacement remains1,2,3,4.

Local signature negatives over the real fixtures reject modified signed counters,
wrong public key and changed clientData. No replay-server acceptance claim. A
future native client must calculate SHA256 internally and must not expose a raw
caller-supplied hash API as protocol validation. API must bind exact saved action/
clientData/challenge itself and not assume SDK hash-length enforcement. Same-key
SDK validation is not server enrollment recovery or a deployed exploit.

Sanitized sdk-input-observations.json and sdk-input-inspection.json retain the
results. Private extra capture input-evidence was offered to the existing API
writer, with exact counter finding. The prior executed source hashes have matching
snapshot files in capture-source; continuation-source-manifest.json names the
expanded diagnostic/inspection source. No production app source or contract
runtime was added. The ordinary app40231 is being restored without the testbundle.

40231 restoration completed: ordinary iPhone app installed and fresh build number
read back. Supplemental lane finding exact-body readback PASS:
https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-6231720002
