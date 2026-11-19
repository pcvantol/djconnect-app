# Watch Session and native speech — candidate40318,18October2026

Owner request: continue DJ Session presentation including TTS on Watch. Existing
sole writer, branch codex/apple-history-row-play-launch, base075895634feca03b5cc068b45a6fa7bfe781762e;
prior unrelated WIP/recovery copies preserved. Local unpublished implementation,
no installation, source PR, merge or release.

## Visible behavior

Current music remains first on the Watch home screen. The Session section shows
its original start time and current native-admitted DJ Moment with full producer
text, attribution and timestamp. Listen/Stop belongs to that card. Up to eight
other admitted flow cards are behind an explicit watchOS-compatible expand button.
Each can be replayed individually. Source/display expiry and authorization still
control visibility; no local narrative, hidden history or future plan is exposed.
The four selectable presence choices share the same client definition as phone
and Mac. Historical talkative still decodes and is shown as unavailable if selected.

Speech on this Watch opens the actual device-local OS voice/gender/rate/pitch
controls and localized static preview, with native speech OFF by default. It does
not change Profile-owned settings or automatically enable autoplay. Contributions
use only fresh Core-authorized speech, not visible-text or demo fallbacks. There
is deliberately no automatic playback derived from polling/current-card changes.

## Exact producer and consumer boundary

Frozen Core handoff session_speech_local_settings_v1, source-freeze.json SHA256
bc6e080e6561a6892727b8706509a589888be1fff6cc45592fb8cb984cbcf5a0,
was verified locally along with its211source-file hashes before adoption. Normative
SESSION_ON_DEVICE_SPEECH_SETTINGS_V1.md and SYNC_PROMPTS addendum belong to that
freeze. Its unaltered fixture is checked into Tests/Fixtures as
session-speech-local-settings-core-bc6e080e.json, SHA256
813182572537911fe519e487c434b4a5b78a905b19d8d49bb097dfb8715a756b.

Watch snapshot carries compact original revisions/locale/attribution/deadline only
for visible admitted cards. Executable segments, private audio assets and iPhone
credentials are absent. Missing metadata from an older companion permits display
but no speech. An interactive internal companion operation asks the iPhone to
re-read settings/Session using the Watch's own paired identity, compare the exact
visible source, send existing prepare3 with processor local_on_device and target
local, then re-read both owners. No caller voice/rate/pitch/text is sent to prepare;
no speaker dispatch or operation replay. Prepared segments cross only the bounded
interactive reply, never passive applicationContext/transferUserInfo or storage.

Watch checks exact reference/text/presentation/Persona/locale/attribution/settings
fences, processor local_on_device, renderer_pending, no HA voice/audio asset, and
original expiry. Newer prepare deadlines cannot extend the original deadline.
One coordinator fences pending preparation, stop/replacement, old completions,
foreground/owner/policy/settings/source loss, route/voice changes and expiry.
A failure produces a clear per-card retry state without speaking substitute text.
An unavailable HA voice does not block a valid native grant. text_only denies it.

The Core writer subsequently reported the identical frozen private development
candidate installed on HA-dev, with both processors and four presence values.
That is producer-writer readback, not independently verified Apple deployment or
audible acceptance. Broader phone/macOS native contribution integration remains
separate; their existing HA route is not silently replaced by this Watch increment.

## Validation

- Full818tests/10suites PASS90.226seconds, serial, final current source. Seven new
  tests cover all24actual producer output/intent/target matrix rows, real frozen
  live/retained/unavailable-HA grants, exact HTTP shape/local-only target, compact
  bridge/old companion/source withdrawal, malformed/assets/revision/expiry/text-only
  denials, opt-in, stop during preparation, replacement/late completion, owner loss,
  failure without substitution and automatic stop at original expiry.
- Producer fixtures are tested at their original deadlines. Controller race tests
  explicitly retime fixtures into a modeled short future; those are not live grants.
- Ordinary signed iOS40318 build PASS including embedded watchOS40318 and widgets.
  Both app bundles pass strict/deep signature verification. No test bundle embedded.
-276manifest-selected source/stage hashes match. Duplicate recovery files excluded.
  Generated project includes the new shared Watch speech controller.
- Brand/localization validation PASS1282matching keys/five languages.
- git diff --check and work-register identity/count/projection validation PASS.

First native compilation exposed DisclosureGroup being unavailable on watchOS and
presence choices defined only in phone UI; replaced with a native Button expansion
and moved shared presentation choices to client Core. First matrix test incorrectly
treated typed unavailable HTTP200 as a grant; corrected to verify both allow and
deny rows. These failures are not counted as final passes.

## Not qualified

Fresh CoreDevice lists the physical Watch unavailable. No Watch install, native UI
render, audible sound, Bluetooth/speaker route, lock/resume/reconnect or cross-device
settings acceptance is claimed. No physical performance result or product release
follows from these source/build/model tests. Next acceptance uses a reachable
paired Watch and the actual deployed owner routes.

Receipt: [bounded results and276input hashes](APPLE_WATCH_SESSION_TTS_40318_20261018.json).
Private raw logs and clean stage: /private/tmp/djc-watch-session-40318.
