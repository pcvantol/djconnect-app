# Native push registration task custody

Base: `b9d0ea6922c6a6036feec8f88f67314bf75b5bb3` (Source214). This source increment connects fresh native token observations to separate widget and Activity registration owners. It does not activate provider delivery.

## Behavior

The app binds each owner to the current paired installation, origin, device, client, profile binding and active session. Backgrounding, owner loss, Activity termination and token replacement synchronously discard read custody and cancel owned transport work. Observation generations fence delayed token queries and A-to-B-to-A transitions.

The native inventory attempt captures both owner generations before scheduling the child task, and the child joins that immutable attempt before the first SDK await. It never captures a replacement generation inside the child. The same AppModel predicate fences success, failure and Activity observation. A cancelled or obsolete inventory cannot persist a pending token or withdraw a successor. Gated tests exercise delayed success and error after cancellation or an A-to-nil-to-A owner change for both roles; separate MainActor tests delay the child start itself, perform the owner change/cancellation without suspension, and assert zero first SDK-model calls. An unchanged-owner control permits one call. These are explicit inventory models, not injected real WidgetKit callbacks.

The widget owner implements the existing strict HA v3 context/register exchange, then existing v1 status, scoped read and revoke. One operation identity survives an uncertain result; neither polling nor token rotation retries an uncertain mutation. Original purpose bounds retain their minimum in RAM. Requests use the exact paired HA origin and identity, with no v2 fallback. Read transport carries only the separately scoped read credential. A read result is data only; it is not an extension publication or a display lifetime.

ActivityKit observation uses actual current Activity state and pushToken, plus exact local presentation bookkeeping. Saved pending tokens alone cannot reconstruct registration authority. The old local ContentState is not relabeled as the remote profile proposal.

## Production remains closed

The public owner constructor has no positive admission factory. Its internal injected admission is explicitly a test model. No UI flag, wire boolean, inferred sandbox environment or local UTC arithmetic enables it. The missing production factory requires qualified native clock/rate/suspend/domain evidence, authentic original first-purpose history and the original server-granted consent. The existing v3 producer admits widgets only: Activity registration explicitly reports profile unavailable.

Cold extension restart/delegation remains a separate unaccepted design. No credential sharing, Keychain delegation, extension read publication, enrollment secret, new API contract, provider action or real native registration is introduced. A local registration instance ID is not a WidgetInfo placement ID. APNs environment is unknown until genuine deployment metadata is admitted.

## Validation

Evidence directory: `/Volumes/Shared Data/tmp/pcvantol/apple-surface-push-owner-20261026`.

- `full-owner-r7.log`: 1,302 tests in 30 suites passed; this preceded the final public visibility correction for native cross-module bookkeeping.
- `native-ios-r1.log`: failed to compile because the existing bookkeeping helper was fileprivate. Preserved as a historical failure.
- `native-ios-r2.log` and `.exit`: final source compiled against the actual iOS SDK; 12 tests passed, parent exit 0.
- Final full-suite rerun: `full-owner-r8.log` / `.exit`: 1,302 tests in 30 suites passed in 133.803 seconds, parent exit 0. Final macOS rerun `native-mac-r2.log` / `.exit`: 12 tests passed, parent exit 0.
- Additional inventory-race correction: `native-ios-r4.log` / `.exit` and `native-mac-r4.log` / `.exit`: 13 tests passed per platform, parent exit 0. The full successor run is `full-owner-r10.log` / `.exit`; earlier results are not silently relabeled.
- Independent review of predecessor `1cb0d26` found that its attempt capture still happened inside the scheduled child. The after-await model tests did not cover this placement race. That candidate remains a historical HOLD. The corrected capture is before scheduling; `owner-child-r11.log` / `.exit` passes 14 tests, including delayed-child-start cases. Final native runs `native-ios-r5.log` / `.exit` and `native-mac-r5.log` / `.exit` each pass 14 tests with parent exit 0. Complete successor run `full-owner-r12.log` / `.exit` passes 1,304 tests in 30 suites in 136.788 seconds, parent exit 0.

The tests use isolated URLProtocol model endpoints. They exercise withdrawal before delayed replies, actual Foundation cancellation, uncertainty, original minimum expiry, token rotation, paired-device mismatch and separate read credentials. Positive test admission assumes a clock model explicitly; it is not native clock qualification. Native unit compilation/tests do not establish real tokens, provisioning, enrollment, APNs delivery, extension refresh, Activity pixels or privacy erasure. No release version or installation changes.
