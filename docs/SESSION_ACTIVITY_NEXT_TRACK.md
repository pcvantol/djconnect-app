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

Before sending next, the app withdraws the previous passive card and awaits its
ActivityKit update. After dispatch it performs up to three foreground-only status
and existing-grant reads, with 350/850 ms retry delays, and awaits the resulting
ActivityKit update. This bypasses the ordinary 850 ms command-refresh scheduling
and 15-second passive read throttle. An unchanged previous playback observation
cannot refill the card; cancelled metadata/image work is version-fenced. If the
app backgrounds, the old card stays withdrawn and new reads stop. Owner, Session,
output and presentation checks still fence command dispatch. Observed foreground
track/artist changes also withdraw old passive content and force a fresh read;
these strings are an invalidation hint, never new content or authority.

The expanded Island uses a compact text-only neutral fallback underneath its
existing leading header, avoiding the duplicated full Lock Screen avatar/title
and clipped bottom text. A neutral card means no current authorized rich snapshot
is available. Activity requests currently use `pushType: nil`: suspended iOS apps
do not receive new track metadata through this route. Server-driven ActivityKit
push registration, delivery and revocation need a separately qualified Core/client
contract; foreground refresh is not evidence of background update support.

Validation: signed iPhone build and App Intents metadata extraction in both
targets; matching intent identifiers and foreground mode; native tests for
read-only presentation matching, old-session rejection and invalid/demo action
rejection. A real user tap, cold-launch next-track execution and visual island
alignment remain physical acceptance checks. No next command is sent by the
automated checks.

Refresh regression tests cover immediate background withdrawal without network
reads, forced reads inside the normal throttle, rejection of an unchanged old
observation, admission of the next authorized track without reauthorization, and
cancelled image work not restoring the old card. Actual next/minimize/reopen and
neutral-layout checks still require physical acceptance.
