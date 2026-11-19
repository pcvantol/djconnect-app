# Widget mood palette

Owner requests mood-linked widget colors. Existing passive Session renderer
already supports active Session palettes, but has no profile/Track Insight
fallback without a Session. Extend only bounded UI styling: active confirmed
Session > explicitly selected standalone Track Insight color > confirmed Profile
Mood > brand. Separate palette cache cannot assert an active Session or carry
Profile/session identifiers, text or artwork. Same 120-second expiry. Refresh on
actual palette changes and existing bounded widget cadence, not progress ticks.
No restoration of retired rich personal widget caches or backend contract change.

Implemented separate closed-color palette cache and fallback timeline deadlines;
active-state admission remains the original Session-only cache. Track Insight
explicit color edits and confirmed Profile reads/edits publish the rendering
palette; Profile epoch changes discard old standalone color projections. Color
changes request immediate WidgetKit reload; sustained observations renew via the
existing 60-second budget cadence. WidgetKit owns actual rendering schedule.

Validation: shared Swift build PASS; 9 Session-surface/palette tests PASS
(/private/tmp/djc-widget-mood-tests.log), including priority, unknown/future/
expired values, minimal serialized keys and no invented active Session. Unsigned
iOS app + widget + Watch build PASS (/private/tmp/djc-widget-mood-ios-build.log).
No installed Home Screen rendering or OS scheduling acceptance claimed.
