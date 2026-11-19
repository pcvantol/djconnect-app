# History owner fences — current iOS compilation, 21 October 2026

The clean source at `0a5e57599bd6570fb7bda9043187fd17223a0fc9` completed unsigned **build-for-testing** for a generic iOS Simulator destination, compiling arm64 and x86_64. This closes current-source iOS compilation for the accumulated history list/timeline/search/open owner fences and unavailable archive copy. It adds no production or test-source changes.

The separate project was generated from the existing `prepare_native_consent_tests.py` using the clean shipping JOSESwift pin `c2664a902e75c0426a1d43132bd4babc6fd173d3`. It references the real Core/UI sources and existing isolated consent tests. No shipping project was regenerated or changed.

Command: `xcodebuild -project /private/tmp/djc-history-owner-ios-build-20261021/NativeConsentQualification.xcodeproj -scheme NativeConsentTests -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/djc-history-owner-ios-build-20261021/derived -resultBundlePath /private/tmp/djc-history-owner-ios-build-20261021/build.xcresult CODE_SIGNING_ALLOWED=NO build-for-testing`.

The command exited0 with `TEST BUILD SUCCEEDED`. The result bundle, build log, source hashes, generated project and build products remain in that private directory. The log retains existing qualification-host UIWindow deprecation warnings and skipped AppIntents metadata extraction. There are no compiler errors. No owned build/test/install job remains.

This is compilation evidence only: no test execution, simulator boot, install, ordinary app launch, native tap, physical/VoiceOver/paired HA, SDK/provider or server qualification. The old full native archive and post-correction XCTest UI assertions remain incomplete/unqualified; this build does not close them. Previously green Mac suites were not rerun. No push, PR, external report, deployment or recovery bundle occurred. `git diff --check` passes.

The next independent visual gap is the actual producer detail-summary fixture. The earlier component noncompact rendering used an admitted list summary; `session-history-summary-final-detail.json` has a distinct opaque revision and its own pinned provenance. Existing native component evidence must not be generalized to that detail fixture or integrated owner history.
