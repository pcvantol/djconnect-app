# Current Moment artwork glass tint

Owner requests a subtle album-art-inspired background in the neon-bordered
current DJ bubble, matching the artwork's glass border.

The current-card scope samples the exact displayed cover through the existing
artwork data/tint cache. Its local URL-bound tint is shared with the glass surface
only for the neon current card (including quiet/paused states). Apply a subtle
38-to22percent background wash and22percent native glass tint; preserve the neon
stroke. Clear on cover removal/change and reject canceled/late sampling; do not
reuse a previous cover. Respect Reduce Motion and Reduce Transparency. No backend,
profile, mood or ordinary history-bubble styling change.

40219 signed iOS and Mac builds PASS; strict deep signatures PASS. Installed on
iPhone and iPad; Mac installed when confirmed not running, previous40218 retained.
Native iPhone screenshot collection PASS, but the actual screen was the welcome/
no-active-session surface while HA was unavailable. It does not constitute visual
acceptance of the tinted live card. Do not start a session or change playback just
to manufacture that proof. No new unit tests for this reversible visual-only edit.
