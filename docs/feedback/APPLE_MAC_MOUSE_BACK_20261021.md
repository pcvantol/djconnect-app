# Mouse back follows the native page back action

Both navigation destination declarations now attach the shared macOS mouse-back modifier. The visible destination uses its own SwiftUI dismiss action, so the standard mouse-back button (AppKit button3) pops exactly that page. The handler only accepts local events from its own window while the destination is active/visible, ignores other buttons and refuses navigation beneath an attached sheet. Event monitors are removed when the host leaves its window or is dismantled. No root-section history, global mouse hook or Accessibility permission was added.

A native offscreen NSWindow/NSHostingView NavigationStack test pushes First, then Second. The production event-routing handler ignores middle/forward buttons and an unrelated nil window, pops Second to First, then First to root, and leaves no active back handler at root:1PASS/0fail. This exercises native navigation and the actual routing handler; it does not post OS input or qualify physical mouse hardware. The initial Cmd+[ key-equivalent approach failed to pop the native stack and was discarded, with its log preserved.

Shared macOS UI/test compilation, unsigned iOS/iPadOS UI compilation and diff whitespace validation PASS. No ordinary app installation, backend effect or external publication occurred. Adjacent JSON binds logs.
