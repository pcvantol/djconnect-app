# Apple settings3 adoption design and work record

Assignment DJC-PROFILE-SESSION-SETTINGS-CONSOLIDATION-V1-20261016. Human directly
requested completion2026-10-17. Same sole writer codex/apple-dj-presence-v1, start
cd23fa0708c881f8899b95b44029b2d119683071. Existing untracked project duplicates
and iPad WebSocket notes remain untouched. No scanner work or second writer.

Producer: definitive Core1329ad1ce8bd066d65a08b3988261a44e2cac730, Apple lane
6223987404. Read exact canonical settings/inventory, capabilities and actual
connected-ha-transport fixtures. Historical contract2 sections are not a fallback
interpretation of settings3. No backend contract change is proposed.

## Implementation boundary

- Typed six-field snapshots, options, migration, opaque binding, independent
  defaults/Session revisions and operation receipt; capability version3 required.
- One model/controller and one shared editor (the original Settings-page proposal is superseded by the overflow-only popover below). Only explicit
  accepted owner PATCH changes shared state; no local default upload or optimistic
  confirmed selection. Pending/conflict/uncertain/offline remain distinguishable.
- Stable UUIDv7 operation and exact binding/expected Session; never replay uncertain
  PATCH. Reconcile via original receipt, then fresh read, preserving generation and
  Profile/route/session fences; old receipt cannot overwrite a newer snapshot.
- Reuse existing authenticated client and foreground coordinator. Refresh on entry,
  foreground, paired authority/Session change and existing bounded foreground
  refresh; no new independent timer/controller or unauthenticated/private WS route.
- Shared quick controls route through the same model. Retire active local voice/
  gender and output overrides when shared ownership is negotiated; preserve
  genuinely local autoplay, output volume, permissions, haptics, connection choices
  and existing parked chat/DNA portability controls.
- Retain unavailable saved voice/output visibly; voice/gender choices come from
  producer inventory. Six-field explicit review for legacy unknown Mood; defaults
  are proposed choices, not silently accepted active state.
- Speech prepare3 uses effective shared settings/output and target-bound operations;
  text_only fences all synthesis/replay before preparation and byte/play acceptance.
  Speaker dispatch remains Core-owned; no HA speaker administration in client UI.
- Five languages, adaptive native layout and accessibility. Watch presentation must
  follow the same authoritative state where supported, not add local personal truth.

## Qualification and closure

Use pinned producer fixtures and meaningful client/controller tests for no-Session,
atomic partial changes, two-client invalidation/readback, per-field persistence,
receipt conflict/unknown, ABA/end/background, providerwithdrawal and text_only
fences. Build Mac/iPhone/iPad/Watch. Native render and real installed cross-device
Session/default/HA-restart/audible acceptance remain separate evidence steps.
No source, installed, audible or joint completion is claimed by this design record.
Update this record with actual implementation/validation results and remaining
constraints. Existing publication/signing authority remains unchanged.

Owner steering during implementation: remove the obsolete Settings Connection
card; existing connection popup and About remain the single diagnostic entry.

Native project drift: the checked-in project omitted existing speech/Persona/hybrid
and associated test sources already selected by canonical project.yml. Regenerated
from that unchanged spec; new settings files and required existing transport/speech
components are now registered. Prior project retained in build/recovery. This is
not proof of installed/audible behavior of the previously unregistered sources.

## Owner UI revision 2026-10-17 10:40

The human supersedes the original Settings -> Profile -> Your DJ navigation:
DJ voice is now an overflow-only popover, with no Settings page link. Persona,
Mood and Presence keep their separate shared controls. All six fields still use
one authoritative settings3 controller; this is a presentation change, not local
ownership. Preserve explicit six-value migration review with a read-only summary
of the three independently controlled values.

Popover contains visibly labelled playback and voice preferences, qualified
male/female segmented glass buttons only when advertised by the producer, and
the device-local autoplay switch. Removed reset-to-provider-default button,
scope subtitle, nested purple canvas/card and Settings navigation link. Voice
inventory remains server-owned; no future client-voice toggle is fabricated.
Five-language labels updated. iOS voice presentation uses the same toolbar anchor
and dismissal/owner/session lifecycle as Mood/Presence; macOS presents from its
ellipsis menu. A later owner correction removes the bubble settings affordance entirely; DJ voice opens only from Session ellipsis.

Fixed a controller bug: backgrounding an in-flight PATCH previously invalidated
its generation while leaving phase=saving. Resume now retains the original
operation as uncertain and reconciles its receipt without replay. Malformed
reads now leave loading as unavailable instead of hanging. Seventeen targeted
settings tests pass; full suite: 724 tests in 10 suites pass (86.228s).

Ordinary signed build40237 built for iOS/macOS; deep strict codesign verification
passed and no hosted test bundles remain in either app. Installed version40237
read back on iPhone00008150-001409183C07801C and iPad00008027-000211140231002E;
Mac mini /Applications app version40237, previous ordinary app retained as
recovery. Source remains uncommitted same-writer WIP; no protected delivery claim.

Acceptance limits: first real iPhone UI probe skipped because the active Session
overflow was unavailable. Hosted read-only settings qualification: iPhone read
had no snapshot; Mac app context was unpaired/demo and skipped. Neither is a
cross-device settings PASS. Full per-field cross-device/default/new-Session and
HA restart acceptance and Watch adoption remain open; no settings mutations,
Session termination or HA restart performed by these qualification probes.

Physical DJ-voice follow-up: real iPhone40237 screenshot confirms single glass
popover below the still-visible toolbar, overflow entry, visible playback/voice
labels, hidden unsupported gender, autoplay switch present and no nested purple
card. All layout assertions passed except the probe could not resolve the autoplay switch by its identifier;
screenshot confirms it. A second identifier-only query also failed. The follow-up
probe uses its exposed accessibility label; neither earlier failure is relabelled
as a PASS.
Evidence: /private/tmp/djc-settings-consolidation-private/voice-ui-attachments/
451C91CC-23AC-48A9-895F-3894B0B22973.png. This does not upgrade the failed probe to PASS.

Corrected physical iPhone40238 popover probe PASS: exposed autoplay label,
overflow-only entry, title/field labels, no Persona/Mood/Presence/reset controls,
popover below toolbar and toolbar remains visible. Result bundle:
/private/tmp/djc-settings-consolidation-private/djvoice40238-ui.xcresult.
Full final regression suite728tests PASS. Cross-device/default/Watch acceptance
limits above remain unchanged; presentation acceptance does not close them.

Owner refinement after40238: DJ voice title uses the same centered headline as
other Session popovers. Popover tint/accent/foreground is white. Shared choice
selector now accepts a selection color (default unchanged); DJ voice supplies
white for gender glyphs, selection fill, border and focus. Removed saved-status
copy and manual refresh action. Opening the popover, existing foreground refresh
and post-PATCH authoritative read continue automatically; error/conflict/uncertain
recovery remains available. No new timer or storage behavior. Native40239 builds
and physical layout readback recorded after verification.

Follow-up40239 physical iPhone layout test PASS (13.993s), screenshot confirms
small centered heading, white picker arrows and no refresh/saved-status copy.
Final40240 changes only the autoplay switch's track to neutral gray to preserve
white-thumb contrast. Both native builds PASS, strict deep signature verification
PASS; installed40240 read back on iPhone/iPad and Mac mini. Previous Mac app
retained as recovery. No Profile defaults changed by qualification.

Final40240 physical iPhone popover test PASS14.300s; screenshot visually verified
neutral gray switch track with distinct white thumb, centered headline and white
picker arrows. No saved-status text or refresh button. Evidence:
/private/tmp/djc-settings-consolidation-private/djvoice40240-ui.xcresult.

Owner follow-up40249: Persona and Mood choices keep full brightness while their
write is pending. The shared button style supports retaining its enabled visual
appearance independently of disabled input; only the pending Persona/Mood
selectors opt in. Duplicate-write guards, disabled accessibility/input and
unavailable-state dimming remain. Both iOS Mood presentation paths and the shared
Persona control use this behavior. iOS/macOS native builds and strict deep
signature verification PASS. Ordinary40249 installed on iPhone/iPad and Mac mini;
Mac40248 retained as recovery. No profile settings changed during verification.
This is build/install qualification, not a captured pending-state physical UI test.


Requirement-level readback2026-10-17:
[acceptance matrix](APPLE_REQUIREMENT_ACCEPTANCE_20261017.md).
The implemented six-field controller and bounded popover are functionally
accepted within their recorded scope. Complete legacy retirement, real shared
defaults/two-device lifecycle acceptance, provider/target audible acceptance and
native-device override remain open. No full settingsparent/sourceclosure.


40258 actual-startup correction: settings no longer requires an authorized
conversationhistory projection before its own authenticated settings3 read. Real
40256 iPad showed idle/ownerfalse despite direct valid HTTP200;40258 normal model
read passes0.274s. Shared controller moved into Core for Watch reuse. Task-fence
unit tests cover absent history, Profile/pairingABA and authority withdrawal with
unknown original operation. Installation identity is stable across authoritative
internal/external URL updates.21targeted settings tests and762total regressions
PASS91.023s; signed ordinary iOS/Watch/widgets/macOS builds PASS. Cross-device
complete change/Session-end/restart/HA-restart and real Watch remain open.
