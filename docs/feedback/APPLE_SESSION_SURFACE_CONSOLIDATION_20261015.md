# Apple Session surface consolidation — local neutral foundation

User request: replace widgets, Live Activities and Dynamic Island with one
active-DJ-Session system. Artwork/current DJ Moment are primary; larger surfaces
also show track/artist/album and change when a newly admitted contribution arrives.
The full request remains **OPEN**. This change is not the rich-content delivery.

## Authority and implementation

Existing Apple sole writer: build/apple-40017-recovery/source,
branch codex/apple-dj-presence-v1. No second writer or protected publication.

DJConnectSessionSurfaceSnapshot is one bounded, neutral runtime projection for
all passive consumers. It contains observation/expiry dates and, after the user's
follow-up, an optional closed UI palette token: no Moment,
private question, history, track metadata, provider URL, Profile ID, image bytes,
credential or executable action. Active status requires a confirmed authorized
non-Demo active Session. Playback pause does not infer Session end. Local repaint,
playback tick or widget read cannot extend an existing observation's lifetime.
The local 120-second neutral freshness ceiling is not a source/media rights grant.

The app observes Session changes and updates its own transient App Group state.
WidgetKit receives an explicit neutral entry at the original freshness deadline.
ActivityKit uses Session presentation identity instead of the old fixed
playback-only identity. Superseded/end updates are serialized; a random local
presentation marker prevents automatic recreation after dismissal. Device-private
Session-to-presentation bookkeeping remains outside the App Group projection.
Cold paired startup waits for a Session observation before ending a recoverable
Session Activity. System stale Activity rendering is neutral, not a freshness claim.

A single iOS/macOS provider/view and one Activity/Island state replace the old
NowPlaying/Queue/Insight/last-chat presentation logic. Configured legacy widget
identifiers remain compatibility aliases to that provider; this does not claim
that old gallery entries are hidden by the OS. Existing explicit feature links
retain their original meanings. New djconnect://dj-session only navigates to the
Session page; it never starts a Session/music/microphone or sends chat.

Watch complications now consume the same Core neutral snapshot type instead of
five independent unqualified rich-cache shapes. Watch has a separate App Group
container and no qualified Session producer in this change, so its fallback is
neutral app launch. No phone snapshot replication, Watch Session redesign or
physical Watch delivery is claimed.

Migration removes only five owned retired transient widget snapshot keys.
Chat/history, user preferences, pairing and mood settings are retained. Demo,
monkey tests and --uitesting cannot publish into the installed shared container.
The old DTOs remain solely for compatibility/migration and existing callers/tests;
no active client rich-widget publication path uses them.

## Producer dependency and authorized handoff

Read Core docs/product/APPLE_SESSION_NATIVE_SURFACES_V1.md: owner no-store native
Moment/artwork display is explicitly not a passive cache/locked-display grant.
No client code may convert native_delivery or Session media into such permission.
No speculative surface wire decoder or locally generated DJ contribution added.

Before consumer changes, the two required Core documentation entries were added:
SYNC_PROMPTS.md and docs/product/APPLE_SESSION_NATIVE_SURFACES_V1.md,
2026-10-15 consolidation follow-up sections. They supersede the earlier legacy
KEEP experience decision for this user request, but do not qualify a producer.
They were handed to the existing Core writer as uncommitted documentation only;
Core speech WIP and implementation remain under that writer's authority.

User explicitly authorized sending the concrete dependency to the existing task
**Pak VibeCast shared renderer op**, thread
01a120e2-b557-76c3-8568-129dbce2f2d2. send_message_to_thread confirmed delivery.
Message asks to register this producer follow-up after valid completion of the
current speech slice, without interrupting it or creating another writer.
Core acknowledged receipt in its current turn and explicitly keeps the dependency
separate from speech. This is not scheduled execution, producer completion or publication.

Required next delivery: exact producer contract/fixture/pin for purpose-specific
Moment/metadata/artwork passive display, OS snapshot/cache and locked-display
rights, subject/generation/revision binding, provenance/attribution, immutable
source/display deadlines, supersession/revocation/end; then Apple typed adoption,
rich layouts, migration and native acceptance. ActivityKit background updates need
their own token-family/route/consent qualification; ordinary notification APNs
registration and foreground redraws are insufficient. OS refresh budgets apply.

## Evidence boundary

Candidate build40082 is local validation only. No installation, device refresh,
source push, PR, CI dispatch, protected merge or publication for this foundation.
Do not install this incomplete neutral replacement as if it delivered the user's
requested artwork and DJ Moment experience.

Initial seven focused tests passed; signed iOS/macOS builds passed. Final build,
Watch compilation and expanded language regression results are recorded separately
in the receipt below. No native widget/Island visual, physical-device, suspended
Moment push, background timing or cross-device acceptance is inferred.


## Final local validation receipt

- Eight executed focused tests PASS: Session/authorization/Demo gating, strict
  non-sliding expiry and malformed cache refusal, legacy-only cache migration,
  deterministic deduplicated writes, explicit navigation with old links preserved,
  dismissal identity across app restart/successor/end, and five-language copy.
  Log: /private/tmp/djc-session-surface-40082-tests-final.log.
- iOS build40082 including Watch application/complications PASS:
  /private/tmp/djc-session-surface-40082-ios-final-build.log.
- macOS build40082 PASS:
  /private/tmp/djc-session-surface-40082-mac-final-build.log.
- codesign --verify --deep --strict PASS on both signed app bundles using the
  ordinary host truststore. The sandbox-only check could not read certificate
  trust and returned CSSMERR_TP_NOT_TRUSTED; permitted host verification returned0
  for both without changing keys/certificates/settings.
- All16 changed app/Core/UI/translation inputs match the existing isolated build
  snapshot. This is changed-input equality, not a claim that every unrelated WIP
  or queued foundation in the writer was imported into that snapshot.
- No native widget/Island visual or hardware/background acceptance. No install,
  source push, publication or completion of the full artwork/Moment request.

Durable metadata and hashes: APPLE_SESSION_SURFACE_40082_RECEIPT.json.
