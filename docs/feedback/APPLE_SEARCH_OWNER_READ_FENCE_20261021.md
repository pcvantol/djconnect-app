# Search owner read fence — 21 October 2026

Successor to `91a779ec0a5c986b544cd8bf1d71941e6dbab2c8`. A new query after owner suspension could dispatch a search GET and repopulate private results. Search now requires a nonempty admitted owner and existing foreground/read readiness before scheduling its debounce or dispatching a page. Response and error acceptance bind that owner alongside the existing epoch/query generation. The existing local Demo branch and backend contracts are unchanged.

## Completed evidence

`sessionHistorySearchRejectsOwnerlessReadUntilRequalified()` uses the actual AppModel/history model, existing `HistoryWireFixture`, and unchanged six retained entries from `session-history-producer-receipt.json`. Its synthetic search envelope follows the existing search regression schema; it is derived fixture data, not a new live producer search receipt or new authored facts.

The completed negative run has **1 failed function /4 issues**: immediate busy state, request count3→4, six re-admitted matches, and accepted query after suspension. The completed corrected run has **4 passed functions /0 failures**, including two parameterized paging cases. The new test proves no extra request, no matches, no accepted query and no busy state without an owner; explicit preparation restores the same admitted IDs. All fixture requests are GET.

The three existing regressions cover stale query/wrong scope, empty-query busy cancellation, and old paging footers/repeated cursors. No unchanged archive/timeline suites were repeated. Both commands completed; no owned job remains or was cancelled.

## Receipts and limits

Private evidence: `/private/tmp/djc-search-owner-fence-20261021/{before-history-model.swift,negative.log,qualified.log}`. Reproduce with the proven private scratch `/private/tmp/djc-native-archive-20261021/mac-native`, `swift test --build-system native --skip-update`, selecting the four function names in the qualified log. The shared scratch binary now represents corrected source; the negative source/log remain preserved. Source and evidence SHA-256 hashes are in the JSON receipt. `git diff --check` passes.

This is shared Apple model qualification on macOS over synthetic HTTP. No new iOS build/runtime, native UI, physical keyboard, VoiceOver, installed HA or server acceptance is claimed. The old full native archive run remains incomplete/unqualified. The default resource-signing cache was left untouched. No simulator, ordinary app, push, PR, outbound report, deployment, SDK/provider effect or recovery bundle occurred.
