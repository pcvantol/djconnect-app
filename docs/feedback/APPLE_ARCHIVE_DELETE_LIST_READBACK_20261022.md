# Saved-session deletion list readback — 22 October 2026

The owner reports that deleting a saved Session on Mac returns to an empty
archive list until manual refresh. Source inspection identifies an ordering
failure: deletion invalidation loads the saved-session list and then refreshes
Profile conversation history. A higher server `clear_revision` invokes
`invalidateClearedConversation`/`suspend`, which clears the freshly loaded list
and negotiated deletion flags. No subsequent list read was scheduled.

Both single and snapshot-bound bulk deletion now finish read-only restoration
before loading the list: retire older preparation, prepare against the original
owner, and—only if the admitted clear advances the response epoch—negotiate
again once to restore genuine feature flags. Load remaining saved Sessions last.
Owner, lifecycle and cancellation guards remain; a mutation is never replayed.
Existing invalidation still discards deleted rows and stale reads immediately.

Added a causal regression for single and bulk deletion with increased
`clear_revision`, remaining/new Session visibility, ability to delete again and
exactly one POST. These tests are prepared but NOT RUN under the owner's no-build
instruction. Swift syntax parsing and `git diff --check` PASS only. Installed
40448 is unchanged; native verification awaits the next explicitly requested build.


Validation update, night of22October: the preserved source now compiled and its software regressions ran in the full serial lane suite:1,164tests/24suites PASS121.521s. Log `/private/tmp/djc-apple-night-20261022/full-lane-tests-first.log`. Earlier no-build/unrun statements above describe the earlier checkpoint. This result is not native visual, installed-client, producer qualification or physical acceptance.
