# VibeCast paused same-key recovery accounting

This source slice follows PR144/145 under the existing Apple scanner assignment.
It consumes API's released `djc-rendezvous/1-implementation.1` contract at
Finalization main `661e5770eb5249b1b02bbdc2426ba7e575fc8881` and the exact producer
[receipt](https://github.com/pcvantol/djconnect-api/issues/90#issuecomment-6272409413).
The pinned ENROLLMENT_RECOVERY_V1.md SHA256 was rechecked as
`851d9756352bed3e03e5c60f1d2709596d58c10e24180e97d67d4514531f1832`.
Historical candidate wording in the document does not override that released
source-implementation permission; live operation remains separately gated.

## Implemented boundary

`RendezvousRepairWindow` accounts for **at most two explicit same-key recovery
attempts in the original24h pause window**. It retains the exact opaque key handle,
original pause/end timestamps, per-attempt identity/start/completion/outcome and
an absolute server delay that can only move later. There are no Profile, Session,
HA, route or credential fields and no automatic scan/resume/background action.

Attempts start at least60s apart. The first attempt conservatively waits60s
after entering pause too. A running attempt blocks overlapping work even after
that interval. Re-entering pause through completion cannot reset the original
window or replenish attempts. Recovery success closes this accounting; it does
not generate or extend a key. Window-end equality refuses a new attempt and
does not authorize replacement enrollment.

Each attempt must also have its own original120s challenge/retry budget from
RendezvousRetryWindow and use the shared complete per-key operation queue.
The24h repair window is not a remote challenge/key expiry: an already-started
attempt may finish after that window, but the caller still must validate the
actual original recovery challenge, returned original key expiry and owner
context before reporting success. The model cannot establish server acceptance.

Versioned Codable restoration retains reservations, attempt counts and delays.
Restored in-flight work does not authorize another recovery attempt. Decoding
rejects changed window length, unknown schema, empty handles, duplicate attempt
IDs, excess attempts, incomplete completion/outcome pairs, impossible timelines,
overlap, premature spacing and an attempt after a recovered result. Backwards
supplied time and arithmetic overflow fail closed.

## Integration obligations

The production scanner does not yet use these components. This is not durable
Keychain persistence or restart/crash qualification. The future install-local
protected journal must retain the same ledger across restart, scans, foreground
and Profile changes, atomically persist reservations **before** SDK/transport
work and stop on write failure. Constructing a new ledger per scan would violate
the contract; a Codable value cannot prevent a caller from discarding history.
Do not sync, log or place the handle/accounting in ordinary Profile settings.
The consistent clock policy and actual user-intent admission remain caller-owned.

After interrupted in-flight work, retain its outcome uncertainty and resolve it
under the original recovery-operation receipt/challenge policy. Do not clear a
reservation or create a fresh challenge merely because the app restarted.
SDK retries, key/challenge action binding, exact request retention and actual
error mapping remain distinct requirements. Unknown/invalid responses mean
paused, never a hint that a new key is safe.

Replacement enrollment after cooldown, one replacement per24h, at most two
unresolved handles, second-uncertain-handle diagnostic resolution and day27/30
rollover are still separate lifecycle work. This ledger exposes no replacement
method and cannot erase/retire/revoke hardware or remote keys. The API-owned
qualified live target and genuine SDK/server/TV acceptance remain open.

## Qualification

Nine focused tests cover exact spacing and exhaustion across Codable round trips,
server-delay retention, expiry equality, success without renewed dates,
wrong/duplicate completion identity, long-running calls, invalid clocks/overflow,
all legitimate phases and malformed persisted timelines. Evidence is retained
under ignored build/qualification/vibecast-paused-recovery. The unchanged-source
full run passed901 Swift Testing tests in10 suites plus25 XCTest cases
(926 total); native macOS and iOS including Watch dependency build40375 both
passed unsigned. Protected CI and exact-head independent review remain separate
delivery checks.

No App Attest key, assertion, capture, API operation, service/HA/signing change,
app installation or live activation is performed by this slice. Core deletion
and Brand V2 adoption remain gated on their own accepted producer contracts.
