# VibeCast retained handle journals — Apple source proposal

Proposal under the existing integral Apple assignment, 22 October 2026. Not implemented or admitted for SDK/API effects. Existing same-key recovery v2 review remains scoped to its immutable snapshot. This proposal requires owning API source review before product wiring; it changes no server contract, schedule, QR or B consent.

## Contract join

Independently read protected API `9ab24315a10b569b84e738d09bf32df6da12e38b`:

- `ENROLLMENT_RECOVERY_V1.md` SHA256 `851d9756352bed3e03e5c60f1d2709596d58c10e24180e97d67d4514531f1832`.
- `KEY_STATE_V1.md` SHA256 `4516319d5635964f2175ad36e89266d80204573253c0cf2e5c83892254930cd2`.
- `WIRE_PROFILE_V1.md` SHA256 `b812ea0dfdaca08e7128b227697a225071b72f28098c556650d76bb24f6029f2`.

Candidate0.4.0 remains NOT_FROZEN / NO_RUNTIME_GO. Native/operator/API admission stays independently closed. Replacement retains original paused24h and one replacement allowance per24h, with at most two unresolved handles. Foreground day27 rollover and absolute day30 expiry are separate. Each new handle has its own fresh original120s enrollment and counter; neither proof nor authority transfers.

## Concrete local composition

Keep `RendezvousKeyLifecycleJournal` at its existing fixed installation/app-environment address as the generation, pause, replacement and original-expiry authority. Do not create a fresh root for a Profile, QR, app build, retry, failure or changed environment digest.

Add one fixed-address composition record, under the same qualified stable app/environment digest. It is a companion to that root, not a second generation authority. It contains a monotonically increasing local slot sequence, the matching lifecycle generation identifier/purpose, selected and pending slot identities, and an optional fail-closed activation transition. It has two fixed child slots, not an unbounded directory or one new namespace per attempt. Each child holds the existing registration/recovery/repair/submission payloads independently. New code does not reinterpret or transfer their nonce, proof, reservation, request, counter or allowance.

A child storage capability binds exact root digest + slot sequence + lifecycle generation ID. Reads and writes re-read/validate that binding. A detached or retired capability fails before any journal material or side-effect bytes can escape. Late SDK/HTTP completions cannot write into a reused slot, select themselves or mutate a successor. Missing, malformed, inaccessible or ambiguously written composition state never means empty installation.

### Initial/legacy admission

Before first production use, acquire the existing global installation slot and the affected existing per-key FIFO. Reconcile the actual lifecycle and all fixed singleton journals, including historical diagnostic occupancy. An occupied legacy installation must be imported as occupied, never initial-eligible. Unknown generation or a missing/mismatched handle stays paused. A bare SDK handle is not an active key. Legacy adoption cannot produce a new SDK reservation or renew a deadline.

Legacy journal accesses must use a root fence before migration is enabled. Unwrapped old singleton writers cannot coexist with active slot reuse. Migration must preserve original bytes and reservations before routing changes. Its commit states must be explicit and restartable; partial migration blocks new effects. A changed app/environment digest refuses the existing address rather than finding another empty one.

### Replacement or rollover reservation

Only a fresh explicit owner action with separate current native/effect admission may request replacement/rollover. Serialize globally, check lifecycle eligibility and original pacing, consume the lifecycle generation reservation, and durably bind the candidate child before generation. Failure of either persistence step leaves the consumed reservation occupied; it never starts SDK generation or makes another slot eligible. The generated callback is recorded against that original lifecycle reservation even after UI owner loss, without activating it.

The new child then uses the existing exact challenge/attestation/registration adapters and original deadlines/retry limits. No public arbitrary child factory or caller-supplied context can create an empty budget. A second unresolved child blocks a third. Generic proof failures, repeated scans, Profile changes and expired QR do not request replacement or rollover.

### Selection and retirement

A validated new registration ACK is the sole input to candidate activation. Persist a terminal transition that closes old child effects before updating lifecycle selection; then complete the joined lifecycle/composition state. If either write is uncertain, no key is selected for new effects until a read-only reconciliation can prove the same original transition and acknowledged receipt metadata. Do not obtain a fresh grant or rerun an external operation to repair that uncertainty.

A recovery ACK for the old handle may restore its original still-valid state but must preserve an unresolved candidate. It cannot retire or select the new child. Stale ACKs for a retired generation cannot undo the transition.

After successful joined activation, the old LOCAL child is terminal. This is not server revocation, Apple hardware erasure or proof that an old server key is gone. The old server key may remain until its original expiry.

## Finite metadata and sensitive-material disposal

No numeric client retention interval is invented or copied from server expiry+120s/cleanup15min. The two fixed slots and retained root sequence bound metadata growth. A slot is reusable only after its old generation is irreversibly terminal and joined reconciliation proves no unresolved selection/persistence transition. The root's spent generation/replacement/pause accounting and monotonic sequence remain; a delayed callback with an older sequence is forever non-addressable.

Raw proof/nonce/request material is discarded at its original expiry or terminal retirement through explicit owning journal transitions. Keep only minimal terminal accounting/fences. Never archive raw proof indefinitely. A failed cleanup must not reopen admission; keep the root/slot closed and report the unresolved cleanup. No directory deletion, new root, slot reset or record removal is used to create permission. Exact migration/tombstone/redaction schemas must be reviewed with the implementation; until then, preserve ambiguous existing state and pause rather than purge to make room.

## Required causal evidence before product wiring

- Legacy occupied/empty/unreadable/malformed/changed-context reconciliation and no initial permission from missing companion state.
- Persistence before/after-commit failures at each generation, child binding and activation step; restart from every joined transition.
- Generation callback lost/late, unknown challenge/expired enrollment and original retry budgets; no third handle after uncertain replacement.
- Pause/replacement/counter continuity through restart/Profile/update and clock rollback; day27/day30 equality and bounded overlap.
- Old-key recovery after candidate reservation/activation, retired callback after fixed-slot reuse and wrong generation IDs.
- Global generation slot plus per-key FIFO across both handles; owner loss and original deadline after every await.
- Existing135-test same-key recovery slice and both reviewer counterexamples stay green; no old reservation/Retry-After release.
- Independent exact source snapshot review and normal protected delivery. Genuine native A→HA→B→TV acceptance remains separate and cannot be manufactured by synthetic tests.

## Revision2 — review correction: explicit exclusion and activation protocol

Owning API proposal-v1 review requested this clarification (one P2 design issue, not an implemented bug). The old path may own a key and then await installation admission. A transition must therefore **never wait for a key while owning installation admission**.

1. A new internal `performInstallationTransition` acquires the existing installation FIFO normally. Inside the queue actor, without suspension, it attempts every affected key slot in canonical sorted order. If any key is busy, release all slots acquired for this attempt and installation admission, then return a distinct busy result. Do not wait, automatically retry, treat timeout as success or start partial migration. The existing key holder can then obtain installation admission and finish. Cancellation likewise releases only this attempt's slots.
2. A successful transition owns a sealed, non-transferable lease for exactly that key set and installation slot. Its body performs only bounded local journal reads/commits. It must not call the public queued `perform` recursively for a borrowed slot. The task-local lease has explicit synchronous borrowing for owning journal operations; a wrong key, descendant after closure or concurrent descendant is refused. No caller can manufacture the lease. All affected slots are released together when its bounded body returns.
3. Native generation and enrollment retain their separately admitted adapters. Local reservation/binding happens in a transition, then releases it before network work. When generation requires installation exclusion, it uses qualified non-waiting key admission as the existing initial adapter does; it never queues for an affected key while holding installation admission. New-key callbacks bind only the original consumed generation. There is no migration/activation lock held across HTTP or SDK waits. Same-key sign→submit keeps its existing complete per-key FIFO.
4. The child store's root/sequence/generation validation is in the **same synchronous critical section** as its read or read–modify–write. There is no await between validation and commit. All production handles share one fixed-address store and fixed OS-level exclusion lock, as well as in-process serialization; separate store instances cannot bypass the exclusion. A missing lock file is not an empty root or generation grant. Overflow, sequence rollback, lock/inode inconsistency and before/after-commit ambiguity close access. Any concrete platform lock implementation must be separately tested before wiring.
5. Legacy fence and quiescence use this non-waiting transition protocol before routing changes. Capture all original registration, recovery, repair and submission occupancy/reservations, original root digest and lifecycle identifiers. A partial/mixed import remains explicitly migrating and denies effects. Do not hold exclusion while awaiting the old operation needed for quiescence. Unwrapped legacy writers are forbidden once migration begins; migration cannot be enabled until every production access uses the fence.

The atomic helper is a new narrow local exclusion primitive, not a permission or a new public SDK path. Required counterexample: hold old key, start its wait for global admission, start migration, then prove migration refuses busy without partial writes and the old operation completes. Also exercise the opposite acquisition order, partial acquisition of two keys, cancelled waiters, concurrent descendants and cross-instance storage exclusion.

### Persisted ACK association and commit stages

A plain registration201 or recovery200 body is not an activation receipt. Only the existing owning adapter's validated original request/response join may construct the internal activation material. Bind: original app/environment digest; old/new lifecycle generation IDs and exact key IDs; old/new fixed slot sequences; original registration/recovery attempt and operation IDs; original challenge digest and deadline; exact prepared request digest; acknowledgment kind and time; immutable original key expiry; and explicit commit stage. Retain no raw response/proof/nonce in the transition. Slot identity and request digests are fences, not executable references.

Stages are `acknowledged_transition` → `lifecycle_committed` → `selection_committed`. Persist the first stage only after a certain adapter-qualified acknowledgment of the original operation. It closes old/candidate effect access before lifecycle selection. Each stage is idempotent only for byte-equal original material. An uncertain write admits no effect and cannot be followed by an independent best-effort release. Reconciliation checks the original joined records and expiry, then advances only that same local stage; contradiction remains paused. It cannot manufacture the first acknowledgment, upgrade `registration_uncertain`, interpret a lost HTTP response as success, renew original expiry or use a new request/receipt as a substitute.

After reconciliation, selection is install-local accounting only. Every future SDK or API operation still needs fresh explicit foreground owner/native/effect admission and original current key lifetime. Read-only reconciliation supplies none of that authority. Expired selected keys stay expired. Old-key recovery cannot clear or select a pending candidate, and an old-generation ACK cannot overwrite a later committed transition.

Slot reclamation retains the root sequence and spent global pause/replacement/generation accounting. It clears only a joined terminal child's sensitive material; an incomplete redaction/retirement remains closed. No client retention duration, server tombstone rule or fresh namespace is introduced. Full concrete schemas and the causal implementation remain subject to the next source snapshot review.


## Test ordering clarification — 23 October

The full07c4 lane run passed1,198 Swift Testing functions but failed one XCTest:
`testEarlierKeyGlobalWaiterFinishesBeforeLaterTransition`. That test assumed an
inner installation-slot return implied the outer key owner had also returned.
Actor scheduling does not guarantee that; the intended nonwaiting transition may
correctly observe the still-owned key and refuse it. Product exclusion is
unchanged. The corrected test holds that outer key at an explicit barrier,
requires busy/no transition body, then releases it and separately starts a new
local transition. All13 queue XCTest cases pass0.007s. The failed full run remains
failed; a new complete run is required before candidate qualification.

## Current contract precedence — 24 October 2026

Protected API source `69ed0fd75833f21c0b3862624e34c2e75efa3dc5` retains the
exact recovery, key-state and wire documents pinned above. The Apple reader also
independently matched `IMPLEMENTATION_CONTRACT_RELEASE_V1.md`, its machine record
and `wire-request-schemas-v1.json` against the same historical9ab24315source:
all six immutable blobs are byte-equal. Owning API readback:
`apple-journal-contract-pointer-69ed-api-readback-20261024.json`, SHA256
`f1c9d61870300d14487d77b2886a2c44fb7126d70dd8ddf7a17cc46f7c768112`.

The explicit `djc-rendezvous/1-implementation.1` release selects enumerated
source/wire/lifecycle semantics FOR IMPLEMENTATION and gives them precedence
over historical0.4.0-draft/HOLD/NOT_FROZEN labels. Those old labels in this dated
proposal are not a blanket block on further Apple source preparation. This
readback changes no message, endpoint, lifecycle policy or server contract.

The new bootstrap/import/activation composition still needs its own concrete
schemas, causal implementation and exact independent review. The separately
reviewed same-key, exclusion and child-store primitives are not whole-composition
approval. Product wiring, real SDK/native/effect admission, operational gates
and the physical iPhone/HA/receiver chain remain separate; this clarification
supplies none of them and creates no production factory.
