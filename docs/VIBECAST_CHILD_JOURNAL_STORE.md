# VibeCast child journal store — source preparation

22/23 October 2026, existing Apple lane. Internal prototype only. There is no shared instance, product factory, automatic bootstrap/import, allocation/reuse API, legacy routing change, activation transition, SDK or HTTP effect. Existing lifecycle accounting remains the only generation/pause/replacement/original-expiry owner. An internal `selected` storage row does not make an active SDK key.

## Fixed schema and original binding

`RendezvousHandleJournalStore` consumes an already reconciled record at a separately selected backing address. Missing/malformed/inaccessible state throws; it is never initialized to an empty child. The eventual trusted factory must join original lifecycle IDs, all occupied legacy singleton reservations and original stable app/environment context before constructing a production store. That factory and its crash/restart join are not implemented by this slice.

The candidate local record has schema1,32-byte app/environment context, retained physical lock identity, high-water slot sequence, selected sequence, closed flag and at most two fixed slots. A binding includes slot0/1, nonzero sequence, original lifecycle generation UUID and canonical App Attest key identifier. Each slot has exactly four channels: registration, recovery, repair and submission. Each channel has an unsigned revision plus optional original opaque journal bytes. Retired rows cannot contain proof bytes or be addressed for reads/writes. There is no growing proof archive or new client retention interval.

The existing per-channel byte limits remain98,304/24,576/16,384/65,536 respectively. The whole encoded envelope is bounded by their two-slot base64 capacity plus a fixed metadata allowance. Full owning journal schema, original clocks, nonce/request equality and retry rules remain with the existing journal actors. The store additionally refuses wrong-key bytes, empty-reset writes and a submission's mismatched app context. It creates no new attempt or grant.

## Physical identity and atomic access

Every store operation validates root context, root lock identity and exact slot/sequence/generation/key binding inside the same synchronous physical exclusion as the backing read or read–modify–write. Normal file acquisition never creates/adopts a missing/replaced lock. A new independent identity cannot read or mutate an old root because its retained identity must match exactly. Product anchor provenance and the one-time root/file bootstrap transaction remain separate gates; the low-level O_EXCL utility is not empty-root proof.

The lock order is: existing logical installation/key admission where required → one journal's synchronous writer lock → fixed physical storage exclusion → backing read/write. No physical lock is held over Swift await, queued key acquisition, SDK or network work. Ordinary root operations never call back into a journal's writer lock. The already reviewed nonwaiting installation-transition primitive owns its own logical exclusion; it is not a substitute for the physical lock.

Independent storage handles compare their original read revision against the freshly read channel before writing. Revision overflow, stale/reused binding, observed high-water rollback, malformed context or closed root rejects the operation. The whole envelope is persisted and read back before advancing the writer's expected revision. A failed or uncertain write advances no caller reservation; if it actually committed, its spent state is discovered on the next read and cannot be overwritten using the old expected revision.

RAM high-water checks detect rollback already observed by that store instance. They are not a claim of hardware anti-rollback across restart; the future factory must join the retained authoritative lifecycle before routing. No new durable counter authority is invented beside that lifecycle.

## One actor per mutable writer

A raw child storage cannot read/write. The existing journal initializer claims a fresh opaque RAM owner and receives its bound writer. A second journal actor offered the same storage object is denied, including if an already bound writer is passed again. This prevents a second actor's read from advancing a shared mutable compare-and-swap view behind the first actor. Fresh independent child handles still coordinate through the physical lock and revision check. There is no release/reclaim of a live writer token to create a new allowance.

The storage protocol's default claiming method returns the original storage, preserving existing fixed singleton/qualification backing semantics. The four journal initializers use that method; their retry, deadline, reservation and same-key recovery logic is unchanged. Only composed children override it. These small existing-file changes require explicit regression/review; prior same-key v2 GO is not automatically expanded to the new composition.

## Qualification boundaries

Synthetic tests seed the prototype record directly in private in-memory backing storage. They use real existing journal actors and real private temporary file exclusion, not a production bootstrap. Covered: missing/malformed/closed/wrong-context roots; independent writers and stale CAS; exact key/slot/generation; root lock mismatch; empty reset; revision overflow; old capability after simulated qualified slot reuse; observed rollback; before/after-commit and silent-drop persistence; duplicate actor ownership; original enrollment deadline proof removal while retaining the occupied attempt; original repair reservation after ambiguous commit/restart.

The simulated metadata replacement in slot-reuse/rollback tests is deliberately test-only. The production store exposes no allocator or retirement API. No local policy duration, remote revocation, Keychain deletion, current owner authority, paid/provider/native success or integral VibeCast acceptance is inferred from these tests.


## Independent bounded review — 23 October

API independently matched the9-file immutable manifest
`bc13f9bbbabb3d7f1f59864f7a7ec81cdd8c1466fba457a1ffc134f1e5279c6c`
and returned `SOURCE_GO_CHILDSTORE_CAS_ADAPTER_SLICE_ONLY`. Its independent
probe exercised the real store, physical exclusion, registration/repair actors
and original attempt accounting with synthetic private backing; no SDK, HTTP
or production Keychain bootstrap was involved. Receipt:
`/Volumes/Shared Data/tmp/pcvantol/djc-api-apple-childstore-review-20261023/receipt.json`.
The complete lane suite passes1,195 tests/24suites; ordinary Apple targets
compile unsigned. Neither result expands this prototype into a product
bootstrap/migration, durable factory or native/runtime acceptance.
