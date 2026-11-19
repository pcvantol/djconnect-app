# Native iOS display-consent appmodel qualification

Peter transferred the sole Apple writer to the successor chat and selected eight
hours of autonomous Apple-lane work on 20 October. Base is reconciled main
`aa9785361e6d41f9c086765fc3b9db28669184b8`. This increment closes the positive
iOS AppModel integration evidence gap; native taps and installed HA/receiver
acceptance remain open. It adds tests and an isolated-project generator without
changing shipping targets or production Core/UI source.

The real iOS `DJConnectAppModel` obtains an active Session and authorized Profile
through ordinary request/decoding paths. Synthetic URLProtocol responses reuse
the two unchanged checked-in history producer fixtures, with the Session ID
rebound in memory to the existing consent fixture. No ordinary credentials or
personal account state are loaded. The existing iPhone simulator is used with an
unsigned, separate test runner.

Five iOS appmodel tests cover:

- Lookup reaches `ready` without an approval; explicit confirmation sends one
  approval and repeated confirmation sends none.
- Dismissal, background, Profile withdrawal, token replacement, route change,
  installation change, unpairing and Session end prevent a late approval.
- An uncertain approval remains uncertain and is never replayed.
- An offered existing share retains its identifier/generation choice.
- A displayed approval becomes unavailable after Profile authority withdrawal,
  and confirmation cannot repeat the effect.

The shared serialized suite also runs the twelve pre-existing coordinator tests
and date-decoding test. Final iOS 27.1 Simulator result: **18 passed, 0 failed,
0 skipped**, independently read from the `.xcresult`. Targeted macOS SwiftPM
regression: **13 passed, 0 failed**. Python compilation and `git diff --check`
pass. The first iOS iteration passed 16 tests; final coverage adds the existing
share and approved-presentation cases and serializes them with the coordinator
suite. An initial sandbox-blocked XcodeGen invocation produced no project; the
normal host invocation generated the disposable project successfully.

Reproduction uses
`Tools/qualification/vibecast-product/prepare_native_consent_tests.py` and the
instructions in that directory's README. It requires a clean existing JOSESwift
checkout at the shipping pin and refuses an existing output directory. It adds
no package download, shipping build setting or runtime test seam.

Private evidence is retained under
`/private/tmp/djc-native-consent-qualified-final-20261020/`: `final.xcresult`,
`summary.json`, `final.log` and `macos-regression.log`. Hashes and sanitized counts
are recorded in the adjacent JSON receipt. Existing UIKit compiler warnings and
Xcode beta build-number diagnostics are retained; there are no test failures or
reported runtime warnings in the result summary.

This evidence does not establish native button interaction, installed/current
HA behavior, receiver rendering, a genuine App Attest chain, provider effects or
physical acceptance. Those remain separate gates. No SDK/key/credential,
provider-budget, ordinary installation, external status publication, protected
merge or release action occurred in this increment. Watch/iPad remain deferred;
no new recovery bundle was created.
