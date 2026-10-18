# Apple on-device TTS — bounded client slice, build 40316

## Scope and source

Direct owner request: “bouw de on device tts slice”. Existing Apple87 selected
scope, including comment6231305768. Existing sole writer and unrelated WIP retained.
Local unpublished candidate on codex/apple-history-row-play-launch, base HEAD
075895634feca03b5cc068b45a6fa7bfe781762e. No new source approval, push, PR or merge.

Settings → Op dit apparaat · Spraak now offers an OFF-by-default Apple TTS
switch, actual installed OS voices and genuine OS gender metadata, rate, pitch,
and a bounded static localized sample. Preferences live in each app installation's
UserDefaults, never in a Profile, Watch bridge or HA pipeline. Personal Voice is
excluded. Missing explicitly selected voices never silently fall back. Five app
languages use the same shared view, including the Watch Settings screen.

The renderer owns one AVSpeechSynthesizer utterance and handles stop, replacement,
voice inventory change, interruption and route change. iPhone/iPad/Mac preview
uses the existing playback coordinator and cancellation fence. Watch preview is
foreground/policy/binding/deadline fenced; its generation prevents an old cancelled
preview from stopping the replacement. All previews require known local output
permission and stop after at most30seconds. text_only and unknown policy produce
zero sample speech. Enabling the override does not enable autoplay or replay old
contributions. Native override suppresses local server synthesis; explicit HA
speaker playback remains independent, including the HA leg of a both request.
Unprepared Watch visible/demo text no longer becomes native speech.

## Core dependency at40316 — superseded for Watch by40318

Fresh local Core source readback: custom_components/djconnect/session_speech.py
lines437–449 recognizes shared versions2/3, then explicitly rejects a processor
other than ha_configured. Version1 is not an authorized workaround on an activated
settings installation. Apple has not invented a new wire format or modeled grant.
DJConnectDeviceSpeechRouting tests the currently permitted routing behavior;
actual DJ text is never passed to Apple synthesis without a delivered contract.

The smallest requested Core delta is a frozen settings-aware local_on_device
prepare path, with the original source/reference, exact text and presentation/persona
revisions, Profile/Session/settings fences, expiry/withdrawal and text_only denial.
Automatic local output must still require client_device/both and autoplay; explicit
local replay may follow the existing policy. No HA synthesis/voice availability
requirement on the local processor; both retains a separately permitted HA leg.
Producer allow/deny fixtures and lifecycle checks must precede Apple adoption.
Core owns SYNC_PROMPTS.md and architecture changes. The owner explicitly approved
the handoff with “Akkoord”. The bounded request was successfully sent to the
existing Core chat “Pak VibeCast shared renderer op”
(01a120e2-b557-76c3-8568-129dbce2f2d2, current host local). Producer delivery
and Apple adoption remain pending; sending the request is not implementation proof.

## Validation and boundaries

Final stable-source validation:

- Full811 Swift tests /10suites PASS90.059s, serial run. Four device-TTS
  regressions include opt-in persistence/isolation, real inventory/missing voice,
  current client/speaker/both/text_only routing, zero duplicate server synthesis,
  separate autoplay and cancellation before preview activation. Mac shared UI/Core
  compiled in this run; this is not a complete native Mac app/runtime qualification.
- Ordinary signed iOS40316 build PASS, including Watch and widget targets.
  Final strict/deep signature check PASS; no embedded .xctest bundle.
- All272 native input-manifest hashes match both the isolated build source and
  current worktree inputs. Generated canonical project adds only native speech
  Core files and shared Settings view, including the Watch source membership.
- Five-language1276-key/brand check, work-register rendering/counts and
  git diff --check PASS.
- Initial sandboxed full run had3issues in two existing host-sensitive tests:
  local Python HTTP fixture could not start and native microphone authorization
  did not match the wake-word test assumption. Repeating with required local
  permissions passed the complete final suite; no permission state or unrelated
  production logic was modified to manufacture PASS.
- Logs: /private/tmp/djc-device-tts-full-qualified.log and
  /private/tmp/djc-device-tts-40316/ios-build-final-qualified.log.
  Signature, exact15-file candidate hashes and executable fingerprint are in
  /private/tmp/djc-device-tts-40316/client-build-receipt.json and
  codesign-verification.txt. This receipt identifies uncommitted local source,
  not a protected delivery or approved SHA.
Local build inputs and manifest: /private/tmp/djc-device-tts-40316/source and
source-manifest.json. SwiftPM clean source excludes the seven duplicate recovery
files; they remain untouched in the worktree. Native output reuses the ordinary
40315 build directory, with prior ordinary app preserved at
/private/tmp/djc-device-tts-40316/ordinary-40315.zip. VibeCast diagnostic test app
is separate and has not been installed as an ordinary build.

No new install, native acoustic acceptance, Bluetooth/Watch hardware run, independent
review or end-to-end DJ-contribution speech claim follows from compilation/tests.
The Core grant is an actual remaining dependency, not a completed feature.


## Continuation: Watch adoption40318

The frozen settings-aware Core handoff bc6e080e is now delivered and consumed for
manual native Watch Session Moment replay. Core's writer additionally reports its
private candidate installed on HA-dev; Apple did not independently qualify that
deployment in this increment. The older blanket contract blocker above describes
40316, not the current Watch consumer. Phone/macOS actual native contribution
integration and physical/audible acceptance remain separate and incomplete.
See [Watch continuation](APPLE_WATCH_SESSION_TTS_40318_20261018.md).
