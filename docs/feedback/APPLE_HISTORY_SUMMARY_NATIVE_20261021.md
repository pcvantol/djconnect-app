# Native historical-summary component qualification — 21 October 2026

Tests/tooling-only successor to `dd67275572e3b7310324bd35f6ecd87f8034d169`. Production source and producer fixture bytes are unchanged. A separate opt-in `NativeSummaryTests` target hosts the actual `SessionHistorySummaryView`, decoding existing producer rows through the actual `DJConnectSavedSession` admission logic. It creates no AppModel, owner operation or network request.

Producer provenance remains Core `ccbb839f4e544b3739c31202685d147207e4c289`; checked-in final-list and summary-states fixture hashes match their provenance manifest. No counts, Mood values or summary facts are invented. The historical detail variant here is the component's noncompact presentation of an admitted list summary, **not** integrated archive-detail route acceptance or a new producer detail-page claim.

## Final results

The complete qualified result has **1 passed, 0 failed, 0 skipped**, no runtime warnings, on owned B62 iOS 27.1. All eight qualified UIKit window-layer renders were inspected at width390 with a 358-point component content width:

- Dutch compact and detail show producer counts2/2 and Energy Mood.
- Dutch/French detail at `DynamicTypeSize.accessibility5` wraps onto multiple lines and displays the complete authored localized labels/values in the final expanded component host.
- Producer zero remains0 with provisional notice; partial8191 appears as Dutch8.191 with the partial qualifier and provisional notice.
- Withdrawn counts display unavailable wording; unknown counts/Mood display unknown, without replacing them with zero.

Measured compact height is80.33 points; detail103.67; largest accessibility detail467 in both tested languages. The final large render windows are531 points tall. These are bounded component-fit measurements and visual findings, not arbitrary viewport/scrolling or whole-screen Dynamic Type acceptance.

The first complete probe also passed1/0/0, but its large render's bottom margin was too tight to exclude clipping confidently. Its historical `final.{log,xcresult}`, `final-summary.json`, `initial-test-source.swift` and `observations/` are preserved as preliminary evidence. The test host was then changed to explicitly exclude safe-area participation for this component and add64 points of render margin. That changed geometry resolves the visual concern and justifies the qualified rerun. No product defect/fix follows from the initial host geometry.

## Reproduction and boundaries

`Tools/qualification/vibecast-product/prepare_native_consent_tests.py --with-summary` adds a separate isolated target/scheme with the new opt-in test source and exact producer resources. Default consent targets, shipping project/schemes and optional UI host source lists are unchanged. See `Tools/qualification/native-history-summary/README.md`. Set private scheme TestAction `shouldUseLaunchSchemeArgsEnv=NO`, explicit `DJCONNECT_NATIVE_SUMMARY_DIR`, and select exactly `NativeSummaryTests/NativeHistorySummaryTests/actualNativeSummaryRendering()`.

Qualified private evidence: `/private/tmp/djc-native-summary-20261021/qualified.{log,xcresult}`, `qualified-summary.json`, `observations-qualified/`, generated project and compiled Core/UI/test products. JSON receipt hashes source, provenance/fixtures and both runs. Renders are native UIKit window-layer renders, not OS screenshots. No VoiceOver/AX reading order, archive navigation, owner withdrawal/admission, integrated list/detail, physical/paired/current-HA acceptance or passive/shared projection is inferred. The summary remains owner-only in production.

`git diff --check` passes. Existing legacy UIKit-host/compiler warnings are retained. No unchanged green suites were repeated. B62 is Shutdown, other simulators untouched, no owned active command remains. No push, PR, external report, ordinary app, physical device, deployment, provider/SDK operation or recovery bundle occurred.
