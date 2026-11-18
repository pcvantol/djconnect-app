# VibeCast composition metadata2 — pure parser source slice

This is an internal immutable value and bounded decoder with synthetic tests.
It has no storage, bootstrap, import, allocation, reuse, callback, selection
operation, SDK, HTTP, native-admission seal or product-factory caller. It does
not replace the reviewed child-store schema1 or define a complete persisted
future composition format. No backend wire, endpoint or policy changes.

The owning API narrowed the next source step to this parser/fixture slice in
`apple-vibecast-r3-api-contract-boundary-review-20261024.json`, SHA256
`affc7307e49ddfec3559205eedcfb77d97b47d4895f34cbdab5caa97d95f8c53`.
Its six selected implementation-contract documents on protected API94a2dc6
remain byte-equal to the historical9ab24315pin. Historical primitive reviews
are not approval for whole bootstrap/migration or new native effects.

## Closed metadata shape

The root has exactly `schema_version` (integer2), `context_sha256` (the exact
lowercase hexadecimal32-byte comparison digest), `lock_identity`,
`last_sequence`, `slots`, and optionally `selected_sequence`. Selected omission
means no selected metadata; null is not accepted. Missing/unknown fields and
schema1 reinterpretation fail. There is no `admitted`, `fresh`, grant or reset
field and no method computing initial eligibility.

The lock object has exactly `directory_device`, `directory_inode`, `file_device`,
`file_inode`, `file_birth_seconds` and `file_birth_nanoseconds`. It must equal
the supplied comparison identity, with positive inodes and valid nanoseconds.
No file or OS anchor is opened or authenticated by parsing this object.

`slots` is a fixed object with only keys`0`/`1`; both pending and bound rows
count toward the two-slot maximum. Each row has exactly `kind`, `slot`,
`sequence`, `generation_id` and `purpose`. Its slot index matches its root key;
sequence is nonzero and no greater than the root high-water value. Generation
UUIDs are canonical lowercase and unique. Purpose uses the existing
initial/replacement/rollover enumeration, with at most one initial generation
in this metadata set. This does not verify lifecycle provenance or pacing.

A pending row has kind`pending` and no key or disposition; it cannot be padded
with an invented key. A bound row has kind`bound` and exactly two extra fields:
`key_identifier` (the existing canonical32-byte standard-base64 key grammar)
and `disposition` (selected/candidate/retired). Bound keys and all slot sequences
are unique; at most one bound row is selected and at most one is candidate.
`selected_sequence` must match that exact selected bound row. A pending, retired,
candidate, missing or contradictory selection never satisfies the join.

## Bounded comparison, not authority

Input is capped at4096bytes and uses the existing closed JSON reader unchanged.
It rejects duplicate decoded keys including escaped aliases, arrays, excessive
depth, trailing input, booleans as numbers, null, negative/fractional/exponent/
unsafe integers and overflow. Metadata integers are supported only through
2^53-1; no rounding or wrapping permits a larger value. Rejection exposes only
a fixed typed error, and normal descriptions of values/rows/coordinates are
redacted.

The caller must supply context, lock identity and a minimum sequence comparison;
there is no default minimum. An older record fails the required floor. The
parser retains no floor, writes nothing and proves no durable anti-rollback or
original lifecycle association. Matching caller-provided comparison values
are not proof of their authenticity. Missing/lost original history cannot be
replaced with zero to obtain a native admission. Zero-slot values, including
zero or previously spent high-water metadata, are representable data only;
none of them proves that an installation is unused.

No existing journal, lifecycle, adapter, queue, physical-exclusion implementation,
AppModel, app target or resource is modified or routed through this value. The
future qualified factory still has to join retained original lifecycle and
legacy occupancy, use real physical exclusion, preserve spent reservations and
close on contradictory/missing/uncertain state. It cannot infer permission from
successful decoding or a string key.

## Qualification and following boundaries

Tests are confined to the test target and synthetic metadata. They cover tagged
pending/bound values, both occupied slots, empty/spent metadata, exact selected
references, comparison floors, duplicate keys/generations/sequences, unknown
fields, numeric/size/depth boundaries, canonical keys and redaction. Actual targeted validation passed7test functions, including65parametrized
rejection cases, in0.015s. One complete serial run passed1256Swift Testing
functions/27suites in130.057s and86XCTest cases with5skips/0failures; actual
parentexit0. Original logs are
`/private/tmp/apple-composition-metadata-targeted-20261024.log` and
`/private/tmp/apple-composition-metadata-full-20261024.log`. Work-register and
diff checks pass. Normal independent exact review, candidate CI and own-main
qualification remain required; no pending result is predicted. A private draft
probe is preparation, not qualification of this source commit.

Later slices still need separate concrete schemas, causal tests and review:
original lifecycle spend before pending persistence; crash/uncertain writes;
EVERY legacy writer fenced before import; nonwaiting quiescence; original ACK
activation stages; disposal/slot reuse and stale callbacks. Inserting a future
binding step must occur before the existing final cancellation/owner/QR check
immediately preceding SDK invocation, not after it. Owner loss during that step
must yield zero SDK calls while retaining the original spent reservation.

No whole composition/bootstrap, product wiring, real key, native clock mapping,
provider or physical iPhone/HA/receiver acceptance is claimed by this parser.

## Necessary native project projection repair — 24 October 2026

Protected source196/mainbcbbf6ce98caf35de1a4f8a5f67e02637c9ac7ca
retains the exact API-reviewed parser/tests. Its original native coverage job
120857960485 succeeded with1249Swift Testing functions/26suites and86XCTest
cases/5skips/0failures. That native project did NOT include the seven new parser
test functions, so this is not native coverage of the new parser. The original
log SHA256 is7b37ba4c956df9bf263f02332b42e7c6f2cedda9ad795840951aa9433aa0b2e0.
The separately executed original SPM1256/27PASS remains valid in its own scope.

The canonical project.yml already includes the two source directories. Regenerating
its native project in an isolated tracked-source copy adds exactly12lines: parser
file/build references in all three iOS/Mac/Watch Core targets and the test file
reference/build entry in the existing Mac Core test target. No removed line,
setting, entitlement, scheme, package pin, version or product caller changes.
The parser/test source bytes remain identical. No SDK or factory adoption follows.

This necessary successor must execute the actual expanded native suite and its
own normal CI/protected delivery/original main coverage before reconciliation.
The original196native result is preserved with its exclusion, never relabeled
as having executed the new suite. Separate documentary Finalization follows
the repaired source qualification; no future result is predicted here.

Actual repaired-project local native validation now passed:1342total tests,
1323passed/19skipped/0failed, parentexit0;1256Swift Testing functions/27suites.
The new metadata suite passed0.021s, full Swift Testing122.001s, actual native
duration255.383s, line coverage0.5613642908021763. Parser/test/project input hashes
were identical before and after execution. Original receipt, xcresult, summary
and coverage remain at/private/tmp/apple-composition-native-repair-20261024.
Original test.log SHA256f71c985410ef257d34bca9849810da0aa667b9a56d5f415b410111ff41994303.
This executed result does not predict candidate CI or the successor's own main.
