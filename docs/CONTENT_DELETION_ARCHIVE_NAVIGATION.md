# Scoped Ask DJ deletion and archive navigation

Owner report: deleting one Ask DJ question/answer from an earlier Session returned to the Session list.

The confirmed deletion already preserved the archive navigation epoch during its first suspension. The subsequent Profile history read can also increase `clear_revision`. `applyAskDJHistory` then invalidates the conversation a second time; the ordinary suspension changed `archiveResponseEpoch` and cleared `openTarget`, causing the archive view to pop.

The fix preserves archive navigation for that second data invalidation only while reading back a confirmed content-deletion receipt, for the same owner and unchanged archive epoch. It still clears cached content, grants, actions, search and in-flight work. Ordinary conversation clears, owner revocation, lifecycle suspension, representation upgrades and whole-Session deletion retain their existing navigation fences. The scoped readback state ends with the operation.

A synthetic producer readback now increases both history and clear revisions after deletion. Against the previous source this failed exactly the archive-epoch and open-target assertions. The same parameterized regression also covers uncertain outcomes, wrong receipts, conflicts, lifecycle withdrawal and status recovery. This is a causal model/navigation-binding regression, not a physical user acceptance claim.

## Mac icon follow-up, 22 October 2026

Both installed Macs were already version40437 with CFBundleIconFile/CFBundleIconName AppIconAdaptive. The MacBook Dock pointed to /Applications/DJConnect.app and the running executable came from that bundle. Refreshed only that app registration, restarted the MacBook Dock and normally quit/reopened DJConnect. NSRunningApplication.icon was then read from the actual MacBook process and visually inspected: the new black icon with purple headphones. The Mac mini running-process icon was independently inspected and matches. No custom icon override or flattened replacement asset was introduced. A targeted remote Dock screenshot could not be captured (could not create image from rect); direct Dock pixels are not claimed verified.

Validation: 4 focused test functions /17 cases PASS; signed macOS and iOS40438 builds and strict signature checks PASS. The red regression log records exactly the two lost-navigation assertions before the fix. Installation is deferred to the combined search-focus follow-up.

Delivery: 40439 installed/read back on Mac mini and MacBook with matching UI SHA256 e2218c764ca061ee43f6b9653b47687e34549dbb216ff1e260db0e5ac376e523; both running. iPhone installed/read back40439, launch blocked by device lock. iPad unavailable, not updated. Implementation source02f541b1e8c3f021984fda51e9c5aa1c30a4adb7. Physical user acceptance remains open.

## Dismiss a revealed swipe action

Owner screenshot22October: a contribution remains shifted left with its trash action visible. A tap anywhere else on that window must animate the contribution back.

A transparent native observation view is mounted behind the revealed trash button only. iOS/iPadOS listens for completed taps on the containing window, excluding the actual trash-button bounds, with cancelsTouchesInView=false and simultaneous recognition. macOS observes same-window clicks without consuming their events. Both routes close the row with a0.2second animation; native observers detach when the action or row disappears. There is no observer for closed rows and no full-screen hit-testing overlay. Actual deletion still uses the existing prepare/confirmation path.

A native macOS coordinate regression checks an inside-trash click, a tap elsewhere on the page, another window, transparent hit testing and removal of the row. This does not qualify physical iPad tap behavior.

Swipe-dismiss validation: native window-coordinate regressionPASS; signed macOS/iOS40440 builds and strict signaturesPASS. Device installation/readback follows separately.

Swipe-dismiss delivery: 40440 installed/read back on iPad, iPhone, Mac mini and MacBook. iPad launched; both Mac processes running and UI hashes match the signed build ea6be008ae26f6bbc41a9ac7a57cf56deb6a63e1e426f222d06b08f312d216fd. Source27427e81f3a97fcf88eb3c3190c4e8e38c6639ec. Includes prior40439 search-focus and content-clear navigation fixes. Physical iPad swipe/tap acceptance remains separate.

## Long press on iPhone/iPad

Direct owner request: contribution deletion must also be available through long press plus haptic feedback. The existing native context menu already exposes the same guarded destructive action. Its interaction content shape now includes the full card, including empty glass areas. A simultaneous iOS long-press recognizer (0.5seconds, maximum movement10points) requests selection haptics only for an enabled deletion target. It does not submit deletion; the native menu and existing prepare/confirmation path retain ownership. Horizontal swipe remains available. Native hardware determines whether haptic output is supported.

No new implementation-mirroring unit test for this small gesture/hit-target refinement. Signed iOS/macOS build verification and device installation are recorded separately; physical long-press/menu/haptic acceptance is not inferred from compilation.

Long-press validation: signed iOS/macOS40441 builds and strict signaturesPASS. No physical menu/haptic acceptance claimed.
