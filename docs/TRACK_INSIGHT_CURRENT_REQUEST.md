# Ordinary Track Insight request — 2026-10-22

The ordinary current-track screen previously sent client title/artist and
playback/player/backend metadata to the existing Track Insight endpoint.
Protected Core c7d6219a9ba1deb427ec436ce4cf132543db9d0f,
`custom_components/djconnect/track_insight.py`, only attempts
`current_knowledge_context` without explicit title/artist claims. A guarded
owner request with these claims can therefore enter the unmeasured fallback
instead of the qualified current-source context. The existing Core writer
independently confirmed this source path; this is not a live request diagnosis.

The ordinary screen now leaves recording selection to the existing server
route. It sends identity, locale, confirmed presentation mood, existing Profile
context and ordinary visual/raw/refresh options. Local playback remains the
screen-entry completion fence. Explicit selected-Moment detail continues to use
its original reference and separate request path.

A causal synthetic transport fixture compares an explicit-title legacy request
with the ordinary screen request. It uses the existing qualified Core producer
fixture to prove that the latter can retain verified credit/interpretation.
Existing track-change/background/cancellation and selected-Moment tests remain
separate regression boundaries. No live Track Insight/model/force call is made
by these tests or this diagnosis.

This does not add audio analysis. Both current qualified-credit and unmeasured
producer paths intentionally return nil energy, danceability and intensity.
Meaningful numeric analysis, the VibeScape numeric qualification gate and actual
recording-specific content availability remain separate Core work. No fake
values, metadata-derived measurements or UI-only success claim are introduced.
The additive closed current-subject selector, exact-URI DTO/proof and original
observation-lifetime consumer adoption are not implemented by this legacy
ordinary-route correction; their requirements remain in the Core current-subject
contract. Physical/native content acceptance still requires its own readback.
