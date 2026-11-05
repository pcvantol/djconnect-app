# Apple 40475 regression recovery

One bounded recovery PR against release source `3fde5ed34a1b2b787ad2f56a868f0ce55f8c3fd5`.

## Changes

- Watch main navigation uses ordinary left-to-right page ordering: Flow, Horizon,
  VibeScape, More. A leftward finger swipe reveals the next page to the right.
  Without a Session the order is Flow, More. Flow is the leftmost dot.
- Main-page indicators appear during horizontal navigation and fade after
  1.5 seconds of inactivity; Moment readers do not show mode indicators.
- VibeScape Follow DJ resets dynamics to automatic 50% while retaining its
  overlay for the normal three-second inactivity interval.
- WatchConnectivity success/error callbacks explicitly cross the concurrency
  boundary. Data replies use a shared Sendable continuation adapter. Both Watch
  and phone error callbacks are non-actor-isolated; model updates return to
  MainActor. This covers demo text, Next, output selection, settings, snapshots
  and logging, plus the existing HA proxy callback boundary.
- Unscoped Watch demo Ask DJ works without an active companion Session and
  displays the existing localized scripted answer locally. Active demo Session
  questions continue through the phone's shared timeline and bounded snapshot.
- Pairing URL defaults and six-digit prompts use explicit gray text; macOS
  does not apply URL content-type styling to the default hint.
- Shared primary buttons use the same native glass surface as unselected
  Session choices, without the previous painted horizontal gloss band.
- Connection status uses a native toolbar button and anchored UIKit popover
  on iOS/iPadOS; macOS keeps its native SwiftUI popover. The native presenter
  owns the arrow and dismissal, preserving the underlying page.
- App-owned dialogs return to native blocking sheets. The custom full-screen
  centered container and animation suppression are removed. Explicit dialog
  actions dismiss; interactive dismissal is disabled.
- Welcome vinyl music/chat glyphs share the blue-purple icon gradient.
- Discover's Music DNA activation card uses the hero's shared maximum width.

## Evidence and limits

Two independently retrieved physical Watch 40475 crash reports showed the same
utility operation-queue stack through libdispatch isolation checks,
libswift_Concurrency and WatchConnectivity. The archived Watch binary UUID
matches the reports. Crash contents and device identifiers remain outside the
repository.

Validation:

- Swift package: 1,702 tests passed, including new background-success and
  background-failure callback tests invoked from a MainActor caller.
- Existing demo tests cover shared phone queue/playback, repeat/shuffle,
  speaker selection, text idempotency and the common twenty-item Flow window.
- Unsigned iOS (including Watch) and macOS builds passed.
- Localization validation: 1,530 keys passed; independent repository checks passed.
- iPhone simulator: connection status placement and dismissal test passed;
  screenshot visually confirms the toolbar arrow and underlying page.
- iPhone simulator: nested pairing/camera/Music DNA sheet test passed; dialogs
  remain centered within the viewport and explicit dismissal returns to pairing.

This is source/build/simulator evidence. It does not assert installation or
physical-device acceptance of this recovery build, APNs delivery, or Core #1439.
No backend contract, durable Profile intelligence or production deployment is
changed. Music-announcement Moments and For You are subsequent work.
