# Contribution input qualification

This isolated iPhone/iPad host renders the production `ContributionContentAction`
with synthetic counters. It never creates AppModel, pairs, sends Ask DJ, opens a
source, changes playback or captures/plays audio. Sibling buttons only increment
a counter. The shipping project has no test flag or test identity.

Prepare with `python3 prepare_native_contribution_tests.py <external-destination>
--jose-checkout <pinned-JOSESwift-checkout> --platform iOS`, then run the generated
`NativeContributionQualification.xcodeproj`, scheme `NativeContribution`, with
an explicitly selected owned simulator and external derived/result paths.
Keep tests serial and use `-collect-test-diagnostics never` on this SDK.

The four native cases cover single-tap dispatch, double/triple/long-press text
selection, dragging, context-menu selection and sibling play/TTS/art/source/avatar
controls, including grouped answer text. They do not qualify the complete paired Session/Ask DJ screens, actual
source-link navigation, VoiceOver, macOS mouse input, research prose or speech.
Synthetic transport/admission/retry cases live in `SessionHistoryContractTests`.
No successful counter or fixture admits a public research source or effect grant.
