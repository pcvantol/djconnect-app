# VibeCast prepared-registration journal

Bounded continuation after PR148: persist a **prepared registration request**
and its original retry budget before releasing bytes to a future transport.
This is not SDK enrollment, response verification, active-key adoption or a
working scanner. The existing released source implementation permission remains
`djc-rendezvous/1-implementation.1`, Finalization main
`661e5770eb5249b1b02bbdc2426ba7e575fc8881` and
[producer receipt](https://github.com/pcvantol/djconnect-api/issues/90#issuecomment-6272409413).

## Verified contract inputs

| Input | SHA256 |
| --- | --- |
| ENROLLMENT_RECOVERY_V1.md | 851d9756352bed3e03e5c60f1d2709596d58c10e24180e97d67d4514531f1832 |
| wire-request-schemas-v1.json | c00d495222a5bc719e5ef22280e4bbacbb7496f03740cb9c6ccf8b464f4d8a0d |
| WIRE_PROFILE_V1.md at released record's source anchor aef408686f485e02b6f5082d69d1fe31bd62f289 | 432374e1f1a4537fddef3cb9248319f3b163993a4d8bd1feae9ea5255a312376 |

The protected source/main and Finalization copy of WIRE_PROFILE has SHA256
`b812ea0dfdaca08e7128b227697a225071b72f28098c556650d76bb24f6029f2`.
Comparison confirmed it only prepends seven implementation-release precedence
lines to the manifest-pinned source. The pinned normative bytes were retrieved
at the record's source anchor rather than silently accepting a mismatched hash.
No producer contract or repository was changed by this consumer work.

## Implemented behavior

RendezvousRegistrationJournal.shared owns a separate fixed device-only Keychain
address using the already qualified data-protection storage backend. It has no
public reset/delete/address override. Paused-repair accounting is not overwritten.
The public API accepts only typed registration fields after the original SDK
attestation is prepared: canonical32-byte base64 key ID, canonical32-byte
base64url challenge ID, original32-byte nonce,1–32768-byte opaque attestation,
admission time and original deadline capped at120s. It creates only the closed
`v/key_id/challenge_id/attestation` registration body, at most64KiB. It does not
accept arbitrary request dictionaries, headers, HA credentials or endpoint URLs.

The body is serialized **once** and stored as its exact bytes, together with
original nonce/hash, request hash, key/challenge binding, local attempt identity
and RendezvousRetryWindow. The whole encoded item is bounded to96KiB. Restore
checks schema, canonical encodings, sizes, hashes, closed field set, exact own
generated-body format and matching registration retry kind. The reconstruction
used for validation is comparison only; returned transport bytes always come
from the original stored Data. This is not canonicalization/reserialization of
server-returned clientData and does not implement recovery/delete/submit actions.
Attestation CBOR/nonce cryptographic validity remains SDK/server-owned.

A submission contains the stored exact body, original key/deadline and matching
attempt/reservation IDs. It escapes the actor only after its consumed retry call
and reservation have been successfully persisted. The original2s/5s delays,
maximum three submissions and absolute Retry-After delays survive restoration.
A restored in-flight call blocks replay. Failed/ambiguous writes return no bytes;
if a write actually committed, the next read sees its consumed in-flight call.
Clock observations, including refused actions, are persisted without renewing
deadlines. Wrong attempt/completion IDs cannot release another operation.

At deadline equality, snapshot/reservation/completion first transitions to
registrationUncertain and removes challenge, nonce, nonce hash, request and
request hash. The original opaque key handle, fixed deadline and consumed budget
remain. A late successful callback cannot revive prepared bytes. Terminal or
exhausted outcomes also purge material conservatively; caller-reported validated
success records completed and purges it. Completed is not active-key authority.
No existing record can be replaced by prepare, including expired/completed ones.

Expiry is logical and enforced on access. If a purge write is unavailable, the
journal throws and exposes no bytes; encrypted old material can remain until a
later successful cleanup. There is no background-expiry task or forensic-erasure
claim. A previously returned body copy cannot be recalled: the future transport
must recheck its attached original deadline/context immediately before sending
and limit its volatile lifetime. Server expiry remains authoritative.

## Qualification

Twelve focused journal tests cover exact closed body and identical retries after
restoration; original2s/5s/Retry-After eligibility; concurrent/in-flight fencing;
expiry equality and late results; proof/nonce removal; failed/uncertain writes;
clock rollback; maximum/invalid inputs; malformed or changed bindings, request
hash, foreign fields and byte format; missing storage and exhausted budgets.

The tracked Tools/qualification/vibecast-registration-journal probe compiled the
actual production sources with Swift6 and ran in a signed scratch Mac app using
the existing identity/profile context. Six separate processes passed prepare,
metadata, restore, expire, verify-purge and exact synthetic cleanup. The maximum
32KiB synthetic attestation and original body survived actual Keychain writes;
body SHA256 matched across processes. Metadata was device-only/non-syncing.
Two unsafe namespace inputs were rejected before accessing Keychain. Only the
synthetic service/account was removed; no real proof, App Attest handle or HA
credential was used. Hashes bind the executed probe and source to the readback.

This combines actual native persistence with a **controlled supplied clock**;
it is not a physical reboot/power-loss, wall-clock soak, locked-device or physical
iOS/Watch test. The synthetic attestation bytes are not an Apple/verifier fixture.
Logs/readbacks are retained under build/qualification/vibecast-prepared-registration.
The unchanged-source full run passed901 Swift Testing tests in10 suites plus47
XCTest cases (948 total). Native macOS and iOS including Watch dependency
unsigned40377 builds passed. Protected exact-head review/CI are separate checks.

## Remaining integration

The shipping scanner does not call this journal. The pre-SDK attestation stage
and its retry window are not yet journaled; this slice starts after preparation.
Fresh management recovery must retain its own exact action/clientData/assertion
and original challenge; no such action is inferred here. The broader lifecycle
still needs authorized replacement/two-handle transitions, active-key expiry and
rollover. There is no generic reset or automatic new enrollment escape hatch.

Registration and paused-repair state occupy separate Keychain items. There is
no cross-item transaction here. The future lifecycle owner must reconcile both,
retain an uncertain registration handle if entering paused repair is interrupted
and never interpret one missing item as permission to create another key.

Future callers must hold the complete shared per-key queue, revalidate trusted
app/environment/origin and current owner/flow after waits, honor the returned
original deadline immediately before transport, resolve uncertain operations and
validate server receipts before adopting an original key expiry. This journal
does not authorize a host, attest an app, select a route, log proofs, synchronize
Profile state or establish cross-process locking/server quotas. Genuine SDK/API/TV
acceptance and activation require the separate qualified producer target.
No ordinary app installation, signing configuration, HA/service change or live
App Attest/network action is performed by this source/qualification slice.
