# History deletion test baseline: necessary qualification repair

Protected documentary PR193 merged095163f as0b621e8. Its original own-main run
40078612032 completed with ordinary CI SUCCESS but native coverage FAILURE.
The actual Swift Testing run recorded1249tests/26suites and two issues in the
`count` argument of `sessionBulkDeletionIsOneSnapshotBoundOperationPreservingActiveFlow`:
the explicit active read returnedfalse while the timeline was already loading.
The original log is retained at
`/private/tmp/apple-final193-main-original-coverage-failure-20261024.log`,
SHA2564f102cd5b14386ff482536e92312ac89c9ad5d67153b0ef86341a763b967d27d.
No failed attempt is relabeled, and PR193's own-main qualification is not PASS.

`loadTimeline` deliberately returnsfalse for an already-owned read. Profile
history preparation can own that read before the test's explicit call. The
previous baseline assumed that awaiting its second call also awaited the original
owner. The log confirms that assumption was false; the production guard is
unchanged.

The corrected fixture first lets preparation settle, then explicitly holds the
next active response. A second read must returnbusyfalse and produce no extra
HTTP request. After releasing the original response, the test requires the
exact active session and revision, no error and no loading before snapshotting
the baseline and attempting deletion. The original deletion acknowledgments,
all11outcomes, snapshot/owner/epoch/count checks, lost-write handling and active
flow equality assertions remain. The five-second monotonic bounds are test
harness timeouts, not product delays, grants or retry behavior.

The first local validation build failed before test execution because an old
generated bundle contained Finder metadata; its original log remains
`/private/tmp/apple-history-baseline-targeted-20261024.log`. No old bundle,
source, pairing, metadata or history was cleared to hide that failure. A fresh
private scratch directory with the same default Swift build engine passed the
11targeted argument cases in0.720s. One full serial run then passed1249Swift
Testing functions/26suites in130.087s and86XCTest cases with5skips/0failures;
actual parentexit0. Original logs:
`/private/tmp/apple-history-baseline-targeted-r2-20261024.log` and
`/private/tmp/apple-history-baseline-full-20261024.log`.

The actual native Mac core coverage run also passed:1335total/1316passed/
19skipped/0failed, parentexit0,217.569s and linecoverage0.5604085973. Original
receipt,xcresult,summary andcoverage remain under
`/private/tmp/apple-history-baseline-native-20261024/`. The executed test source
SHA256 is0191f7ba8c3f4c5ea68f02ee39b8b1e84a4bbb796dc5654b26dc5c893c99d04b;
no test-source edit occurred during either full run. No extra skip or product
change was introduced to obtain the result.
This source slice changes only the test, qualification evidence, the current
VibeCast contract-precedence readback and the separate
[Help simulator receipt](APPLE_HELP_IOS_NATIVE_20261024.json). Product sources,
app targets, contracts, signing and shipped resources remain unchanged.
Normal independent exact review, protected delivery and successor own-main
qualification are still required. This necessary repair does not grant VibeCast,
remote push, native/provider or physical acceptance and does not retroactively
qualify the failed PR193 SHA.
