# Scoped Ask DJ deletion and archive navigation

Owner report: deleting one Ask DJ question/answer from an earlier Session returned to the Session list.

The confirmed deletion already preserved the archive navigation epoch during its first suspension. The subsequent Profile history read can also increase `clear_revision`. `applyAskDJHistory` then invalidates the conversation a second time; the ordinary suspension changed `archiveResponseEpoch` and cleared `openTarget`, causing the archive view to pop.

The fix preserves archive navigation for that second data invalidation only while reading back a confirmed content-deletion receipt, for the same owner and unchanged archive epoch. It still clears cached content, grants, actions, search and in-flight work. Ordinary conversation clears, owner revocation, lifecycle suspension, representation upgrades and whole-Session deletion retain their existing navigation fences. The scoped readback state ends with the operation.

A synthetic producer readback now increases both history and clear revisions after deletion. Against the previous source this failed exactly the archive-epoch and open-target assertions. The same parameterized regression also covers uncertain outcomes, wrong receipts, conflicts, lifecycle withdrawal and status recovery. This is a causal model/navigation-binding regression, not a physical user acceptance claim.

## Mac icon follow-up, 22 October 2026

Both installed Macs were already version40437 with CFBundleIconFile/CFBundleIconName AppIconAdaptive. The MacBook Dock pointed to /Applications/DJConnect.app and the running executable came from that bundle. Refreshed only that app registration, restarted the MacBook Dock and normally quit/reopened DJConnect. NSRunningApplication.icon was then read from the actual MacBook process and visually inspected: the new black icon with purple headphones. The Mac mini running-process icon was independently inspected and matches. No custom icon override or flattened replacement asset was introduced. A targeted remote Dock screenshot could not be captured (could not create image from rect); direct Dock pixels are not claimed verified.

Validation: 4 focused test functions /17 cases PASS; signed macOS and iOS40438 builds and strict signature checks PASS. The red regression log records exactly the two lost-navigation assertions before the fix. Installation is deferred to the combined search-focus follow-up.
