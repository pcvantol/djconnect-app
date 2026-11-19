# Active Session foreground position

Owner reports iPhone/iPad app-switcher return visibly traversing contribution
bubbles. Existing foreground code reloads a captured row, opens it again, then
uses the animated navigation helper. Active Session resume must instead select
the current header synchronously with animations disabled, before any awaited
read. Old row navigation/restoration remains only for archived Sessions. Cancel
superseded restore/search/paging work on inactivity; foreground reads never issue
a subsequent active-Session navigation. User-initiated search/jump stays separate.
Existing foreground refresh uses the tail window, not the stale bubble anchor.
No backend or durable-history change, no replacement writer.

Implemented immediate nonanimated current-header positioning on active Session
appearance and scene resume, including reset of stale bottom-pagination visibility.
Inactivity cancels prior restoration/paging; background periodic reads are gated.
No active resume anchor-open or post-network jump. Archive resume retains its
validated entry target. Initial top offset is explicit for the native ScrollView.

Validation: shared Mac Swift build PASS; four focused history/foreground race
regressions PASS (`/private/tmp/djc-resume-scroll-tests.log`). New test confirms
active resume ignores an old bubble anchor, reads only tail and never publishes an
open target; archive still requests its anchor. iPhone/iPad build including Watch
PASS (`/private/tmp/djc-resume-scroll-ios-build-final.log`). Diff whitespace clean.
No installation or physical app-switcher smoothness acceptance claimed yet.
