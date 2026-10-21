# Unconfirmed archive deletion — actual native Mac list

Test-only local successor to `1313da5b53e8a63a344ddee7c742bdf87c4fae23`.
New opt-in `nativeArchiveRetainsUnconfirmedDeletionNoticeAcrossReadRefresh` hosts
the actual `SavedSessionsView` and actual model with existing synthetic history
fixtures and the unchanged Core1251 pending503 response. The list envelope is
explicitly derived from the existing archived timeline header, not a new producer
list receipt. No live backend or personal deletion is involved.

Complete 1 PASS/0 failures, 1.724s; incremental build29.65s. Four window-layer
bitmaps inspected: authorized list without notice, unknown operation notice at
430pt, same notice after read refresh430pt, and wrapped notice320pt. Every capture
retains the same archive row, owner profile-a, list_loading=false/preparing=false.
The notice has full Dutch text without ellipsis and says deletion is unconfirmed,
no new delete is sent, refresh only reads history. Visual evidence is not an AX
text assertion or VoiceOver qualification.

Exactly one synthetic POST `/session/history/delete` returns503. All other10
requests are GET; mounting the actual view and explicit ordinary refresh do not
replay the deletion. The persisted journal bytes remain equal and both single/
bulk deletion admission stay blocked. No native button tap, confirmation dialog,
toolbar integration or deletion success is qualified. Inactive offscreen Mac host
does not qualify glass chrome or physical input. This is normal-font Dutch at the
two supplied widths, not arbitrary layout/iOS/whole-root/physical acceptance.

Evidence `/private/tmp/djc-pending-archive-native-20261021/observations/` plus
`/private/tmp/djc-pending-archive-native-20261021.log`; companion JSON hashes all
files and the introducing test source. Run with `DJCONNECT_PENDING_ARCHIVE_NATIVE_DIR`
set to a new output directory and Swift test filter equal to the function name.
No environment variable means the opt-in function is disabled. Native cache reused;
logs retain SwiftPM deprecation, JOSE unhandled Info.plist and missing PCM debug
cache warnings. Build and test nevertheless complete exit0. Windows/defaults close
and own job completes; no simulator/build/install or production change.

Peter's subsequent concrete request for visible per-session trash and individual
Moment/bubble contextmenu/swipe remains implementation work, not implied by this
recorder PASS. Individual contracts still await the qualified owning Core handoff.
