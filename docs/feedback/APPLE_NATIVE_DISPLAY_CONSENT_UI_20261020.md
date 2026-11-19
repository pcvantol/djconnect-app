# Native display-consent form and withdrawal follow-up

This local successor follows appmodel-qualification commit
`8462454f4c662259b0fd47f4bd78c2545f41daa0`, based on reconciled main
`aa9785361e6d41f9c086765fc3b9db28669184b8`. The first increment's 18 iOS
appmodel tests and 13 macOS tests remain recorded at their original freeze.

The isolated project generator now has `--with-ui`. It hosts the actual
`VibeCastDisplayConsentForm` with the real appmodel, matching the shipping root's
dark appearance. The synthetic URLProtocol wire is extracted from the existing
consent-test fixture; ordinary credentials, HA, App Attest and providers are not
used. Separate bundle identifiers and defaults preserve ordinary applications.
This is actual form interaction, not full-app navigation or installed HA proof.

## Completed native evidence before the UI correction

On the existing iOS 27.1 simulator, final serial native tests completed with
**3 passed, 0 failed, 0 skipped**. The result bundle is
`/private/tmp/djc-native-consent-ui-20261020/final-terminal-states.xcresult`.
The tests enter six digits, tap lookup, require zero approvals before explicit
consent, then cover successful confirmation, Profile withdrawal without an
effect, and uncertain approval without a resend. They wait for the actual
localized terminal text, so a spinner alone cannot qualify the scenario.

Earlier separate serial runs also passed 1 and 2 tests. Their four screenshots
were exported and inspected: ready with zero approvals; approved with one;
withdrawn with zero; uncertain with one and no resend. The initial light host
did not match the real root environment; subsequent qualification uses the same
dark environment as `DJConnectRootView`.

## Bounded source correction and remaining check

The withdrawn screenshot exposed an enabled lookup action after Profile
authority had been removed. Appmodel admission already prevented dispatch, but
the native button tested only code length and busy state. Its disabled condition
now also checks `!model.canResolveDisplayConsent`, matching the admission used by
the screen-link entry. No protocol, model, translation or playback change is
introduced. The withdrawal UI test now additionally requires a disabled action.

After this source correction, macOS compilation and all **13 targeted tests**
passed. The additional native disabled-button assertion is **NOT QUALIFIED**:
its before/after runs and the combined corrected run stalled in Xcode test-log
finalization, with no complete result bundle. They are not counted as a failing
counterproof or a successful corrected run. Screenshots and the original
disabled expression establish the UI mismatch; a completed corrected native
test is still required. A separate build-for-testing result is recorded in the
adjacent receipt to distinguish compilation from runner acceptance.

The first stalled run and later incomplete bundles/logs are retained privately.
Only identified jobs owned by this chat were cancelled; unrelated runners,
devices and simulator sessions were preserved. Do not repeat the unchanged
stalled runner without a meaningful environment or harness change.

This follow-up remains local and requires review/delivery. The earlier draft-PR
publication request for exact `8462454` was automatically rejected and awaits
the user's specific response; it grants no publication authority for this
follow-up. No new branch publication, protected merge, ordinary installation,
backend deployment, SDK/key/provider effect or recovery bundle occurred here.
Installed/current HA, receiver rendering, full-root navigation and physical
acceptance remain open.
