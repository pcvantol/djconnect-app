# Command-F in searchable screens

Queue, Playlists, Saved Sessions and Ask DJ had search controls but no Command-F key equivalent. They now use a shared native hidden-button shortcut, matching the existing Logs approach. Each shortcut opens/focuses its existing search field. It does not toggle an already visible search field closed or clear the query. Existing Queue/Playlist empty-state availability guards are retained. The visible toolbar buttons still toggle search normally; Ask DJ retains composer dismissal on both open and close.

A native offscreen Mac NSWindow/NSHostingView test sends two Command-F NSEvents through performKeyEquivalent(with:). Both events are handled and invoke the callback exactly once each:1PASS/0fail. This tests the actual shared shortcut dispatch; it does not qualify focus on every ordinary application screen or physical keyboard interaction. Per-screen open/focus wiring was source-reviewed.

Shared macOS UI/test compilation and unsigned iOS/iPadOS UI compilation PASS; diff whitespace check PASS. The first concurrent compile was invalidated by a final source edit, and the first completed test compile caught the AppKit Swift argument label. Both were corrected; prior logs remain preserved and are not reported as passes.

No installation, publication, backend contract, network query or playback change occurred. Adjacent JSON binds final build/test receipts.
