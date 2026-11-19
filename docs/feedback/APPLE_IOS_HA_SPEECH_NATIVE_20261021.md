# HA speech status rows adapt to large native text

Local Apple increment based on `cc0d4a173a4fc79d1f73a042041764c3b5d1bb6c`.
The real iOS `HASpeechConfigurationView` kept labels and statuses in two narrow
columns at 320pt with accessibility5 text. All five initial window-layer images
were inspected: words such as “Speech” and “Unknown” broke across several short
lines. The initial recorder completed **1 PASS/0 fail/0 skip**; this visual finding
is not an automated failing text/accessibility assertion.

## Change

The shared HA status row now uses `ViewThatFits`: a full intrinsic-width native
`LabeledContent` when it fits, otherwise a vertical label/status stack with normal
wrapping. Rows align to the leading edge and combine accessibility children.
Status mapping, text keys/translations, admission, retries, permissions, settings
and backend contracts are unchanged. Combined accessibility semantics are source
implementation only; VoiceOver is not qualified.

An optional `--with-ha-speech` generator flag adds a separate
`NativeSpeechPresentationTests` target/scheme and the unchanged checked-in producer
fixture. The default consent project and shipping projects are unchanged. The
component recorder is excluded from shipping and ordinary package tests.

## Completed qualification

The new target uses the real iOS model with unique synthetic defaults/token,
background tasks disabled and a URLProtocol sink that fails every request. It
admits unchanged English producer snapshots through `applyStatusEndpoints`.
Dutch/German unknown samples deliberately have no snapshot; they do not rebind
producer locales or assert translated configured-state acceptance.

| Render | Width | Initial/final host height, pt |
| --- | ---: | ---: |
| EN retry, standard | 320 | 206 / 206 |
| EN retry, accessibility5 | 320 | 1157 / 1173 |
| EN speaker withdrawn, standard | 720 | 167 / 167 |
| NL unknown, accessibility5 | 320 | 887 / 779 |
| DE unknown, accessibility5 | 320 | 1007 / 899 |

All five final UIKit window-layer renders were inspected. Large-text rows now put
the status beneath its full-width label; labels/statuses and retry copy remain
visible without ellipsis. Long words in headers/labels still wrap normally at this
extreme size. Host height is measured content plus 32pt, not a physical viewport or
proof of scrolling the full settings page. 720pt is supplied geometry on the same
iPhone simulator, not a physical iPad claim.

Final iOS xcresult: **1 PASS/0 fail/0 skip, 2.212s**, `TEST SUCCEEDED`/exit0.
Initial xcresult: 1 PASS/0 fail/0 skip, 4.881s. Both summary readbacks completed.
Both record **0 HTTP requests**. This does not imply zero OS framework activity:
real model initialization queries `AVAudioApplication.shared.recordPermission`
and starts its existing WatchConnectivity bridge. Logs retain TCC microphone
identity errors and WCSession interruption warnings from the isolated xctest host;
no audio/permission workflow was invoked by the test. Xcode also logs SDK build
version parsing diagnostics and the qualification UIWindow deprecation warning.
No warning-free, microphone-status or WatchConnectivity acceptance is claimed.

Because production shared layout changed, the native Mac component recorder and
two relevant admission/status functions were rerun: **3 functions PASS/0 fail**
(Mac component 1.296s; two Swift Testing functions 0.108s). All six Mac regression
bitmaps were inspected with full text visible. These are normal-font Mac samples,
not Mac accessibility scaling or active glass-host acceptance.

Generator AST and `git diff --check` pass. Complete default project specs evaluated
from before/after generator source with the same mocked pinned checkout compare
structurally equal; `default-spec-comparison.json` preserves this check.
No unrelated green suite was rerun.
No capture/synthesis, provider request, personal mutation, publication or device
installation. Own B62 simulator was already Shutdown at cleanup; shutdown returned
state405 and the subsequent device readback confirmed Shutdown. Other devices
were untouched. Both builds completed; no test job was cancelled.

## Evidence and remaining gates

Private root `/private/tmp/djc-ios-ha-speech-20261021/` retains initial and final
logs/xcresults/summaries, all five before/after images, original production source,
separate generated project, six Mac regression images/log and observations. The
existing owned derived-data cache was reused; earlier result bundles and projects
were preserved. Companion JSON hashes the source and individual evidence files.
Reproduction: `Tools/qualification/native-speech/README.md`.

This qualifies component rendering under supplied geometry/state only. Full root
settings, arbitrary viewport/scroll/reflow, all locales/states, real permission
flows, glass chrome, VoiceOver, physical iPhone/iPad/Mac, live HA and audible output
remain open. Core individual-deletion/archive-status work is still a local
review-bound candidate, so no unqualified contract was adopted. Independent review,
publication and installation remain separate from this local checkpoint.
