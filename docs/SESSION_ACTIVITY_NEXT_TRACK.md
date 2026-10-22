# Dynamic Island next-track action

The expanded island places its avatar/title in the leading region, removes the
Spotify logo from that island, and places a white next-track button at the
bottom right. Other widget and Lock Screen attribution is unchanged.

The button uses a foreground `LiveActivityIntent` shared by the iOS app and
widget targets. It opens DJConnect and calls the existing `next` command through
the owning app model. The extension receives no paired credentials and makes no
command request. The intent is not exposed as a discoverable shortcut.

Before dispatch, ActivityKit must still contain that active, unexpired
presentation. The app then waits briefly for normal startup, refreshes the
current Session, checks unchanged owner/epoch and the original local
presentation-to-session binding, and applies the normal runtime/output guards.
Concurrent requests are suppressed. A presentation identifier is not an
authorization grant and cannot create or retarget a session binding.

Validation: signed iPhone build and App Intents metadata extraction in both
targets; matching intent identifiers and foreground mode; native tests for
read-only presentation matching, old-session rejection and invalid/demo action
rejection. A real user tap, cold-launch next-track execution and visual island
alignment remain physical acceptance checks. No next command is sent by the
automated checks.
