# Device-local Apple STT input

Owner request: add “Gebruik Apple STT op dit apparaat” in Settings and override
the Ask DJ microphone route with local recognition, composer insertion and
automatic text submission. Applies to the shared iPhone/iPad/Mac app; the Watch
capture/companion contract is unchanged.

## Implementation

- Default off; boolean stored only in this installation's private UserDefaults.
  It is not added to Profile settings, App Groups, Watch replication or push.
- Both Ask DJ and DJ-session composers already use the same native capture
  entrypoint. The selected route, context, app language and draft are captured
  when recording starts. Permission is requested on the explicit microphone
  action, never by turning the Settings toggle on.
- Apple must advertise `supportsOnDeviceRecognition` for the app's BCP47 locale.
  `SFSpeechURLRecognitionRequest.requiresOnDeviceRecognition` is always true.
  No unsupported-language, permission, timeout or recognition-error fallback to
  HA audio exists. The ordinary HA WAV entrypoint independently refuses audio
  while the option is enabled. Existing HA input remains selected when off.
- Final nonempty text uses the existing draft and text-send operation exactly
  once. Epoch, operation, Session/selected-entry, language and unchanged-draft
  checks prevent stale redirection or overwriting new typing. A route switch,
  navigation cancellation or background cancels pending recognition.
- One native recognition task, a30-second recognition deadline, no transcript
  logging and no audio persistence beyond the existing temporary capture file.
  The file is removed on normal/error/cancel completion. No cloud-STT fallback;
  enabled wake-phrase recognition also requires native on-device support.
- Toggle, explanation and errors have five-language translations. iOS/Mac
  localized Speech permission descriptions now include Ask DJ transcription.

Apple API requirements were checked against
[on-device support](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)
and [required local processing](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition).

## Qualification boundary

Three focused tests pass: private opt-in persistence/independent installation,
exactly one JSON text turn and zero WAV requests (including duplicate-result
rejection), and empty/stale/context/language/edited-draft rejection. These use
synthetic text and an intercepted HTTP fixture, not actual microphone/STT proof.
Localization validation passes for1317keys; diff hygiene passes.

Native signed builds, final full-suite results, device installation and actual
permission/recognition/offline-audio acceptance are recorded separately below as
they complete. A test or compile pass does not establish installed speech quality
or on-device recognition availability for every OS/language combination.

Final full suite: **846 tests /10 suites PASS93.140s**, run without parallel tests.
An initial concurrent run overlapped the native build and failed existing short
wall-clock timer tests; no fixture or product timing was relaxed. The serial
run also passes the new STT regressions. Signed ordinary40338 iOS/Watch/widgets
and Mac builds pass; strict signatures, updated compiled permission purposes,
zero test bundles and163exact source/stage input matches pass.

Ordinary40338 is installed/read back and opened on iPad, MacBook and Mac mini;
previous Mac apps and pairing state are preserved. The setting stays defaultoff
unless the owner explicitly enables it on that device. No iPhone/Watch40338
installation or actual recognition/permission/physical UI acceptance is claimed.
