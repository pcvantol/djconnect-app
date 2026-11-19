# Mac playback/favorite regression readback — 19 October 2026

The MacBook crash at 15:55:57 remains an intermittent, unresolved root-cause
finding. Its AppKit exception stack contains NSWindow constraint invalidation,
SwiftUI ScrollViewCommitMutation and repeated native layout. It does not name
an application source line. No speculative product fix is claimed.

## Real paired server interaction

The ordinary installed build was 40357, main
98402c71c05e1e4519c42eb39286fdd5fab50baf; pending PR142 was not installed.

- Mac mini: actual artwork clicks paused and resumed the current track; actual
  favorite button actions removed and restored its favorite state. Separate
  authenticated HA status reads confirmed each of the four effects for the
  same track. The client remained responsive. Original playing/favorite state
  was restored; no replacement track was acted on.
- MacBook: the user performed the same artwork pause/resume and favorite
  off/on cycle and confirmed the app remained working. Follow-up readback
  found ordinary PID83313/build40357 alive. At 16:13:19 UTC, the latest crash
  report was still DJConnect-2026-10-19-155557.ips, not a new incident.

Private-free receipts are retained in
build/qualification/live-mac-playback-regression/. This is a successful bounded
real-server cycle on each Mac, not a long soak or proof the original intermittent
crash cannot recur. MacBook acoustic/voice routes are outside this test.

## Separate synthetic native check

An isolated Mac mini app identity, in-memory token store and review_demo fixture
exercised eight native artwork state transitions and eight favorite transitions
without crash/hang. An initial event-driver attempt failed to observe a playback
transition; after explicit foreground/window activation and proper native click
count, the bounded sequence passed. This fixture did not call Home Assistant.
Its result is supplementary UI evidence, not real server qualification.

The isolated MacBook test process launched, but no usable window was exposed to
remote accessibility automation. It was stopped without claiming a native UI
PASS; the subsequent user-operated ordinary-app cycle supplies the MacBook
interaction observation above. Both temporary test processes were stopped.

If a hang recurs, leave the process open for an immediate sample before force
quit; a fresh crash report is required if the app exits by itself.
