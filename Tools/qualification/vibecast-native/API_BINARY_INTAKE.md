# API-issued binary SDK intake — build40380 proposal

This is the separate path requested in API90 comment6277830018. It is not the
historical AppAttestQualification UTF8 synthetic-input diagnostic, the synthetic
HostedQualification action generator, a shipping scanner or API profile approval.
The released source permission remains djc-rendezvous/1-implementation.1; no
producer contract or public service is changed.

## Actual byte/SDK path

BinarySDKInput.registration parses the closed API challenge response, validates
canonical base64url32-byte nonce/challenge ID and hashes the **decoded32 bytes**.
It never hashes the43-byte base64 string/ASCII text. BinarySDKInput.action parses
the closed action response, matches challenge ID/nonce/deadline to independently
captured request context, decodes client_data and validates its complete closed
submit/delete-key/recover-key fields. Hashing uses those **original server bytes**,
including their whitespace/order/escapes. No clientData reserialization, historical
proof, synthetic nonce substitution or registration/action proof reuse.

The decoded clientData bound remains2KiB. The complete challenge-response bound
is4KiB, allowing the base64url wrapper without incorrectly treating the API's1KiB
challenge-request limit as a response limit. All JSON is flat, bounded UTF8 with
duplicate decoded-key rejection and fixed typed error redaction. Integer syntax
remains the conservative nonnegative digit-only qualification parser policy.

BinarySDKIntake requires durable persistence before dispatch, rechecks original
absolute deadline/key/current context immediately before and after SDK await,
bounds attestation/assertion outputs to32KiB/4KiB and serializes the complete
qualification call. Cancellation cannot release its slot until the provided SDK
callback returns. All thrown file/parser/SDK errors are replaced by a fixed error.

APIBinaryHostedQualification connects this path **directly** to DeviceCheck's
attestKey or generateAssertion callback API in the actual app-hosted test target.
It uses a continuation that deliberately awaits the real callback despite task
cancellation. It has no HTTP client, key generation or retry loop. It consumes an
already-admitted exact key handle from independent request context. Registration
must never re-attest an old diagnostic/uncertain key with a new nonce; key setup
is a separate jointly admitted step. An occupied marker means stop for explicit
reconciliation, never delete the marker and try another key.

## Concrete proposed signed profile

[PROFILE_PROPOSAL_40380.json](PROFILE_PROPOSAL_40380.json) records actual readback
and source hashes, not an approval. App host is dev.djconnect.ios, TeamZEML4LPXH4,
App ID ZEML4LPXH4.dev.djconnect.ios, CFBundleVersion40380. The existing development
profile UUID17969a71-9eec-40dc-a06f-e1bece5d4062 has SHA256
9243e1b2b3c829a86073ecf61f50e13cb7f0c9ab0630c9597ca3e9fa286629dd;
actual signing certificate SHA1 is9ae3c26d564cdc66671f3aeb5e9e9c7f2d0080aa.
get-task-allow is true. The explicit App Attest environment entitlement is absent.
Development is the **proposed** verifier environment; an entitlement omission or
our metadata does not establish the actual Apple AAGUID/environment. API owns
exact profile policy review and genuine-proof validation before acceptance.
Build40380 is not silently added to the existing40227/40228/40230 allowlist.

The private signed scratch host includes the qualification xctest bundle, is not
an ordinary install/release and must not be distributed as one. Its89-file bundle
manifest digest is c60944174aaafb42cd254828617ec7d8d2018669b8319cb784fd8b86f4d42521
(SHA256 of sorted compact JSON file/symlink manifest, without final newline).
Raw app/profile archives are not published: profiles can contain device details.
Local stage, executable/profile/manifest readbacks and source hashes remain under
build/qualification/vibecast-binary-sdk-intake and /tmp/djc-api-binary-40380-*.
Signed-source hashes must match this proposal; a changed artifact is not covered
by an old receipt merely because its displayed build number is40380.

## Joint-run gate and private transfer

1. API first reviews/accepts the exact proposed profile/artifact/source and names
   the qualified original120s experiment. Existing dependency comments, including
  6277830018, are **not acceptance receipts**. No fresh nonce/key/assertion before
   both owners are ready. Do not change Developer accounts/profiles/entitlements
   or API verifier policy to make a failed proof pass.
2. Before requesting a fresh challenge, prepare/unlock the actual iPhone,
   independently read back its installed hosted build/signing identity and agree
   the private host-to-device-to-API transfer. Build/signing here is not physical
   install/launch or transfer acceptance. The existing signed app target and
   existing profile are used; no standalone runner identity is substituted.
3. Only after admission, the controller copies the actual API response plus
   independently captured request context into the app's private container:
   Library/Application Support/DJConnect/APIBinaryQualification40380/register
   for registration, or the single `action` directory for the one selected action.
   Do not generate clientData on Apple. Prepare files with complete file
   protection in the private app container; export only this diagnostic subtree
   to a mode0700 host directory. Never copy preferences, pairing tokens or the
   whole app container. No shared/public uploads, XCTest attachments or raw logs.
4. Each stage contains admission.json, request-context.json and
   challenge-response.json. Admission is exactly
   `{v:"djc-api-binary-qualification/1",team_id:"ZEML4LPXH4",bundle_id:"dev.djconnect.ios",build:"40380",environment:"development",api_review_receipt:"<EXACT-ACCEPTED-API90-RECEIPT>"}`.
   This local receipt field is operator bookkeeping, **not machine proof of human
   review/authority**. The operator must independently verify the actual receipt
   and exact artifact before arming; a matching string/URL cannot authorize SDK
   work. The placeholder deliberately fails validation.
5. Request context is the captured action, key_id, challenge_id, challenge,
   expires_at and requested_at (safe-integer UTCms at the original request).
   Submit additionally requires transaction_id, generation,
   browser_key_thumbprint, envelope_digest and **transaction_expires_at** from
   the original transaction. It is not derived by parsing the signed clientData.
   The response file is the unchanged API response body. Original challenge
   deadlines stay fixed; the transfer/test launch consumes that same window.
6. The temporary test-only scheme compiles Binding.swift, BinarySDKIntake.swift,
   APIBinaryHostedQualification.swift and the two pure test files, hosted by
   DJConnectIOS with DeviceCheck.framework. It is not added to project.yml or
   the checked-in ordinary project. Default execution skips capture. Only the
   explicitly admitted operator may set DJC_API_BINARY_CAPTURE=1 and choose
   DJC_API_BINARY_STAGE=register or action, then test-without-building the exact
   agreed diagnostic artifact. Do not run the historical key-generation test.
7. The foreground-only test checks bundle/build, SDK support, closed profile and
   context before dispatch. Any foreground loss permanently invalidates that
   call even if the app becomes active again; changed packet bytes also reject
   late results. It writes sdk-input.bin/hash and a no-overwrite attempted marker
   under complete file protection before the SDK call. It then saves proof.cbor
   only for an admitted, still-current, unexpired result. It prints no proof,
   handle/hash or SDK userInfo. A marker blocks repeat invocation for that stage.
8. API consumes only the fresh private proof and its exact input/context in its
   bounded verifier/registration/action tool, validating actual environment,
   app/key/nonce, counters, original deadlines and receipts. No client-side
   success substitutes for server acceptance. One joint experiment is not TV,
   HA ownership, production activation or full-chain qualification. Timer stays
   off; server public root/module and Core screen admission remain owner-held.

## Executed qualification

Twenty-six isolated Swift tests pass (the prior10 binding cases plus16 binary
intake/dispatch cases). They prove decoded nonce vs base64-text hash, all three
exact action-byte paths, response-vs-clientData size bounds, canonical encodings,
duplicate/foreign/malformed JSON, original deadlines, persistence before a fake
SDK sink, failed save/context/key/expiry refusal, late results/error redaction,
proof bounds, nested serialization and cancellation retaining the slot until
callback. Four regression tests first reproduced wall-clock rollback and a frozen
wall clock both before dispatch and during the SDK call. They now reject:
input construction preserves its wall-time observation and starts the original
remaining lifetime against ContinuousClock. Dispatch/release cannot lower that
wall baseline or renew the monotonic lifetime after input construction,
persistence or an SDK await. These are injected closure tests, **not Apple SDK execution**.

A clean tracked-source snapshot plus the explicit new qualification files built
for generic iPhone/iOS including the real DeviceCheck callback paths and both
test classes. Unsigned and subsequently development-signed build-for-testing40380
both passed. After the clock correction the development-signed hosted build
was rebuilt successfully against all five corrected source/test inputs. codesign --verify --deep --strict passed on the resulting scratch
app. Actual profile, entitlements, certificate, bundle manifest and all five
compiled-source hashes were read back. No physical tests, fresh nonce/key,
SDK call, API request, installation or ordinary app replacement occurred.
The initial standalone compiler probe lacked XCTest's Swift overlay flags; the
full native hosted build, not that failed probe, is the compilation evidence.
An initial signing invocation lacked the existing Team/automatic identity flags;
the final build used the existing Team and Apple Development identity without
provisioning updates or account/profile creation.

CI now runs the pure isolated package with no credentials/hardware opt-in, in
addition to ordinary Swift/native build checks. That does not arm hosted capture.
The shipping scanner, genuine SDK/API joint proof, agreed profile and physical
private-transfer readiness remain explicit separate gates.


## Corrected build40381 candidate — 20 October 2026

[PROFILE_PROPOSAL_40381.json](PROFILE_PROPOSAL_40381.json) is a new, separate
proposal containing the protected PR160 expiry correction. Both the test host
bundle guard and explicit private admission descriptor require40381. The durable
attempt directory deliberately remains `DJConnect/APIBinaryQualification40380`:
a new build must not bypass an occupied registration/action marker. Historical
attempt state, old40380 proposal/artifact and independent admission gates remain
unchanged. No migration, deletion, new key, capture or SDK execution occurred.

The actual generic-iPhone build-for-testing succeeded using the existing Team,
Apple Development identity and existing exact profile without provisioning
updates. Both produced and preserved bundles pass strict nested signature
verification. All89regular bundle files and five compiled qualification inputs
are SHA256-bound; the copied artifact root is private. Source-base5173de1 and
separate test-target overlay are recorded; only the two build guards changed.
The earlier private prototype with a new state-directory name was superseded
before external proposal and retained separately as non-admitted evidence.

This is compiled/signed diagnostic evidence, not a protected delivery receipt,
API policy acceptance, actual DeviceCheck request, install or physical test.
After exact source review/delivery, API separately reviews this exact candidate
profile/artifact and both owners arrange private-transfer/device readiness before
one bounded original120s registration and selected action. Never reuse old
40380/40227/40228/40230 approval or reset a consumed/uncertain marker.
