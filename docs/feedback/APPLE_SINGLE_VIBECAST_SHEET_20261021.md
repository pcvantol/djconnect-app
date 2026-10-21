# One iOS VibeCast entry sheet

Local successor to `9a952fb`. Source inspection found two distinct protocols
presented as duplicate code-entry flows: the existing session handoff and the
newer display-consent lookup/explicit approval flow. Settings separately exposed
the QR rendezvous destination-preparation flow.

Removed the QR rendezvous entry section from Settings. Underlying QR/deep-link
handling is unchanged. On iPhone/iPad the session-start dialog now embeds the
existing display-consent form directly, with one code entry, lookup and explicit
confirmation in the same sheet. Removed the extra open button and nested sheet.
The parent supplies the hero, scrolling and single dismissal action. The form
retains reset, owner admission, expiry polling and disappearance cancellation.
The lookup remains gated by canResolveDisplayConsent. macOS retains its existing
session-handoff protocol; display consent currently admits only iOS identities.
No transport, backend contract or producer authority changes.

New actualIOSSingleVibeCastSheetContainsOneCodeEntry test hosts the actual
VibeCastSessionStartDialog using the existing actual iOS model and synthetic
URLProtocol fixture. Widths 390 and 1024 in one iPhone simulator: exactly six
native UITextFields before and after explicit model lookup; no presented second
controller; no approval POST; actual root-controller removal cancels the ready
claim. These are hierarchy/model observations, not native button taps, a physical
iPad run, visual acceptance or real-server proof.

Completed qualified xcresult: 1 PASS / 0 FAIL / 0 SKIP, no runtime warnings.
Native macOS DJConnectUI build passed in 19.20 seconds. git diff --check passed.
Initial iOS run failed before execution on a Swift Testing macro expansion of a
filter/isEmpty assertion. Replaced it with a separately calculated approval count;
production unchanged between these runs. Initial log/result preserved separately.
Own B62 simulator was already Shutdown at cleanup; no other devices changed.
No ordinary app installation or publication performed.

Evidence:

- `/private/tmp/djc-single-vibecast-sheet-20261021-qualified.xcresult`
- Qualified log `/private/tmp/djc-single-vibecast-sheet-20261021-qualified.log`,
  SHA-256 `6cd78a609008f1533884cd8129836b1add6511748e96c11b0b43683c1209fb25`.
- Summary `/private/tmp/djc-single-vibecast-sheet-20261021-summary.json`,
  SHA-256 `787f203007093e6125c8e57dc0349f3dfcc28f6ad9634227395a6eb3c660bb44`.
- Mac log `/private/tmp/djc-single-vibecast-sheet-20261021-mac.log`,
  SHA-256 `ae7462a4e69b45f4f535096bdb9446620c13fe38fae58b6ba346e70a02862e2a`.
- Initial `/private/tmp/djc-single-vibecast-sheet-20261021-ios.log` and
  `/private/tmp/djc-single-vibecast-sheet-20261021.xcresult`.
