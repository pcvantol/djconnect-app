# Apple adoption of the VibeScape settings fence — 2 November 2026

Owning batch: [Apple PR295](https://github.com/pcvantol/djconnect-app/pull/295).
This adopts the protected Core1424 contract at
`c874b92a08593ea9cd34c113b311e20d2a02177e`, described in
[Core1271's exact handoff](https://github.com/pcvantol/djconnect/issues/1271#issuecomment-6583330629)
and [Apple177](https://github.com/pcvantol/djconnect-app/issues/177#issuecomment-6583332260).
The current contract document, capability declaration and visual runtime source
were compared byte-for-byte with that protected commit and match.

## Consumer behaviour

Before requesting microphone permission or capturing visual speech, the existing
fresh capabilities read must advertise both
`capabilities.vibescape_visual_settings_fence: true` and
`contract_versions.vibescape_visual_settings_fence: 1`. Missing, false, malformed
or future versions refuse the operation. Read-only Help remains usable on the
older visual v1 contract; opening Help does not authorize recording.

`VibeScapeConfirmedSettings` captures the active Session identity, confirmed
persona/value/revision and Mood/value/revision locally. Runtime and its original
Broadcast must agree. Missing revisions, conflicting values or a different
Session cannot admit private voice. This ticket joins the existing original
Profile/owner/epoch/origin, visit, occurrence, scene revision and request-start
lease deadline checks. It is checked across permission, context, capture,
transcription, interpretation, final context revalidation and GPU acknowledgement.
Changing or withdrawing the settings cancels pending voice. Different revisions
prevent a later A→B→A from restoring the old request. Idle occurrence reads also
reject results returned after their captured settings changed.

The seven closed visual v1 DTOs are unchanged. No persona, revision or owner
fields were added to context/interpret/revoke requests. Existing scene-ticket
cancellation still fences newer slider gestures, character-specific Undo and
late voice. The server's original lease/visit/attempt bounds are not extended.
No new endpoint, setting, scene persistence, Ask DJ turn or playback action is
introduced by this adoption.

## Evidence

Evidence directory:
`/Volumes/Shared Data/tmp/pcvantol/apple-suggestions-more-footer-20261102/`.

- `vibescape-settings-core-contract-pin.json`: protected Core contract comparison.
- `vibescape-settings-fence-r1.log`: 47 focused Swift tests pass, including seven
  capability/version scenarios, strict tuple conflicts, persona/Mood ABA,
  original lease, scene/gesture/voice and existing VibeScape regressions.
- `vibescape-settings-full-r1.log`: 1,660 tests in 60 suites pass.
- `validation-vibescape-settings-r1/logs-checks/results.json`: all nine repository
  validation groups pass.
- `vibescape-settings-gpu-r1/`: fresh native macOS offscreen Metal evidence for
  all 48 family/Mood/Dynamics states, twenty **synthetic** occurrence inputs per
  family, twelve motion comparisons, field/contact checks and 240 rapid
  transition frames. Apple M6, 960×640; transition GPU median 9.18ms and p95
  11.21ms. These are GPU command times, not whole-app FPS or thermal acceptance.
- `vibescape-settings-final-inputs-r1.json`: source/test input hashes retained
  for readback after qualification.

The unsigned shipping iOS/iPadOS application and embedded Watch targets also
build (`vibescape-settings-ios-build-r1.log`). `vibescape-settings-native-r2/{iphone,ipad}.xcresult` records six passing
native UI methods on each temporary iPhone/iPad simulator: actual character
controls with accepted/rejected settings, missing-fence refusal before audio
permission, explicit microphone denial, fresh Help, owner/background withdrawal,
and five locales with large text and actual system Reduce Motion. Both owned
simulators were deleted successfully.

The earlier native r1 retained a failing negative-control test: it ran after the
explicit audio-denial test and incorrectly expected an untouched permission
state; its first tap could also only reveal hidden controls. The final harness
runs that negative control first with a fresh test identity and handles the
reveal tap. Production code did not change between these native runs. Synthetic
native qualification remains separate from installed backend, real microphone/
provider and physical mobile acceptance.

## Installed joint tests — awaiting the Core update

A fresh credential-free read of the actual local Home Assistant capabilities
returned HTTP200 with `vibescape_visual_director: true`, but neither the new
settings-fence boolean nor its version. The installed source declaration also
lacks it. Limited readback is retained in
`vibescape-settings-installed-capability-r1.json`; no credentials, Profile,
Session identifiers or personal content are included.

The owner confirmed that Core installation will follow tomorrow. No Core
service deployment/restart or ordinary Apple installation was performed here.
Do not interpret local Core source, a simulator fixture or the old installed
build40454 as matching installed acceptance of this new consumer.

After the owning Core update and the matching reviewed Apple build are active,
the joint run must record their exact identities and freshly advertised fence:

1. Existing Session character control → accepted server revision → correct
   visible world; rapid switching, refused save and late replies must not revive
   an older family. No unintended music, Mood, Presence or normal-chat effect.
2. Actual authorized voice → interpretation → GPU-applied acknowledgement;
   voice then slider, late voice after slider, character changes during capture,
   Undo and Follow DJ. Original deadlines remain fixed.
3. Twenty actual provider playback occurrences including same-item replay;
   retained family, real composition variation and smooth transitions.
4. Physical iPhone/iPad and whole-Mac quality: aspect/rotation/resize, low/mid/high
   Dynamics, accessibility, sustained frame times, thermal and energy behaviour.

Those installed checks and owner visual acceptance remain open. This source
adoption does not close the whole Apple177/Core1271 feature or claim a protected
merge, app publication or device acceptance.
