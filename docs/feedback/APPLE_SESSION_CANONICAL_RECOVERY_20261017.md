# Canonical contribution recovery, without snapshot-gap banner

Owner asks to remove the updated/incomplete-contributions banner and repair data
loading. The banner incorrectly promotes snapshot_required from the bounded live
event journal into a claim about missing canonical retained history. Reconnect
currently restores Broadcast only; timeline refresh is separate. A transient
loadTimeline error also replaces confirmed rows with an empty error projection.

Remove the banner. Reconnect/snapshot recovery schedules one coalesced canonical
conversation+tail read, with three bounded read attempts and owner/Session/epoch/
foreground cancellation fences. Do not replay mutations or navigate/scroll.
Preserve confirmed retained rows on transient read failure; explicit authority
withdrawal still clears them. Existing timeline error/retry UI remains truthful.
No invented recovery of non-retained events, no backend contract change.

Implemented: remove banner and its stale UI flag; schedule coalesced history
reconciliation on live reconnect and HTTP snapshot recovery. Stop/Session change
cancels the task; original Broadcast/owner generation and history epoch gate late
completion. Canonical reads retry at most three times per task; ordinary visible
refresh remains available afterward. Confirmed retained timeline rows survive a
transient read error; actual authority refusal still withdraws private state.

Validation: shared Swift build PASS; five focused recovery/foreground/authority
regressions PASS (`/private/tmp/djc-contributions-recovery-tests.log`). New test
covers confirmed rows surviving a network error, 503 followed by successful tail
recovery, no open target, GET-only traffic and invalid-profile withdrawal.
Unsigned iPhone/iPad+Watch build PASS
(`/private/tmp/djc-contributions-recovery-ios-build.log`); whitespace check PASS.
No installed-device or full historical retention recovery claim. Source tests do
not establish that the phone's reported interruption has been reproduced live.
