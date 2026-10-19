# VibeCast bounded retry accounting — source slice

The existing Apple lane continues API's released
`djc-rendezvous/1-implementation.1` contract, Finalization main
`661e5770eb5249b1b02bbdc2426ba7e575fc8881`, after Apple PR144. The exact pinned
`docs/rendezvous/ENROLLMENT_RECOVERY_V1.md` was retrieved and verified SHA-256
`851d9756352bed3e03e5c60f1d2709596d58c10e24180e97d67d4514531f1832`, matching
API's released manifest. Historical candidate wording in that document is
superseded for source implementation by the exact producer release/receipt;
operational and real-device acceptance remain separate.

## Implemented boundary

`RendezvousRetryWindow` is a versioned Codable install-local accounting value.
It records one fixed deadline, consumed calls, one in-flight reservation and
absolute next eligibility and the original completion timestamp. Constructor limits the original window to120 seconds;
expiry equality fails closed. Initial call plus at most two retries are allowed.
The2s/5s delays start at the preceding completion, not at a newly generated
challenge. Absolute Retry-After eligibility can only delay the next call.

| Kind | Retryable completion | All other completions |
| --- | --- | --- |
| Apple attestation | Apple serverUnavailable | Stop |
| Registration | Response lost | Stop |
| Key recovery | Response lost | Stop |

The budget never calls the SDK or transport and cannot generate a key/challenge.
Each reservation has a local identity; duplicate or mismatched completions cannot
release the current call. A late completion clears and closes accounting, then
throws expiry so it cannot be treated as a timely accepted result. A restored
in-flight reservation blocks a new call rather than replenishing the budget.
Backwards supplied time and malformed/unknown-version stored states are rejected.

## Integration obligations still open

This value is not yet wired to a production enrollment journal or scanner.
Codable round trips qualify representation/restoration; **no actual durable
Keychain write or crash-recovery test is claimed**. The future journal must bind
it to the same key/challenge/exact saved request, persist a reservation before
starting an external call, and persist completions atomically. A failed storage
write must prevent the external call. Use the previous shared per-key coordinator
for the complete SDK and submission/recovery operation; this value is not an
independent concurrency lock. A persisted in-flight call after restart needs
explicit outcome recovery, not replay by merely constructing another window.

Only admitted original deadlines may be supplied, capped by applicable original
key/challenge bounds. Waiting, restart, route/Profile changes, or foregrounding
cannot create a fresh attempt or renew anything. Supplied time must come from
the caller's consistent clock policy; these local checks are not a remote expiry
or anti-tamper authority. Closed accounting says nothing about whether the remote
key was registered, revoked or hardware-erased. Retain the unresolved handle.
The24h repair window, bounded explicit same-key repairs, two-handle/replacement
limits, absolute key expiry/day27 rollover and actual SDK error mapping are
separate lifecycle integration work; no generic failure authorizes key creation.

## Qualification

Eleven focused XCTest cases cover attestation/registration/recovery budgets,
2s/5s boundaries, server delays, deadline equality and late success, wrong error
classes, exhausted budgets, Codable in-flight/backoff restoration, wrong/duplicate
completion identities, clock rollback, malformed budget and unknown schema. The review regression rejects restored elapsed/shortened backoff and retains legitimate early-poll and elapsed-real-time restoration. Decoding recomputes minimum eligibility from the recorded completion, rather than incorrectly restarting backoff after every observation. The new negative cases fail against the preceding reviewed sources in an isolated tiny package and pass after the fixes. A further review regression checks the cumulative minimum timeline (first retry at least2s after origin, second at least7s) for completed and in-flight attempts. Every legitimate phase is round-tripped at its earliest boundary using a nonzero origin.
Logs/receipts are under ignored
`build/qualification/vibecast-bounded-retries/`. The first compile was restarted
after an owned source edit changed its input during compilation; only the final
unchanged-source runs qualify this candidate.

No App Attest key/assertion, fresh capture, API challenge/request, installation,
service/HA/signing/environment change or activation occurred. The installed Macs
remain ordinary40370. Genuine SDK/server/TV acceptance requires the API-owned
qualified test target and is not substituted by these controlled-state tests.
