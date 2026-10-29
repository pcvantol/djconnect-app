# Native status once: internal SQL DATA preparation

This first bounded increment implements an **internal metadata journal only**.
It has no production caller or bootstrap/migration/repair factory, no AppModel
binding, original permission constructor, native ActivityKit/network/key port,
public arbitrary-invoke closure or opened `modelProvider`.

Canonical design basis: Core Source1389
`a3c30619baae0e5ec3c0edfa950e8275d7c076fc`, separate Final1390
`ae08e5d7a9eb798fa860f605d074b94aefd05e75`, design blob SHA256
`96c7f37fe6a965a30e2f8f0f5088f34e156b10495a1d92afac5ebd364f6000b1`.
Both original qualified receipts were received before this source branch.
That delivery permits closed preparation, not positive native admission.

## What this code does

`NativeStatusOnceDataJournal` opens an already initialized private SQLite file,
validates its store ID/schema/capacity and performs actual `BEGIN IMMEDIATE`
reserve/consume transactions. It requests WAL/FULL/fullfsync settings. Positive
dispatch and its separately reserved terminal slot use a shared operation-ID
ledger; kind is not a namespace that permits cross-role UUID reuse. Decision
and presentation metadata remain different typed identities.

All returned ACKs and snapshots are DATA. Process-local reservation sets are
created only after a definitive fresh reserve ACK. Status, a duplicate reserve,
or a new journal instance cannot reconstruct them. Consume attempts are latched
before the transaction; denial/unknown never frees old P1 capacity. Explicit
reply-loss tests return UNKNOWN only after a real SQLite COMMIT. A terminal
slot is reserved at P1 independently of dispatch consumption. Closing the whole
storage-process custody is separate from any future positive-source retirement.

There is no automatic row eviction, operation replacement, expiry refresh or
capacity replenishment. Capacity is an explicit existing-store input, not a
new production policy value. SQLite failure codes are retained where an actual
SQL operation fails; failures are not represented as invalid native proof.

The journal is compiled only for iOS/macOS. Watch has no new store or role.
Existing rich Activity, public Session-v3 task owner, widget handler and every
old-family storage implementation remain unchanged. The private new signed
grammar is not adopted by this local SQL format.

## Fresh disposable tests only

The SQL schema in `Tests/Fixtures/native-status-once-data-test-schema-v1.sql`
is an explicit **test-only bootstrap**, never read or created by product source.
Tests use newly allocated private directories and O_EXCL/NOFOLLOW mode0600
files. Set `TMPDIR` and `DJCONNECT_NATIVE_SQLITE_TEST_ROOT` to a unique external
qualification directory before running local tests:

```sh
swift test --build-system native --scratch-path "$DJC_QUALIFICATION_ROOT/build" \
  --no-parallel --filter NativeStatusOnceDataJournalTests
python3 Tools/qualification/native-status-once/run_crash_probes.py \
  "$DJC_QUALIFICATION_ROOT/new-subprocess-run" --disposable-test-only
```

The opt-in subprocess runner requires a NEW output directory. It compiles the
exact journal source alongside the small metadata helper. Only the explicit
test runner creates disposable schemas. It executes actual child-process exits
before reserve, after committed reserve, after committed dispatch and after
committed terminal accounting, deliberately bypassing Swift/SQLite teardown.
An independent Python SQLite read and a fresh Swift process inspect the result.
The new process cannot turn retained rows into an original process reservation.
All logs, actual exits and receipts stay under the selected external output.

## Limits that remain open

* This is the dispatch/terminal metadata subset, not the complete four-role
  G0/acquisition/assertion lifecycle, a MainActor original native owner or fake-
  SDK dispatch-capability qualification. Twenty design vectors remain separate;
  do not label them all executed from these SQL tests.
* Normal process exits/commit/readback are not power-loss, full VFS-fault,
  nonrollback or original restore/currentness qualification. Path/inode/owner
  checks are hardening, not proof of which original qualified VFS handle an SDK
  transaction may trust. No production provider or bootstrap is selected.
* No original registered principal, signed grammar, purpose/start/display grant,
  original host/clock, finite policy or independent negative authority is
  supplied by an initializer, row, status reply, test owner or valid signature.
* Actual ActivityKit requests, App Attest, native target/proof, APNs, background
  widget read custody, native UI/physical devices and installed acceptance are
  outside this increment. No new release version or app installation follows.

New code still requires its own exact source review, normal protected delivery
and original qualification. This README is not a completion receipt for that
delivery or permission to connect the metadata journal to an active SDK path.
