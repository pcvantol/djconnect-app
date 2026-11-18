# Track Insight still missing analysis — installed Core diagnosis

User reports data remains unavailable after presentation fixes. This is OPEN;
recent Apple visual/build/install acceptance never qualified analysis delivery.

Actual HA-dev container and host-mounted track_insight.py both SHA256:
a441ff0d1c7956ff23f0845bfcbf245c8cf44d161df141412760a21c0f14e6a1.
Fresh20minute bounded logs:5matchingTrackInsightlines,1request,1result200.
Latest actual iPad screenshots show title/artist/art and explicit unavailable
qualified-analysis text with empty energy/danceability/intensity/mood/vibe.
This is distinct from the resolved HTTP500 issue and from WS routing.

Installed source chain:
- api_handlers.async_handle_track_insight_payload resolves owner and ALWAYS calls
  TrackInsightService.async_analyze with commit_guard=owner_guard.
- Service, when no admitted explicit target, resolves track metadata then sets
  qualified_context={} whenever commit_guard exists. Adds detail_context
  unmeasured-owner-v1 to its cache key.
- Analyzer, when qualified_context=={}, returns _unmeasured_detail immediately,
  before asking the conversation provider.
- _unmeasured_detail delegates to _qualified_detail_analysis, sets
  basis=unmeasured_metadata_only_v1, measured_audio=false, and returns null energy,
  danceability,intensity,mood,vibe,confidence. Production/instrumentation and
  arrangement notes empty. Even qualified credit/interpretation mode explicitly
  leaves these measurements null; credit evidence is not musical measurement.

Pure-function execution of these exact installed helpers confirms all6nullfields:
/private/tmp/djc-track-insight-metadata-only-diagnosis.json. This is source-level
confirmation, not a new authenticated API/provider success. Apple decodes these
optional fields as absent; changing frontend drawing cannot create real values.
Force refresh cannot make a provider run in the short-circuit branch.

Required producer work under existing sole Core writer: diagnose the intended
owner-analysis capability and admitted source/provider, publish canonical
contract/architecture/SYNC_PROMPTS before cross-repo runtime changes, preserve
owner/source guards, qualify real per-track delivery/failure states, and account
for metadata-only responses cached up to24hours when capability is restored.
Do not remove fences or fabricate measurement defaults in Apple. Distinguish
qualified credits, model interpretation and audio measurements. Return explicit
availability/reason and original subject/provenance; joint installed Apple
acceptance must show actual analysis values/text with an admitted source.

Explicit permission to message Core for this new analysis-repair scope requested
through native user input; pending at this document's creation. Earlier grants
for500/widgets/HTTP-WS are not silently expanded. No Core mutation, fake metrics,
new app install or network configuration change performed for this diagnosis.

Cleanup check:1activeApplewriterworktree; merged refs currentlane/main only;
otherrefs and untrackedprojectdirs retained, no eligible stale artifact removed.
