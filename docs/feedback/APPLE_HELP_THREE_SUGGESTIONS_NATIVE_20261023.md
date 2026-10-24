# Contextual Help and three suggestions — native interaction continuation

The existing Apple #128 / PR187 lane is continued from `98c922435b25be6050e5cd64c45ccb05116f6284`, with protected main `7ded7f34a1deb6b35533396c861998756f4cb9c6` merged without rewriting either history. This is client preparation, not producer qualification or an installed release.

Both existing surfaces use the same native Help entry/popover and suggestion-row presentation. Selection, owner/context eligibility, tap-time validation, frozen cursors and the existing Ask DJ send closures remain with their original owners. There is no second command route or locally invented example list. Help now has an explicit close control, using the existing five-language Close string. This fixes the observed iPhone interaction where tapping a label behind the popover did not dismiss it.

The isolated native test uses the actual Core selector with the existing synthetic test catalogue, and the production row/entry/reference components. It verifies exactly three suggestions on each surface, exact chosen text forwarding to a probe label, six grouped reference examples, native popover opening/closing and unchanged suggestion order afterward. It creates no AppModel, pairing, HTTP, command dispatch or audio.

Actual results on 23 October:

- iPhone 17 Pro / iOS27: one interaction test PASS on both Ask DJ and Session. A second run with retained screenshots also PASS; both Dutch popover screenshots were inspected. Contents scroll within the native popover.
- iPad Pro13 / iOS27: the same test products PASS on both surfaces, one test and zero failures. Only the optional post-test `simctl diagnose` child was bounded after two minutes; Xcode finalized with exit0 and a Passed result. The action receipt and original logs are retained.
- The initial outside-label dismissal test genuinely FAILED and remains preserved. It is not relabeled as passing after the explicit close control was added.
- Native Mac sources compile. The unsigned runner hung before connecting; a bounded retry using the existing Apple Development identity failed while enabling automation mode. Neither run supplies Mac UI acceptance. Developer mode was already enabled; no security setting was changed.

The current source also passes 65 filtered Ask DJ software regressions, including the existing catalogue/reference vectors. The default Swift build first failed before running tests because old shared-cache resources had Finder metadata; it is retained as failed. A separate native-build-system scratch directory completed successfully without altering that cache. Catalogue byte comparison and localization validation (1,447 keys in five languages) pass.

Evidence, source hashes and result scopes are recorded in `/Volumes/Shared Data/tmp/pcvantol/apple-contextual-help-client-20261023/native-interaction-continuation-r2-20261023.json`; the earlier receipt remains immutable. Original result bundles and screenshots remain under `/private/tmp/apple-help-interaction-ios-20261023/`; Mac failures are retained under the corresponding `apple-help-interaction-mac-20261023` path.

The shipping catalogue remains byte-equal to Core at `dfaa98a1659ef5673037da26f98136314b314beea8afe8e31af4ffd5bd6ac4e7`, `draft_not_consumer_qualified`, with 70 producer route/locale gates pending. Synthetic UI success cannot promote those flags. Core is separately preparing the newly authorized producer qualification. Its exact published catalogue and capability context must be reviewed and adopted before three real executable suggestions can be advertised. Actual paired capability discovery, server-rendered typed `help`, installed interaction and physical VoiceOver remain separate acceptance requirements. Issue128 remains open.

No ordinary app version bump, physical installation, paid model call, catalogue promotion, push/provider action or backend-contract change was made by this client continuation.
