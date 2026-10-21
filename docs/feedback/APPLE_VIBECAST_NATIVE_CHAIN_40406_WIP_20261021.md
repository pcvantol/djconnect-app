# Native VibeCast chain candidate40406 — work in progress

This is ongoing implementation for the owner's instruction to finish VibeCast
with the existing API lane. It is not a signed-build proposal, source delivery,
SDK execution grant, operational admission or successful television connection.

The fixed QA app now calls a native coordinator after the existing selected-HA
owner-context and JOSE preparation. A genuinely empty lifecycle can generate one
key, enroll against the original binary32 nonce, and activate only after the
verified registration201. Subsequent QR requests reuse the active key. The new
submission journal persists assertion and HTTP reservations before effects,
retains original clientData bytes, bounds restored state and expiry, and blocks
new challenges while a prior operation remains uncertain. Full per-key FIFO
covers challenge/sign/submit. A late or duplicate SDK callback cannot release a
newer operation's physical SDK occupancy. Cancellation does not imply hardware
cancellation. Generic errors never trigger automatic new keys, signing or resend.

API202 means historical accepted operation only. UI messages distinguish that
from uncertain outcome and never claim browser consume, TV navigation or Core B
screen consent. Core B remains the separately implemented owner approval flow.
Production's native path remains closed pending its own selected profile; the
source candidate is limited to the separately compiled fixed QA identity.

Initial focused memory/fake-SDK/intercepted-HTTP tests passed12 functions across
two suites. They exercise fresh enrollment, binary-nonce hashing, original-byte
assertions, active-key reuse, lost201/202, owner withdrawal, FIFO and duplicate
callbacks. These are synthetic executions, not genuine App Attest evidence.
After the original-deadline/body-fence and finite-test-wait corrections,
the v3 fixed-QA run passed 13 XCTest and 18 Swift Testing cases (31 total).
The same 173 recorded source inputs compiled successfully for real iphoneos
with signing disabled, bundle dev.djconnect.ios.vibecastqa/build40406.
The actual unsigned executable SHA256 was
379ba49da1abeaeda0b627777071de35ba895fd0ef7f8bfab9d68e3af9bd85a1.
These WIP inputs were recorded as dirty, without a qualified source SHA. Full
production regressions and all signed/native/profile evidence remain pending.

API implementation remains the already released
`djc-rendezvous/1-implementation.1`, source
`3b43332bb28ed4aea228938f2d3a61796c8c3f33`. No backend message/authority model is
changed here. Its QA guard is closed and no current signed Apple profile is
selected. The intended separate QA bundle is `dev.djconnect.ios.vibecastqa`,
candidate40406; actual signature, App ID/prefix/environment/provisioning and
artifact hashes must be read back before the API owner can qualify a new exact
profile. No older40381/production profile is relabeled or admitted.

Remaining work includes explicit same-key recovery/replacement/rollover product
orchestration and its tests, complete native callback/foreground qualification,
independent source/profile review, protected source delivery and actual signed
build preparation. API activation, receiver Pages authentication, effective HA
external routing, a finite genuine SDK run, browser navigation and physical B
acceptance remain separate actual gates. Earlier iPhone/Watch availability was
deferred by the owner; no device action or success is inferred from this source.

## Continuation after the UI fixes

The original-response deadline correction passed the broader production-origin
Rendezvous regression run: 93 Swift Testing cases. The new adaptive icon was
merged from protected main and the combined Xcode project was regenerated.

A typed recovery challenge parser now binds the exact existing key, action
`recover-key`, fixed service origin, server challenge ID, decoded binary nonce,
original clientData bytes and original wall/monotonic deadlines. Its four focused
regressions passed, including action separation, every-field mutation, duplicate
JSON members, noncanonical base64, expired/extended response and clock rollback.
These functions perform no HTTP, SDK, key generation or repair-budget mutation.
Management transport, explicit recovery/replacement/rollover orchestration and
physical acceptance remain open. This is still a WIP source branch, not a
completed VibeCast release or an API activation request.
