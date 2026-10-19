# VibeCast exact-byte recovery journal

Bounded continuation after PR151: protected persistence of the **recover-key**
server clientData, one consumed assertion reservation and an exact prepared
recovery request/retry budget. This is source/storage preparation; the shipping
scanner and real SDK/API capture path remain unconnected.

## Authority and inputs

Consume the unchanged source permission `djc-rendezvous/1-implementation.1`,
Finalization main `661e5770eb5249b1b02bbdc2426ba7e575fc8881` and
[producer receipt](https://github.com/pcvantol/djconnect-api/issues/90#issuecomment-6272409413).
Pinned enrollment-recovery SHA256:
`851d9756352bed3e03e5c60f1d2709596d58c10e24180e97d67d4514531f1832`;
request schemas: `c00d495222a5bc719e5ef22280e4bbacbb7496f03740cb9c6ccf8b464f4d8a0d`;
normative WIRE_PROFILE at source anchor aef4086:
`432374e1f1a4537fddef3cb9248319f3b163993a4d8bd1feae9ea5255a312376`.
The preceding prepared-registration report explains the released banner copy.
No producer schema, service, profile, signing account or cross-repo code changed.

## Implemented behavior

RendezvousRecoveryJournal.shared has one new fixed device-only Keychain item,
using the existing qualified storage backend. There is no public delete/reset,
replacement, arbitrary storage address, endpoint URL, action selector or fresh
challenge/key creation. begin refuses every existing record, including paused
and completed ones; lifecycle-controlled subsequent repairs remain separate.

begin accepts the existing canonical32-byte standard-base64 key, canonical
base64url32-byte challenge ID, original32-byte nonce, **original decoded** server
clientData and admission/deadline. The deadline is JS-safe milliseconds with a
maximum120s span. The journal validates all seven clientData fields against the
captured context: protocol, recover-key action, fixed service origin, key,
challenge ID, nonce and deadline. It accepts neither delete/submit action bytes
nor extra Profile/QR/route/user fields. Its bounded flat-object parser rejects
invalid UTF8, duplicate **decoded** keys, trailing data, extra fields, objects,
arrays, booleans, null and invalid/out-of-range numbers. String escapes and
whitespace/order differences remain in the original byte string. The small
recognizer is adapted from the existing qualification parser, not a new general
JSON library. Numeric intake conservatively accepts unsigned integer tokens
only, not exponent/fraction lexical forms; the producer's fixtures emit integers.
Malformed string parsing returns only a fixed typed rejection. A focused
regression first reproduced a Foundation parser error escaping, then passed
after that error was sanitized; input fragments are not included in public errors.

The exact original clientData bytes and SHA256 are saved before reserveAssertion
can return its matching key/hash/deadline/reservation. The consumed reservation
is saved before external-call parameters escape; it blocks a second assertion
after process restoration. There is one assertion per attempt, with no implicit
SDK retry, new nonce or key. A matching callback containing1–4096 opaque bytes
constructs the closed v/key_id/challenge_id/client_data/assertion request once.
The client_data field is base64url of **the original saved bytes**, never of a
reconstructed dictionary. This validates bounds/context, not CBOR/signature or
Apple/server key state. Wrong/duplicate callbacks cannot replace a saved proof.
Failed or empty/oversize assertion pauses and purges material conservatively.

Transport reservations persist before original stored body bytes can be returned.
The existing recovery-kind retry window permits at most initial+2 byte-identical
submissions after a lost response,2s then5s after completion, subject to absolute
server delay and the original deadline. Restoration does not release an occupied
request or replenish calls. Other outcomes close; caller-reported verified
success records completed but does not adopt/renew a key or prove current HA
route/authority. Server receipts and original key expiry remain caller-owned.

At deadline equality, both live phases transition to recoveryPaused, remove
challenge/nonce/clientData/hash/request/hash and retain opaque key/deadline plus
consumed assertion/transport accounting. A late SDK result cannot be saved or
submitted. An expired SDK reservation can remain occupied: no hardware
cancellation or successful completion is inferred. Expiry is logical on access;
failed purge writes throw without exposing call parameters/body, and no forensic
erasure/background purge is claimed. Already-returned copies require another
context/deadline check immediately before actual SDK/transport work.

Encoded protected storage is capped at24KiB, including maximum2KiB clientData
and4KiB assertion within a16KiB request. Restore checks schema, hashes, canonical
IDs, exact closed request shape/format, original clientData field, correct retry
kind, monotonic outer/nested clocks and phase/reservation/accounting consistency.
A failed or commit-then-error storage write releases no external-call parameters;
a later read cannot interpret a committed occupied call as a new attempt. The
actor has no suspension between read/mutation/write and is a sole-process
serializer, not cross-process compare-and-swap protection.

## Qualification and boundaries

Thirteen focused cases cover original unsorted/escaped/whitespace bytes and
SHA256; closed request contents and identical retries across restoration;
Retry-After and2s/5s boundaries; decoded duplicate keys and foreign/malformed
clientData; restored in-flight assertions/requests and wrong callback IDs;
invalid/terminal/late assertion; terminal/success/exhausted request outcomes;
failed/ambiguous admission, reservation and completion saves; read/purge failures;
clock rollback; maximum sizes; corrupt persistence; and20 concurrent assertion
reservations with exactly one winner. Injected storage faults are modeled;
they do not prove real power-loss durability.

The actual source was separately compiled with Swift6 into a new signed scratch
Mac bundle, using the existing valid identity/profile without account changes.
Seven successful separate processes ran against a new synthetic device-only,
non-sync Keychain item; two unsafe namespaces were rejected before access.
Maximum original clientData/hash and occupied assertion survived process exit;
maximum synthetic assertion became a prepared request; another process returned
the identical request hash. Expiry removed material and retained both budgets;
exact cleanup verified absence. Source/executable hashes and process results
are retained under build/qualification/vibecast-recovery-journal. This uses a
supplied clock, not reboot/wall-clock/locked-device/iOS/Watch proof. No real key,
Apple SDK call, API/HA request, app installation or ordinary app replay occurred.

Final unchanged-source full run:901 Swift Testing cases in10 suites plus71
XCTest cases,972 total, all passed. Unsigned macOS and iOS including Watch
dependency builds40379 passed. Protected exact-head review/CI are separate
delivery gates; ordinary installed apps were not replaced by these builds.

The registration, per-recovery request and24h paused-repair journals are separate
items with **no cross-item transaction**. A future lifecycle owner must reconcile
them, retain uncertain handles after interrupted transitions, reserve the explicit
paused-repair budget before admission and never infer a new key/challenge/repair
from a missing item, foreground/Profile change or generic rejection. This slice
does not consume or reset that separate24h ledger. Subsequent explicit recovery,
replacement/two-handle reconciliation and30-day active-key rollover remain open.

Future callers must hold the complete per-key queue, admit the trusted app/
environment/fixed service and current explicit flow, revalidate after waits and
before SDK/transport, await actual SDK completion before releasing the key slot,
and verify server receipts before key adoption. The journal alone grants none
of that authority. The source is intentionally unwired while the qualified native
capture/profile/private transfer and joint API experiment remain separate gates.
Fresh [API handoff6277830018](https://github.com/pcvantol/djconnect-api/issues/90#issuecomment-6277830018)
still requires the actual capture adapter's decoded32-byte nonce/exact action-byte
intake; this recovery journal is not that adapter or genuine fixture evidence.
No fresh nonce/key/capture, production activation, full-chain acceptance or
completion of the overall VibeCast assignment is claimed.
