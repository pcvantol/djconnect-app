# Track Insight: missing musical analysis — 22 October 2026

The owner reports build40448 still shows unavailable musical analysis, empty
energy/danceability/intensity/mood/vibe/texture and an actual genre value.
This is not resolved or accepted by the earlier ordinary-request client fix.

## Read-only source findings

- Apple `DJConnectAppModel.performTrackInsightRefresh` already calls the existing
  server Track Insight route without explicit title/artist catalog hints. The
  current screen requests visual/raw detail and uses the original screen-entry
  completion fence. No new live request or provider/model call was made here.
- Core source inspected at HEAD `103dc6c58862b9ef277fbaa02d59039d5f13eefe`:
  `custom_components/djconnect/track_insight.py`, `_qualified_detail_analysis`,
  intentionally sets energy, danceability, intensity, mood, vibe and texture to
  `None`. `_unmeasured_detail` uses that same empty analysis and marks
  `unmeasured_metadata_only_v1`.
- A genre value may come from actual display metadata independently of musical
  analysis. It does not establish that the audio has been analyzed.
- The current-subject producer contract explicitly retains null numeric audio
  attributes without a qualified source. Exact-recording selector adoption and
  observation-proof/expiry validation remain separate Apple work; they cannot
  create numerical analysis on their own.

These findings identify a source-side gap; they do not establish which response
was served for this particular screenshot or verify the installed Core runtime.

## Authorized Core handoff

Confirm the installed provider path and explain why this recording has no
qualified analysis. Establish the supported musical-analysis source and closed
response contract, including numeric meaning/range, measured versus interpreted
basis, exact recording/version identity and original source/expiry. Preserve
missing-data semantics when unavailable. Return an actual synthetic producer
fixture and qualification evidence for Apple consumer adoption. Do not substitute
seeded values, genre-based estimates or arbitrary model guesses for measurements.

Peter explicitly authorized sharing these findings with the existing Core writer;
the bounded handoff has been sent. Apple will then bind the supported request/response and current recording proof
with cancellation/owner/track-change/expiry regressions. No server source was
changed and no build or installation was performed by this audit.

## Later client adoption checkpoint

The separate current-recording proof and captured reply artwork increment is now in source WIP; see `APPLE_CURRENT_INSIGHT_REPLY_ARTWORK_20261022.md`. It uses independently matched protected Core103dc6 blobs and causal synthetic transport tests. This does not close the missing musical-analysis source or establish a live/installed result for the reported recording.
