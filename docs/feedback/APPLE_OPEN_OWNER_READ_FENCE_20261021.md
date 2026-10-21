# Saved-session open owner fence — 21 October 2026

Successor to `381a24e44660dd4ce0a58a5144315b9d54272963`. Opening an existing historical action after owner suspension could re-admit the target entry and navigation destination. `DJConnectSessionHistoryModel.open` now requires a nonempty admitted owner at entry and binds that same owner alongside existing epoch/navigation/timeline generations for response and error acceptance. Demo remains on its existing early path. No authority, producer contract or endpoint is added.

## Completed counterexample and correction

The new `sessionHistoryOpenRejectsOwnerlessReadUntilRequalified()` uses the actual AppModel/history model and `HistoryWireFixture`, with unchanged `later_historical_answer`, its existing open action, and `validated_open_target` from `session-history-producer-receipt.json`.

The initial completed negative run has one failed function /4 issues: three owner-fence failures plus an incorrect test assumption that all reads were GET. The existing client uses a read-only navigation POST to `/session/history/open`; the test now permits only GET or that exact POST route. The first source/log is retained. With that corrected route assertion and production still unchanged, the refined completed negative run has **1 failed function /3 issues**: ownerless open succeeds, requests3→4, and navigation/timeline state returns.

After correction the completed selected run has **6 passed functions /0 failures**. The new test proves no request or private state after suspension, followed by successful explicit preparation and reopening of the same admitted target ID. Existing regressions cover a profile change during an open, newer-open versus older-timeline response, periodic read versus explicit navigation, stale search/wrong scope, and authenticated no-store validated navigation. The fixture route assertion permits no commands or other POSTs.

## Reproduction and limits

Private `/private/tmp/djc-open-owner-fence-20261021/`: `before-history-model.swift`, `initial-test-source.swift`, `initial.log`, `negative.log` (same initial result), `negative-refined.log`, `qualified.log`. All three runs completed; no job remains or was cancelled. Reproduce using the proven private Mac scratch `/private/tmp/djc-native-archive-20261021/mac-native` with `swift test --build-system native --skip-update` and the exact function names in the qualified log. SHA-256 source/evidence receipts are in the JSON. The shared scratch now contains corrected source, not a preserved negative executable.

`git diff --check` passes. This is shared Apple model/transport qualification on macOS over synthetic URLProtocol, not native UI, new iOS build/runtime, physical input, VoiceOver, installed HA or server acceptance. The old full native archive result remains incomplete/unqualified. Default build-cache signing metadata was left untouched. No simulator, ordinary app, provider/SDK effect, deployment, push, PR, outbound report or recovery bundle occurred.
