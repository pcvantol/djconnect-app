# API-issued SDK input expiry correction — 20 October 2026

API90 and the fresh Apple87 review identified a P2 in the delivered PR154 source:
`deadlineMS - requestedAtMS <= 120000` incorrectly measures the server challenge
TTL from the client's original request timestamp. The API starts that TTL at
server challenge creation, after the request has been sent.

The exact counterexample is client request1000ms, server creation1001ms,
server expiry121001ms and native receipt1002ms. The genuine challenge has119999ms
remaining, while the former native check rejects its120001ms request-to-expiry
interval. This applies to both registration and action inputs.

## Correction

The binary intake retains both original timestamps. At construction it bounds
`deadlineMS - observedAtMS` to the server's maximum120000ms remaining window,
requires the original request <= construction observation < original expiry,
and keeps safe nonnegative integer bounds before subtraction. Later checks
reject any wall-clock rollback below that observation and reject at the original
absolute expiry. The original ContinuousClock anchor remains at construction;
frozen clocks and construction-to-dispatch delays cannot renew the lifetime.

No original `requested_at` is relabelled. No deadline, serverTTL, nonce, key,
clientData bytes, canonical binding, durable pre-SDK reservation, serial SDK slot,
cancellation/late-callback guard or error-redaction rule is replaced or relaxed.
No API production contract or verifier profile is changed.

## Qualification

Two new pure regressions reproduce the API counterexample and the remaining-window
boundary before the source edit: the old source yields28tests/2failures. After the
source correction, all28isolated binding/intake tests PASS. Positive coverage
includes decoded registration and submit/delete-key/recover-key actions with
server creation after the original request, preserving their exact request and
absolute expiry. Negative coverage rejects >120000ms remaining, unsafe maximum,
expired/equal-deadline input, future request and negative request. Existing frozen
clock, rollback, delayed dispatch, expiry during SDK, changed context/key, save,
cancellation and proof-size fences remain green. A former invalid-request test
for `start-1` was removed because that one-millisecond pre-creation latency is
legitimate under the API contract; negative/future/expired request checks remain.

These are pure injected SDK-closure/source tests, not real DeviceCheck proofs.
No new key/nonce/assertion/capture, signature/profile/OS trust change, installation,
service activation or personal context mutation occurred.

## Artifact / acceptance boundary

The historical [40380 proposal](../../Tools/qualification/vibecast-native/PROFILE_PROPOSAL_40380.json)
and its independently checked89-file signed artifact are unchanged and **do not
contain this correction**. Their source/artifact hashes cannot qualify the new
candidate. The [existing binary intake runbook](../../Tools/qualification/vibecast-native/API_BINARY_INTAKE.md)
still governs exact source/artifact/profile and joint readiness.

After review/protected source delivery, a newly bound signed diagnostic candidate
and separately reviewed API admission are still required before a genuine joint
run. No reuse of old40380 acceptance or40227/28/30 policy is implied; no new build
number/profile/installation authority is selected here. All native physical,
cryptographic, API, HA and TV acceptance remains separate and open.
