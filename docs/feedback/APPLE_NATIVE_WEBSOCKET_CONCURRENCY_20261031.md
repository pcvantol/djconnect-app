# Shared native WebSocket concurrency — source qualification in progress

Base: protected main `138a0ba923e5e5d3f3447178b2a5b395b825040d`.
Owner: existing Apple writer; branch `codex/apple-websocket-reader-20261031`.
Scope: real shared native adapter, common client fallback and causal transport
tests. No new Discovery concurrency, backend contract, signing, installation or
provider activation.

Evidence root: `/Volumes/Shared Data/tmp/pcvantol/apple-websocket-reader-20261031`.
The immutable run receipts bind exact input hashes and actual process exits.

- Baseline r2: failed against protected adapter; actual wire reported one
  connection/auth, zero capabilities and two premature commands before auth.
- r4: fixture identity prefix error retained; corrected fixture to the existing
  real client namespace, without weakening production identity validation.
- r8: new test failed to compile (mixed typed ternary); retained and corrected.
- Full r10: 1,439 functions / 37 suites, one failure. Actual Foundation handshake
  exposed a POSIX error outside URLError. Known pre-dispatch startup errors are
  now classified/redacted without enabling post-dispatch write replay.
- Full r11: 1,439 functions / 37 suites PASS, 36.802 seconds; actual exit 0.
- Native Xcode r12: eighteen actual wire test functions PASS / actual exit 0;
  both unsigned Mac/iOS builds also passed. These precede the final common
  fallback guard and additional transport-manager tests.
- Full r13: 1,441 functions / 37 suites, one existing persona-test race. The
  persona test also started independent Broadcast recovery, whose ended-session
  callback may legitimately remove the Session while the persona reply is held.
  The fixture now fences that separate recovery, waits for the real held reply
  and preserves its original persona/error/single-POST assertions, plus an ended
  final-state assertion. No product Session behavior is changed.
- Full r14: 1,441 functions / 37 suites PASS, 37.435 seconds.
- Full r15: 1,441 functions / 37 suites PASS, 27.486 seconds; actual exit 0,
  source unchanged. Includes raw POSIX/decoding write errors and four typed or
  wrapped cancellation cases through the actual Client/HA transport manager.
  Native safe-read and proven pre-dispatch write fallbacks also traverse the
  actual manager; eighteen wire functions retain real Foundation I/O.
- Nine independent contract/localization/hygiene validators: all actual exit 0.
- XcodeGen generated exactly four project entries for the new core test file.

Current-byte native Xcode tests, unsigned platform build results, independent whole-source
and exact-head review, protected delivery and original Source/Final evidence
remain separate gates. No feature-wide or push/device acceptance is asserted.

## Current native qualification predecessor

Full native Xcode r16 exited 65: 1,507 passed, 19 pre-existing conditional skips,
one failed function (`passivePublicationHintDuringImageLoadStillReadsNewestContribution`).
Its original result bundle and summary are retained. The count assertion failed
after a guessed 400 ms completion wait following image IO. The scheduled hint
read is throttled and may run later under native parallel load; the original
failure does not by itself prove the exact count or a product failure. The fixture now observes
the committed newest contribution and completed task within a bounded wait,
without forcing a manual refresh or changing any original count/content/expiry
assertion. Cleanup releases only its held image and owner. No passive product
logic or clock/admission rule changes.

The native Xcode log also reports stale CoreSimulator support (1174.9.2 versus
1174.21.0). Native Mac results and clean iOS simulator readiness remain distinct;
no simulator success or host repair is inferred from the successful iOS build.
Current native/full reruns for this additional fixture delta remain pending.

Full native r18 also exited 65 with one different existing fixture failure:
`choiceBurstCoalescesLastValuePerFieldBeforeOneSend`, whose expected async
perform effect was still empty at the guessed 350 ms assertion. The previous
passive hint failure passed. Choice tests now wait for the actual performed
patch and drained queue, with original exact patch/order/count assertions
preserved; scope withdrawal waits for the actual queue drain. The adjacent
passive hint-burst positive assertion uses the same bounded completion pattern.
Negative no-permission waits remain unchanged. No production scheduler or
passive timing is altered. These latest fixture bytes need their own reruns.
