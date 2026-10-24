# VibeCast pending metadata store1 — source accounting only

Internal comparison-only prototype. No root creation, bootstrap, migration,
shared/Keychain instance, adapter, SDK, callback binding, selected child writer,
activation, product factory or backend wire change. Existing lifecycle and
legacy writers are unchanged. This is separate from child-store schema1 and
from the standalone composition metadata2 parser. Decoder success and a
metadataRecorded outcome supply no native admission or fresh-install eligibility.

The owning API's preparation selected slice A, not adapter integration B.
R2 resolved the three design concerns about nesting, exact canonical bytes and
one-shot entry semantics. Those bounded design reviews are not source GO.
Caller UUIDs, digests, floors and snapshots remain comparison data. Actual
reservation provenance, retained restart history and anti-rollback still need
an authenticated lifecycle/storage join in a later reviewed slice B.

## Exact new local encoding1

Root has exactly pending_store_schema (integer1), revision (positive safe integer),
metadata (unchanged schema2) and consumed_associations (slot0/1 object). Each
association has exactly generation_id, purpose and lifecycle_digest. Its UUID
and purpose join the exact pending row; digest is lowercase64hex. Associations
cover all and only pending rows, never bound rows. Pending plus bound occupancy
is at most2. No invented key or selected disposition is attached to pending.

All counters are bounded by2^53-1. The new outer codec is capped at16384bytes.
It validates duplicate decoded aliases and numeric tokens with the unchanged
bounded JSON recognizer BEFORE Foundation projection. It separately feeds only
the metadata subobject to its unchanged4096byte/depth2 decoder. Valid occupied
outer metadata is depth3 overall; global shared reader limits are not raised.

Canonical encoding is exact UTF8 without BOM, whitespace, trailing newline,
escaped ASCII or escaped slash. Values use only their admitted ASCII domains:
existing finite enum, canonical lowercase UUID, lowercase hex and canonical
32byte standard-base64 (literal/,+,=). Numbers are unsigned decimal with no sign,
leading zero, fraction or exponent. The encoder uses these fixed field orders:

- Root: pending_store_schema, revision, metadata, consumed_associations.
- Metadata: schema_version, context_sha256, lock_identity, last_sequence, slots,
  selected_sequence only when present (otherwise omitted, never null).
- Lock: directory_device, directory_inode, file_device, file_inode,
  file_birth_seconds, file_birth_nanoseconds.
- Slot rows, numeric0/1 order: kind, slot, sequence, generation_id, purpose;
  bound-only key_identifier and disposition follow.
- Association rows, numeric0/1 order: generation_id, purpose, lifecycle_digest.

Decode requires originalbytes == exactEncode(fullyCheckedDecodedValue).
Equivalent alternate ordering, escaping or whitespace is refused, never
normalized/repaired in storage. There is no schema1 or metadata2-blob fallback.

## Exact one-shot transitions

Constructor requires an explicit original byte/revision/high-water comparison
and an existing physical exclusion. Nil history is unavailable, never default0.
No production initial-root encoder is exposed. Fixtures explicitly pre-seed
synthetic storage; that is not an install/initial-generation grant.

Fresh refers only to the RAM object's method state. Capture succeeds once from
fresh to captured; busy/read/validation/cancellation failure closes it. Recapture
from any other state closes/refuses. Snapshot binds the original object, exact
bytes, revision and high-water; it is not a lifecycle capability.

EVERY append saves the prior state and sets attempted before any guard or lock.
Only prior==captured plus its exact original snapshot may proceed. A defer closes
all outcomes, including busy/stale/foreign snapshot/cancel/validation failures and
success. Checking the overwritten state or merely matching a snapshot cannot
reopen a closed object. No automatic retry, fresh ID or postterminal capture.

Under nonwaiting physical exclusion, reread exact original bytes, context, lock,
revision, high-water and occupancy. Add only one keyless pending row at a free
fixed slot with checked high-water+1, preserving every existing row and selected
reference. Validate the complete proposed encoding before writing. Advance RAM
floors before the ONE write, require exact readback and recheck cancellation,
including after exclusion's final anchor validation. No await occurs under lock.
Uncertainty gives no successful outcome, refund, cleanup rewrite or reallocation.

Original lifecycle spending remains independent. Lost original floor/history
on restart cannot be inferred from a surviving old root. Supplied old comparison
data is not authenticated by this prototype. Real provenance, every legacy
writer, restart join, ACK/selection/reuse and final no-await SDK guard remain B.

## Executed and remaining qualification

The actual corrected targeted run passed11functions/1suite in0.051s, parentexit0;
source/test hashes matched before and after execution. Tests cover bound row and
selection preservation, two pending slots, CAS/concurrency, canonical/alias/depth
and scalar rejections, counter exhaustion and one-shot terminal outcomes. Seven
injected persistence outcomes use a separately instantiated real lifecycle journal
with synthetic backing; its initial reservation remains spent after restart.
The busy test holds only an owned temporary lock on a separate OS thread; the
Swift test waits cooperatively. No SDK/provider/native admission is exercised.

Original first compile failure (test macro try/noasync wait) and subsequent
visibility compile failure are preserved; a host-blocked retry did not run.
Full serial regression passed1267Swift Testing functions/28suites in138.209s
and86XCTest cases/5skips/0failures, parentexit0. Expanded native execution passed
1353total/1334passed/19skipped/0failed, parentexit0, actual223.261s; its Swift
Testing1267/28passed123.179s. Source/test/project hashes matched before and after
both runs. Original receipts, logs, xcresult, summary and coverage are preserved
in/private/tmp/apple-pending-A-full-20261024 and
/private/tmp/apple-pending-A-native-20261024. The native project adds exactly12
canonical generated references with no setting/scheme/version changes.
Independent exact source review, normal CI/protected merge, original own-main
qualification and separate Final remain required. No future result is predicted; no medium/hardware or whole
VibeCast acceptance follows from these source-accounting fixtures.
