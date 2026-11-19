# VibeCast presentation ownership — 23 October 2026

This increment fixes an Apple presentation-lifecycle defect. It does not qualify
the public QR service, App Attest, a HA receiver or physical screen rendering.

## Behavior

Leaving the QR screen to enter a TV code opens a separate display-consent form.
SwiftUI may subsequently deliver disappearance/background callbacks from the old
QR screen. Previously those callbacks called the global cancellation method,
which also withdrew display consent. Each QR presentation now captures its own
immutable identity. Only the currently displayed, matching QR presentation may
cancel through a screen callback or its Close action. An obsolete presentation
cannot cancel display consent or a newly opened QR screen. Actual owner loss
retains the existing unconditional withdrawal path.

Independent review found two gaps in the first candidate's qualification: a
plain View property did not demonstrate identity across SwiftUI reconstruction,
and the product root's nil setter still looked up the currently visible route.
The revised candidate retains the original identity in SwiftUI State and keys
the root's QR view by that identity. Root dismissal captures its original route
and a presentation-owned closure. The product root and native harness use the
same binding helper; an old QR nil event cannot dismiss consent or a newer QR.

No approval is implicit in this transition. The user must still look up the
receiver and separately confirm. The wire contract, native admission, key
budgets, QR lifetime and receiver trust rules are unchanged.

## Causal software evidence

The new actual-AppModel regression failed against the original unconditional
callback: two assertions observed withdrawn consent instead of the pending
state. After the identity guard it passed, including reopening the QR screen,
preserving its parsed QR against an old callback, and cancelling through the
current presentation. The fixture rejects network requests and observed zero.

Private original logs under `/private/tmp`:

- `apple-vibecast-screen-lifecycle-red-20261023.log`: failed regression retained.
- `apple-vibecast-screen-lifecycle-green-20261023.log`: three targeted tests pass.
- `apple-vibecast-transition-regressions-20261023.log`: broader run failed four
  assertions; it is not counted as passing evidence.
- `apple-vibecast-transition-regressions-serial-20261023.log`: the prescribed
  explicit serial run passed all 160 tests in ten suites. Shared-fixture
  interference is suspected for the preceding failure, not proven exclusively.
- `apple-vibecast-final-full-serial-20261023.log`: pre-review source passed 1,246 Swift
  Testing functions in 26 suites, plus 86 XCTest cases with five skips and zero
  failures. Swift Testing's own conditional skips remain recorded in the log.

## Native interaction scope

The disposable native harness presents the production QR view and consent form
with the same two destination cases. It does not exercise the entire shipping
root navigation. A test opens the QR view, selects TV-code entry, enters the
synthetic six-digit code and looks it up. A test-only control then delivers the
old QR screen's callback while consent is ready. Confirmation remains available,
approval count remains zero, and only the separate Confirm action submits once.
The callback is tested **before** approval, not after its acknowledgment.

An earlier iPhone run passed this interaction. A subsequent three-case iPhone
run also passed Profile withdrawal and uncertain approval without replay. Those
historical results precede the final method rename and scoped Close action;
they are retained separately and do not substitute for the final-source runs.

The subsequent pre-review exact-source iPhone and iPad transition runs each
passed one test. These also precede the root-binding review correction.
The revised native scenario delivers the original **production binding's nil
callback**, rather than a directly supplied UUID. A second scenario opens QR,
switches to consent, reopens QR with a synthetic parsed payload, delivers the old
root nil, reconstructs the current view and uses its actual Close button. These
final revised tests and the full software suite must pass before qualification.

## Integral completion remains open

The retained two-handle bootstrap/migration/selection factory is not yet wired.
Its concrete migration, terminal-accounting and redaction schemas must be
reviewed together with their causal implementation. The existing same-key and
child-store source reviews do not qualify that missing factory.

Current native/service admission remains closed. A fresh exact supported signed
Apple candidate, finite native window, actual paired HA owner and separate
receiver approval, and reviewed operator/service admission are needed for the
real QR-to-HA-to-receiver test. An iOS simulator cannot supply genuine App Attest.
No old grant, mock SDK, empty journal root or synthetic acknowledgment may fill
these gaps. No ordinary release build, device installation or activation was
performed for this increment.
