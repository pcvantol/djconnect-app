# Populated native Flow position probe — 21 October 2026

**Nonzero position qualification: INCONCLUSIVE_NATIVE_WHEEL_INPUT.** Tests-only work based on `7ee60b65f337a284838b8d24331af5a6b8ea8bcc`; production sources are unchanged.

## Admitted data and native rendering

The opt-in `DJCONNECT_POPULATED_FLOW_DIR` uses the pinned `session-history-retention-bases-v2.json` tail fixture (SHA256 `da5d8674dc49adb1cc0fabcca51d4f8b730d31f1179462160d1f68aa97e19b14`). Its four authored synthetic retained contributions and two receipt-only rows retain their entry IDs, text, provenance and retention metadata. Only the synthetic Session ID is rebound to the existing test runtime.

The fixture keeps conversation contract version 1 and separately advertises `session_history_entries: 2`, as the existing negotiation contract requires. The real `session/history/{id}` GET is checked for `history_contract_version=2` and `limit=20`. The qualified tail envelope serves `window=tail`. For the screen's ordinary prefetch, a local envelope is derived from those same six rows by removing only window-specific metadata. This derived ordinary envelope is test setup, not new producer/page acceptance; no entries or product facts are invented. Unsupported cursor/anchor modes remain unavailable.

The final actual `SessionTimelineScreen` loads all six retained rows without a timeline error. Three native 600 × 900 dark AppKit captures were inspected: populated Flow, Forecast and returned Flow. Retained entry identities, draft, Session ID and playback remain unchanged. Existing GET-only fencing rejects command/message effects; no speech/playback/source-Link action is pressed. The final fixture/lifecycle run passes one function with 16 cases. This does not establish nonzero reading-position preservation.

## Why the position result is inconclusive

A first direct clip-view probe found that SwiftUI may replace the native scroll container during the switch. Reading the old detached container would falsely report position preservation. The final recorder reacquires the actual returned container and records whether identity changed.

An unposted synthetic CGEvent contains a real pixel delta of -400, but both direct native scroll-wheel dispatch and the own-NSWindow dispatch route leave this offscreen host at zero. The final metrics record event window number 0, a different actual host window number, and offsets 0 → 0. The recorder explicitly emits `INCONCLUSIVE_NATIVE_WHEEL_INPUT`; zero cannot count as a nonzero position PASS. This is an input/host qualification limit, not physical-wheel acceptance or a confirmed product defect. The direct clip probe used an incompletely served prefetch and is not product counterproof.

Earlier failures remain preserved: the initial mutable reply caused a test-only Sendable compile error; an incorrect conversation-version advertisement prevented owner preparation; the first negotiated run had unsupported prefetch and an overstrict same-container assertion; wheel prerequisites failed because no nonzero position was established. These runs are not passing evidence. No production correction is justified by them.

## Evidence and next step

Logs and directories: `/private/tmp/djc-populated-flow-{native,final,negotiated,wheel,window-event,recorded}-20261021`. The `recorded` log and directory contain the final successful fixture checks, three inspected captures and explicit inconclusive position metrics. The receipt hashes source, fixture and private evidence. `git diff --check` passes. No unchanged iOS build, push, PR, merge, ordinary installation, deployment, SDK operation or recovery bundle was performed.

Do not repeat these unchanged offscreen wheel/AX probes. The next independent point is the outstanding native iOS display-consent disabled correction: inspect the existing isolated NativeConsentUIHost and private evidence, then consider a materially different own-B62 Simulator UI route rather than the stalled XCTest result-finalization runner. Keep all HTTP synthetic and retain the actual iOS identity; ordinary app-start/publication approvals remain pending. Do not infer physical/installed/VoiceOver or full-root acceptance.
