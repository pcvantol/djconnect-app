# Audit of eight retained Apple branches

Audit base: `5bb8738b11a3c256e7752d3f0708ec1de24ef118` (protected main, PR #274).
Each original head remains retained. Commit reachability and `git cherry` alone
were insufficient because previous deliveries used squash merges. This audit
compared each merge-base patch, current source and a three-way merge simulation.

| Original branch (codex/) | Exact original head | Disposition |
| --- | --- | --- |
| apple-bulletin-client-qualification | 8d5bafd644bbad48bb007e7b57e4e466c239cf7e | Already adopted. All source changes merge with zero source delta; five qualification/document files are byte-identical. The only conflict is newer Core1328/Final1329 tests that main must retain. |
| apple-contextual-help-client | 3feaf46db27055bbac8044ca797316ea51285ae9 | Already adopted and superseded. Original track-expiry revalidation, dismissal and three suggestions remain; main adds the newer anchored composer Help, full catalogue and native tests. Restoring the old popover implementation would regress those changes. |
| apple-live-activity-token-lifecycle-20261023 | 2297089053691eaefcdbe3ae807a07b360f3e52f | Already adopted. Ownership predicate, callback checks and replacement tests exist. Main additionally exports the predicate across modules and notifies nativePushChanged only after successful current-token storage. |
| apple-selected-context-refresh-20261031 | 92abb2fe43293455d68595bfb71300c71715eec1 | Missing. Adopt indexed exact-reference context lookup and deadline-driven repaint, retaining paint-time expiry, fallback precedence and owner withdrawal. Add both original regression tests with current isolated-client resource ownership. |
| apple-session-collapsible-search | 7ac7a8716bdff18d8825ce4c4e55e8f18f29081b | Already adopted and superseded. Flow retains collapsible search with newer focus/position ownership. Horizon search was explicitly removed in #274; do not restore the old Forecast bindings, control or fixtures. |
| apple-status-only-pre-fixture-cleanup-20261026 | 7ad3f92acbb322ea217b0934cea98d769c68f200 | Candidate source and all six contract fixtures already adopted by #217 (abc03e4). Its extra historical private review JSON is not a product change; current generator deliberately admits exactly six contract fixtures. Preserve the old branch/evidence rather than reintroducing a seventh fixture or weakening that guard. |
| apple-websocket-reader-20261031 | bbfd1d74e774a0f2d27585418aef467efd35f56c | Missing. Adopt bounded shared authentication, one socket reader, correlated request IDs, independent cancellation, native wire tests and no mutation replay after uncertain delivery. Keep newer main choice-completion and passive-publication test waits when resolving conflicts. |
| apple-widget-original-read-pin | ea3afc27fecdc789a156c561ccecbf7de7162509 | Already adopted and strengthened. BackgroundSession and feedback document are byte-identical. Main additionally retains field-specific monotonic deadline history across higher-sequence/rollback/ABA frames, plus regression tests. Do not replace it with the older whole-frame deadline logic. |

Only the two missing changes enter this integration. The four later UI PRs
#275-#278 remain separate. No device build/install, enrollment, pairing, push
activation or backend deployment is part of this audit/merge.

Local audit evidence (merge-base patches, merge simulations and exact original
heads): `/Volumes/Shared Data/tmp/pcvantol/apple-eight-branch-audit-20261101`.
Validation and the final protected merge receipt are retained there separately;
historical branch feedback is not new native or provider acceptance.

## Integration validation correction

First integration CI run `41349848192` failed while starting one native wire
fixture: Foundation JSONSerialization reported empty data before the fixture
body ran. The Node fixture previously created the final port-report filename
before writing its JSON; the native start loop could observe that empty file.
Publish a complete closed staging file through an exclusive hard link instead.
The original strict JSON reader, startup timeout, real socket I/O and all
mutation/no-replay assertions remain unchanged. Preserve the failed run logs
alongside the fresh complete validation for the corrected source head.

A separate local full-suite rerun exposed the pre-existing lifecycle fixture
`actualHTTPAndLocalDisconnectRoutesCannotReconfirmFromCachedSessionBookkeeping`:
its original bounded wait failed and a force unwrap then aborted the test process.
Replace only that unwrap with a required snapshot and an explicit synthetic
model-state failure message. Keep the original wait, no-cached-reconfirmation,
expiry equality and newer-observation assertions. The targeted 49-test native
custody/WebSocket run and subsequent complete 1,614-test diagnostic run passed.
This improves failure reporting; it does not claim a product lifecycle fix or
explain away the retained one-off timeout. CI on 8405521 also passed the full
suites and both unsigned platform builds before this reporting-only change.
