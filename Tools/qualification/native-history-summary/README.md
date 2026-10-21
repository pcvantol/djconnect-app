# Native historical-summary component qualification

This opt-in target hosts the actual `SessionHistorySummaryView` on the owned iOS simulator. Checked-in producer fixtures are decoded through `DJConnectSavedSession`; no summary values are synthesized. It uses no AppModel, owner operation, live server or passive/shared projection.

Generate a new disposable project with the existing generator:

```sh
python3 Tools/qualification/vibecast-product/prepare_native_consent_tests.py /private/tmp/NEW-SUMMARY-EVIDENCE --jose-checkout /path/to/pinned/JOSESwift --with-summary
```

The private `NativeSummaryTests` scheme needs TestAction `shouldUseLaunchSchemeArgsEnv=NO` and explicit `DJCONNECT_NATIVE_SUMMARY_DIR=/private/tmp/NEW-SUMMARY-EVIDENCE/observations`. Select `NativeSummaryTests/NativeHistorySummaryTests/actualNativeSummaryRendering()` on the specifically owned simulator. The shipping project/schemes are unchanged. Existing evidence directories must not be overwritten.

The test records native component measurements and UIKit window-layer renders at width390: compact/detail, large accessibility text in Dutch/French, and existing zero/partial/withdrawn/unknown fixture states. Inspect the generated PNGs before asserting visual findings. This component host does not qualify archive navigation, owner admission, physical devices, OS screenshots, scrolling, VoiceOver or actual paired/backend acceptance.

With `--with-summary`, the existing NativeConsentTests target also receives the unchanged final-list summary fixture. The opt-in `actualIOSNativeArchiveSummaryWithdrawal()` (`DJCONNECT_NATIVE_ARCHIVE_DIR`) mounts the actual archive list over the existing synthetic paired-owner bootstrap. Its checked-in report distinguishes native observations from completed model checks and any incomplete Xcode result finalization; do not infer a green native suite from PNG/JSON files alone.
