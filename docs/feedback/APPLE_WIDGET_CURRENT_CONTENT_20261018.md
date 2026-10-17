# Current music and latest Moment in Session widget

Owner requests current artwork/track information and the last DJMoment instead
of the neutral Open Session widget. Same Apple writer; no backend mutations.

Actual iPhone40303 shared-group cache readback at2026-10-17T21:59Z:
widget passive projection active, as_of21:59:24.771223Z,
observed_at21:59:22.013763Z, expires_at22:01:22.013763Z; now_playing present,
contribution absent, artwork count0. These are actual delivered fields, not a
claim about the exact screenshot time. No bearer/grant/track text is published.
Private diagnostic copies remain in `/private/tmp/djc-widget-current-diagnosis`.
HA-dev public capability confirms passivev1, maximum120seconds,
background_delivery=false and read_side_effects=false.

Existing Apple renewal is bounded to60seconds while foreground coordination
runs. Initial suspicion of missing same-track renewal was not established;
no transport/cache lifetime workaround was introduced. Backend grants, source
admission, field deadlines and OS scheduling still control rendered content.

Presentation fix40304: current music appears first with its independently
qualified cover; large artwork increases72->104pt. Small widgets no longer omit
the track when a contribution exists. Latest admitted contribution follows music,
using two lines in the small combined layout. Complete source text remains the
accessibility label; attribution and uncropped artwork remain. The shared renderer
also orders playback before contribution in Live Activity content.

Swift parse, diff and native signed iOS40304 build PASS; strict deep signature
and ordinary-product checks PASS. iPhone install succeeded; independent installed
version readback40304 and normal launch requested. No physical widget layout
acceptance or new full-suite PASS is claimed. iPad/Mac unchanged per installation
scope.

Owner explicitly authorized forwarding this widget finding and requesting repair
in the existing Core chat; message successfully delivered to thread
01a120e2-b557-76c3-8568-129dbce2f2d2. Backend current-cover preparation/purpose
admission, latest eligible Moment projection, and any background delivery contract
remain OPEN pending Core evidence. Never export foreground owner artwork/Moments,
revive expired facts, manufacture passive rights or renew deadlines on read.

Build log: `/private/tmp/djc-widget-40304-ios-build.log`.
