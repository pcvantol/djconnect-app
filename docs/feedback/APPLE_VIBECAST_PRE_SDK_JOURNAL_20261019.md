# VibeCast pre-SDK attestation journal

Bounded continuation after PR149: persist an admitted existing key, original
server challenge/nonce/hash/deadline and consumed Apple SDK call **before**
releasing its call parameters. This is source/storage preparation, not scanner
activation or actual App Attest enrollment. No backend contract was changed.

## Authority and inputs

The source implementation permission remains `djc-rendezvous/1-implementation.1`,
Finalization main `661e5770eb5249b1b02bbdc2426ba7e575fc8881` and the
[producer receipt](https://github.com/pcvantol/djconnect-api/issues/90#issuecomment-6272409413).
The immutable enrollment-recovery input SHA256 is
`851d9756352bed3e03e5c60f1d2709596d58c10e24180e97d67d4514531f1832`;
request schemas SHA256 is
`c00d495222a5bc719e5ef22280e4bbacbb7496f03740cb9c6ccf8b464f4d8a0d`.
The preceding [prepared-registration report](APPLE_VIBECAST_PREPARED_REGISTRATION_20261019.md)
records the normative source-anchor/banner distinction. This slice consumes
those rules and confers no runtime or production GO.

## Implemented behavior

RendezvousRegistrationJournal now stores both pre-SDK and prepared-registration
phases in the **same existing** device-only Keychain item. beginAttestation
accepts only the canonical existing key ID, original32-byte server challenge
ID/nonce and original bounded deadline. No existing record, including completed
or uncertain records, can be replaced. This method creates no hardware key,
challenge, request, timer or endpoint.

reserveAttestation returns only the existing key, attempt/reservation IDs,
original deadline and SHA256 of the saved original nonce bytes. It persists the
consumed call/reservation before returning. Failed or ambiguous writes return
no call parameters. A committed but unacknowledged write leaves its reservation
occupied on restore. Actual SDK callers must not start without a successful
reservation, or resubmit a restored in-flight call.

The SDK and registration windows retain separate counters with the **same
original** start/deadline, never a fresh120s window after SDK completion. Only
the typed serverUnavailable result permits another same-key/hash SDK attempt:
at most three calls,2s then5s after the previous completion, no overlap. Other
SDK failures close conservatively, retaining the handle/accounting and purging
nonce/proof. The result mapping is caller-owned; no Apple error mapping or
fixture qualification is claimed here.

A matching SDK completion containing1–32768 opaque bytes builds the closed
registration body once and persists it with its hash before submission can be
reserved. It does not return the proof/body from completion. Wrong/duplicate
IDs cannot replace it. Empty/oversize proof closes the consumed SDK attempt and
throws invalidMaterial instead of replenishing attempts. This validates sizes
and bindings, not Apple attestation cryptography/CBOR.

At deadline equality, either live phase becomes registrationUncertain and
removes challenge, nonce, nonce hash, request and request hash before returning
anything. Late SDK callbacks cannot save or submit their proof. Consumed
in-flight reservations remain known; hardware cancellation is not assumed.
Expiry is access-enforced logical removal, not a background purge or forensic
erasure guarantee. Failed purge writes throw without releasing parameters or
bytes. Previously returned copies still require a caller deadline/context check
immediately before an SDK/HTTP invocation.

## Restore and migration

The fixed Keychain service/account and96KiB encoded bound remain unchanged.
Schema2 explicitly distinguishes tracked SDK admissions from prepared imports;
missing provenance is rejected. Tracked records require the SDK window, its
correct kind and matching original start/deadline, journal clock at least as
recent as both windows, no registration call during the pending SDK phase and
a closed consumed SDK window before a prepared/completed registration. Existing
nonce/hash/body/schema validation remains in force.

Valid schema1 prepared/uncertain/completed records migrate **in place**, retaining
attempt/key/deadline, exact original request bytes, consumed registration calls
and in-flight reservation. They are explicitly marked preparedImport; no SDK
history is fabricated. The previous prepare API remains a post-SDK import for
source compatibility. It cannot override an existing pre-SDK record and does
not confer permission to run an unjournaled SDK call. Future SDK enrollment must
use beginAttestation/reserveAttestation. This is structural validation under
the existing protected storage boundary, not tamper-proof accounting against a
compromised client with its own Keychain access.

## Qualification

Twenty-three focused journal cases pass, including11 added pre-SDK/migration
cases: same hash through2s/5s retries/restarts; separate registration budget;
SDK in-flight restoration; wrong/duplicate callbacks; terminal/exhausted SDK;
expiry equality/late proof; near-deadline successful handoff; invalid proof;
failed and commit-then-error saves at admission/reservation/completion; v1
migration of all three phases; malformed provenance/windows/hash/clock; and20
concurrent reservations with exactly one winner. Injected faults are modeled
storage outcomes, not real power-loss observations.

The tracked qualification probe compiled the actual production sources with
Swift6, used a new signed scratch Mac bundle under the existing development
identity/profile and ran eight successful separate processes against a fresh
synthetic Keychain row. Two unsafe namespace calls were rejected before access.
The processes verified device-only/non-sync metadata, restored occupied SDK
reservation, original nonce hash after a retry, maximum synthetic proof to
prepared-registration handoff, identical request hash across another process,
expiry removal with both consumed counters intact and exact synthetic cleanup.
No ordinary app was installed/launched/replaced, no account/profile was created,
and no real key/Apple SDK/HA credential/network operation was used. The signed
probe and source hashes bind this readback. This is real native persistence
with a supplied clock, not reboot, wall-clock soak, locked-device, iOS or Watch
hardware proof. Evidence is under build/qualification/vibecast-pre-sdk-journal.

The full unchanged-source run passed901 Swift Testing cases in10 suites and58
XCTest cases (959 total). Unsigned native macOS and iOS including Watch
dependency builds40378 passed. Protected exact-head review/CI are separate
delivery checks. The ordinary installed apps were not replaced by this slice.

## Integration boundary

The shipping scanner remains unwired. Future callers must hold the shared
complete per-key operation queue, revalidate current owner/action/key and trusted
app/environment/origin after waits, honor original deadlines and verify server
receipts before adopting an active key. Actors serialize one owning process;
there is no cross-process compare-and-swap or independent-writer authority.
SDK reservation is conservative: interruption can leave a call occupied until
the original deadline; it must not be interpreted as retry/new-key permission.

Management recovery still needs its own exact saved server clientData/assertion.
The separate paused-repair item is not a cross-item transaction. Lifecycle
reconciliation,24h replacement/two-handle limits, active30-day expiry/day27
rollover, real iPhone App Attest fixtures, qualified API target and TV E2E remain
separate work. No public activation, new key, signing configuration, service or
HA change follows from this source slice.
