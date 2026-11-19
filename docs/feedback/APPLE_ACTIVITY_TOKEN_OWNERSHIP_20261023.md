# Live Activity token ownership — 23 October 2026

This bounded client correction prevents an old ActivityKit token observer from
overwriting its successor's pending token. A callback must match the current
local presentation, the exact requested native Activity ID, and an undismissed
presentation. Replacement within the same presentation is also fenced. The
controller records native ownership before observing an immediately available
token; it does not depend on the asynchronous stream emitting that token again.

The causal regression reproduces six failed assertions with the former
unconditional store. With the guard, all 42 selected Session/Activity regressions
pass. They cover cross-session replacement, token rotation, same-presentation
native replacement, late withdrawal, dismissal and local Session end. Temporary
test defaults contain synthetic tokens only. The first command used an
unsupported SwiftPM flag; the next build hit resource-fork codesigning on the
source volume. Both failures are retained; the actual causal run and successful
rerun use the existing isolated temporary build directory.

This is pending-token custody, not server registration or push delivery. On the
personally checked API source, admitted Activity profiles remain empty and the
dispatch gate is false. Core confirms that its context/purpose adoption is
widget-only. The separately proposed remote ContentState still needs canonical
provider attribution/export rights, original display expiry semantics, and an
Activity-specific original purpose/context before a shipping registration
factory can use it. The local rich snapshot and receiving-device uptime are
not a remote profile. No provider key, runtime gate, token export, deployment,
installation, remote start, or actual APNs receipt is established by this change.
