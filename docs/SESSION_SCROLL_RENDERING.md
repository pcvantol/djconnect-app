# Session scroll rendering

Flow and Forecast share one scroll host. Their moving content cards use stable
native ultra-thin frosted material rather than individual live Liquid Glass
refraction surfaces. The scrolling subtree also skips the shared
GlassEffectContainer. Native toolbar, popover and button glass remain live.
This policy is constant during a visit: dragging does not switch material
branches or recreate the scroll content. Existing outlines, artwork/mood tints,
Reduce Transparency and the user's disabled-glass opaque fallback are retained.
Other screens, including Track Insight, keep their existing glass treatment.

Historical artwork expiry dates are prepared alongside retention dates in the
existing entry cache. Unchanged entries no longer reparse artwork expiry dates
on every screen evaluation. Same-ID replacements, epoch changes and exact
retention expiry continue through the existing cache validation.

Validation uses the native opaque-fallback tests in both scrolling and ordinary
contexts, Forecast field materialization/top alignment, the single-scroll-host
check, and existing stable-row/expiry/replacement/context tests. Preview 40430
is an owner test build. These checks do not establish physical iPhone frame
rate, hitch reduction, thermal behavior or visual acceptance.

Exploratory native probes of non-observable search geometry and custom reading
position bindings did not demonstrate fewer page-body evaluations in the
isolated host (both control and candidate were zero during 24 scroll steps).
Those speculative changes were removed. No percentage speedup is claimed.
