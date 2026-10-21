# Native HA speech configuration presentation

This isolated iOS XCTest target hosts the actual `HASpeechConfigurationView` with
the real iOS model. A URLProtocol sink blocks and counts accidental HTTP. It never
starts speech capture or synthesis. Model initialization still queries OS status
and activates its existing WatchConnectivity integration; simulator warnings are
retained, and this target does not qualify those integrations.

Generate a **new** private project with the existing pinned JOSESwift checkout:

```sh
python3 Tools/qualification/vibecast-product/prepare_native_consent_tests.py \
  /private/tmp/unique-speech-project \
  --jose-checkout /path/to/pinned/JOSESwift --with-ha-speech
```

Use scheme `NativeSpeechPresentationTests` and select only
`NativeSpeechPresentationTests/NativeSpeechPresentationTests/testActualIOSSpeechConfigurationPresentation`.
Set TestAction `shouldUseLaunchSchemeArgsEnv="NO"` and a test environment variable
`DJCONNECT_IOS_HA_SPEECH_DIR` pointing to a new artifact directory. Without this
variable the recorder skips. Use a dedicated simulator, new log/xcresult paths,
unsigned builds and the existing owned incremental derived-data cache when safe.
The default generator, consent scheme and shipping targets remain unchanged.

Five window-layer renders cover 320pt standard/largest accessible English retry,
720pt English withdrawn speaker, and 320pt largest accessible Dutch/German unknown
states. English producer snapshots remain unchanged; NL/DE intentionally admit no
snapshot. Inspect every render: passing recorder assertions alone do not prove
readable layout. These are isolated component renders, not OS screenshots,
physical device, VoiceOver, full settings page, live HA or audible speech proof.
