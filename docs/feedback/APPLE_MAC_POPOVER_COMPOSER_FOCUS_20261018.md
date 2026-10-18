# Mac popover mouse dismissal and composer geometry — 2026-10-18

Request: closing a toolbar popover with the mouse must not increase the chat input bar height.

Code diagnosis: AskDJInputBar previously derived its expanded VStack/two-to-four-line layout directly from SwiftUI FocusState. Native popover first-responder restoration can focus the field again after an outside click, which was indistinguishable from deliberate editing. The event monitor cleared native focus, but had no separate editing intent; later restoration could re-expand the bar.

Fix: keep Mac editing intent separate from native focus. A mouse event inside the editor, a real focused text edit, or the explicit caret request establishes editing intent. Every outside mouse event clears intent, including clicks in the popover window. Restored focus and same-value binding writes do not establish intent. Expansion now requires both focus and intent. Existing native editor identity, selection, unsent draft, Return/Ctrl-Return behavior and iOS path are preserved.

The existing paired Mac presence UI regression now measures compact composer height and Y after three native mouse open/dismiss cycles. UI test syntax parsing passed; the native interactive UI scenario has not been executed in this change. No physical reproduction/fix acceptance or installed-build claim.

Qualification: final native Swift compilation passed; 47 focused profile/artwork tests passed sequentially in 5.679 seconds. Log: /private/tmp/djc-mac-composer-focus-tests-final.log. git diff --check passed. Native UI regression syntax parsed; interactive test not run. No new app installed.

Subsequent combined installation: iPhone build40313 includes these source changes; native build/signature/install/readback passed. Launch was blocked because the phone was locked. MacBook remains40312; no new physical acceptance. See APPLE_ARTWORK_GESTURE_OVERLAY_40313_20261018.md. Server dosing remains separately qualified/installed by Core.
