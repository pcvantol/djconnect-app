# Native archive observation and owner read fence — 21 October 2026

Successor to `1da6158e070566f4ceffeb1ab9befbed721bb4e9`. Production `DJConnectSessionHistoryModel.loadSessions` now requires a nonempty admitted owner at entry and checks that same owner with the existing epoch/generation at response admission. `restoreVisibleSessions` stops after cancelled/ownerless preparation. Demo's existing early path remains unchanged. No authority or backend contract is added.

## Why the fence changed

The new actual `SavedSessionsView` host uses the real iOS AppModel, existing synthetic paired-owner bootstrap and the unchanged Core `ccbb839f` final-list summary fixture via the real GET `/api/djconnect/v1/session/history` decoder. Capabilities explicitly negotiate existing summary version1; no archived IDs, dates, counts or Mood facts are rewritten.

The preliminary run captured an archive row returning after `sessionHistory.suspend()` while the owner was nil. Its complete result is0 passed/1 failed, but the reported failure was the test's premature assumption that preparation had finished. This is not a clean focused red suite for the read fence. It nevertheless records the actual bounded native sequence: list GET1→2 during withdrawal, owner nil, one row re-admitted, summary hidden. The preloaded row's timestamp/duration remained visible.

The refined test removes that prerequisite and explicitly attempts `loadSessions()` after suspension. Native observations again record ownerless row re-admission, GET2→3, but Xcode did not finalize a complete result bundle. The owned PID83776 was stopped with INT then TERM. That incomplete run is neither a qualified failing suite nor a pass. Production source inspection confirms the missing entry-owner guard and the restore path continuing after cancelled preparation; these observations motivated the bounded correction.

## Completed model checks and native limit

On corrected production source, **five existing targeted Mac Swift Testing functions pass**, including paging with three cases, owner denial with two cases, anchor withdrawal and overlapping refresh. A new direct `savedSessionsRejectOwnerlessReadsUntilRequalified()` model test also **passes**: the archive loads with an admitted owner, suspension empties it, an ownerless read returns false without any request, and explicit requalification restores the admitted row. All use synthetic fixtures.

The first Mac invocation failed before test execution because Swift Build code signing rejected resource-bundle metadata in `.build/out`. No cache/source xattrs were cleared. A fresh private scratch path with `--build-system native --skip-update` completed the relevant checks. The new direct test then passed in that same scratch build. Do not count the failed build as a product-test failure.

Corrected native execution produced three inspected UIKit window-layer renders and JSON observations: authorized row with producer2/2/Energy summary → no row/summary with nil owner → same row/summary after explicit requalification. Archive GETs are2→2→3. Session ID/playback assertions are in the recorder. **The corrected native xcresult is incomplete**: Xcode stalled during result finalization and owned PID86434 was stopped with INT then TERM. Consequently no complete native test PASS, global GET-only assertion PASS, native button/AX/physical/VoiceOver or installed HA acceptance is claimed. This is source + completed model tests + bounded native visual/state evidence. Do not repeat the unchanged stalled test runner.

The withdrawn native empty-state copy still says “Geen bewaarde sessies” (no saved sessions), although owner authority is absent. This is a separate presentation follow-up; this commit does not claim that unavailable-state copy is corrected. The restored capture still shows preparation in progress, so it is not a settled-spinner acceptance result.

## Evidence and reproduction

Private `/private/tmp/djc-native-archive-20261021/`: preliminary historical `final.{log,xcresult}`, `initial-summary.json`, `initial-test-source.swift`, `observations/`; refined `negative.{log,xcresult}`, `negative-test-source.swift`, `observations-negative/`; corrected `qualified.{log,xcresult}`, `observations-qualified/`; original `before-history-model.swift`; `mac-regression.log` (environmental build failure), `mac-native-regression.log` (five functions pass), `mac-owner-fence.log` (new test passes), and `mac-native/` build. No complete negative/corrected xcresult summary exists.

Generate a fresh isolated project with `--with-summary`, set private NativeConsentTests TestAction `shouldUseLaunchSchemeArgsEnv=NO`, explicit `DJCONNECT_NATIVE_ARCHIVE_DIR`, and select `NativeConsentTests/DisplayConsentSessionTests/actualIOSNativeArchiveSummaryWithdrawal()`. Its private helper's `summaryArchive` defaults false; existing consent fixture behavior stays unchanged. Shipping schemes are untouched. Native iOS code compiled and executed the correction, but no separate completed unsigned build-for-testing run is claimed.

`git diff --check` passes. B62 is Shutdown, other simulators untouched, all owned commands have returned/stopped. No push, PR, external report, ordinary app, physical device, provider/SDK operation, deployment or recovery bundle occurred.
