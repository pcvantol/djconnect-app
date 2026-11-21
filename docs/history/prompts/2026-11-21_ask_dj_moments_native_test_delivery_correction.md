# Ask DJ Moments native test delivery correction

Bounded supplemental QA source from qualified main `83e2f03822deac1c52cc1dbedd8623d4a0e09b06` (Source #400). Final #401 at `6357882ecf70d9b85531ae9a316cfbd65a1a7fc1` and failed CI `44804481699` remain preserved. This separate correction changes only the introduced native test oracle; the separate Final stays documentary.

The old fixed grace could expire before the native failure-dependent double-click callback under MainActor load. An external instrumented reproduction with a 400 ms stall observed `opens=0, jokes=[]` at the old deadline, followed by the correct playful callback 81 microseconds later. The original CI callback was not instrumented; this reproduction explains the same observable failure without claiming its precise scheduling trace.

The test now awaits the actual expected action for at most three seconds and then observes a complete `NSEvent.doubleClickInterval + 100 ms` window for late duplicates/cascades. Photo and source clicks each retain their own sequential delivery and full observation window. Physical event sequences, exact single/double/triple results, zero avatar actions from photo/source controls, hit-region and single-mount assertions are unchanged. No runtime source, project, package, fixture or provider behavior changes.

Fresh native focused test: 1 passed in 7.404 seconds. Same exact build full parallel suite: 1784 tests in 61 suites passed in 31.779 seconds. The external controlled-stall harness passed all 18 original conditions after the full observation windows. Canonical non-mutating host verification: MATCH, exit 0, onboarding 4.5.13. An initial attempt with the previous external scratch cache could not spawn the expired Metal cryptex path; its log is retained. The current healthy xcrun-resolved toolchain and a fresh task-local external scratch completed normally. No host repair was performed.

Local evidence is supporting evidence. This corrective PR still needs independent exact-head review, normal protected CI/merge and its own main/internal-publication qualification. Source #400 historical qualification remains unchanged. Governance Final #401 must inherit this correction from its qualified base, preserve prior receipts and remain governance-only. Real-model/editorial and physical installed/audible/accessibility acceptance AM12 stays OPEN; TDE policy failure stays open. No installation or deployment is included. Original failures, historical checkout, installed build 40530/recovery and HA backup are preserved.

Artifact digests (private external evidence, not embedded personal data):

- `native-oracle-repair-sequential-focused-fresh.log`: `350fdd340ab977c72bea5a7c0c9dde19320f74dc2a0fcb1f8107db74283b7afe`
- `native-oracle-repair-sequential-full.log`: `f4e7b285eb3a66fe901d2fb939796a0647bbb22a85dcbab30ac8d5f5c944f597`
- `native-input-sequential-diagnostic.swift`: `b1f7866a9e20003df7871e98584b2b2953d87e23884c1a2e20f003c9bf20fe0a`
- `native-input-sequential-diagnostic-stall.log`: `97ab08e5de8d1fd0dafee65da3658e7cd734e34f730ecaca1763c98079a0f680`
- `host-verify-resume-20261121-canonical.log`: `153f252465a9e24764b8c362d8b12aa3eb5311b8c0e66dcbc79ef22f637d34b2`
- `native-oracle-repair-sequential-focused.log`: `6aad0be9cf15dc991f88d317c9c349f95893199c6d1c28db84e7857e11e13c46`
- `finalization-pr-ci-logs.zip`: `8ea72a4f6e1cf37d9d2143af58aba1caba9395bb65e4ac3eea706fc58959ebf0`
