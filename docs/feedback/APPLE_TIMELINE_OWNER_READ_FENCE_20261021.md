# Timeline owner read fence — 21 October 2026

Successor to `9928aa335a72cf92802a917ed88e1f8e2f57c321`. A completed model regression reproduced a direct timeline read succeeding after owner authority was suspended. `DJConnectSessionHistoryModel.loadTimeline` now requires a nonempty admitted owner at entry and binds that same owner alongside the existing epoch/navigation generation when accepting its response. No authority, producer contract, endpoint, data or Demo path is added.

## Negative and corrected evidence

The new `sessionTimelineRejectsOwnerlessReadUntilRequalified()` uses the actual AppModel/history model and existing `HistoryWireFixture`, with the unchanged six-entry `archived_timeline` and owner-history responses from `session-history-producer-receipt.json`. No fields or retention dates are rewritten; all traffic is synthetic URLProtocol GETs on the existing routes.

Before correction, the complete negative Swift Testing run has **1 failed test /3 issues**: the post-suspension read returned success, requests increased3→4, and a timeline was re-admitted while `authorizedProfileID` remained nil. This is a completed model counterexample, not native-screen or installed/server evidence.

After correction, the complete selected run has **6 passed tests,0 failures**, including the new owner-fence test and five existing regressions:

- Retained windows preserve canonical loaded entries and find the tail.
- Background epoch rejects an in-flight private timeline.
- A newer navigation rejects an older response.
- Newest window survives earlier paging/restore.
- A transient refresh keeps the failure visible until an actual successful read.

The new test proves a suspended owner cannot dispatch a direct read, leaves no cached timeline and makes zero additional requests. Explicit owner preparation restores reading and the same admitted entry IDs. The test also verifies that every fixture request is GET. Existing response-generation/retention handling stays intact.

## Reproduction and limits

Private `/private/tmp/djc-timeline-owner-fence-20261021/`: `before-history-model.swift`, `negative.log`, `qualified.log`. Both commands have terminal results; no job was cancelled or left running. Use the proven private scratch build `/private/tmp/djc-native-archive-20261021/mac-native` with `swift test --build-system native --skip-update`; select the exact six function names shown in the qualified log. The negative source is parent9928aa3 plus the new unchanged regression; the corrected source is hashed in the JSON receipt. The shared scratch executable now represents the corrected code, not an immutable negative binary.

This is shared Apple source/model qualification on macOS over synthetic HTTP. No new native UI, iOS runtime/build, physical, VoiceOver, installed HA or server acceptance is claimed. The old full native archive test remains incomplete/unqualified; none of its assertions are closed by this model run. No unchanged green suites were repeated outside the changed timeline-read coverage.

`git diff --check` passes. Toolchain deprecation warnings are retained and the earlier default Swift Build resource-signing cache was left untouched. No simulator or ordinary app was launched for this slice, and no owned job remains. No push, PR, external report, deployment, provider/SDK operation, physical device or recovery bundle occurred.
