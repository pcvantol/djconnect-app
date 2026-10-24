# VibeCast Apple connection source review — 22 October 2026

Scope: existing Apple writer, PR179, source only. Peter explicitly authorized
coordination with existing API and Core writers. No builds, test execution,
installation, App Attest calls, Keychain effects, HA changes or deployment.

## Contract readback

- Core source inspected at main `83744790decc6ef8940795dc2c9c0e3fb058173b`:
  `display_authority.py` admits `ios` and `macos`; `display_service.py` defines
  owner/context, resolve, approve and revoke contract version 1. Revoke requires
  session_id/share_id and optionally display_id. Supplying display_id targets
  that screen only, including an approved claim not yet collected by the browser.
- Core writer reports its last installed verification as the same main at
  12:01:30 UTC, 239 integration files equal. This is a writer report, not fresh
  Apple deployment or physical acceptance. Later unmerged Core work is separate.
- API main inspected at `9ab24315a10b569b84e738d09bf32df6da12e38b`.
  `docs/rendezvous/source-finalization-v1.json` releases implementation source
  `djc-rendezvous/1-implementation.1`; public activation remains HOLD and native
  acceptance/production readiness are not granted by that source release.

## Direct Mac entry

Peter confirmed the intended Mac entry: open the HA receiver page on the target
screen, enter its six-digit code in the Mac app, and explicitly approve. QR
scanning and the public vibecast.tv redirect are optional destination preparation,
not prerequisites for this route. The existing Mac TV toolbar button opens the
same shared form. An active paired DJ Session and Core's qualified HA display
origin remain required by the existing contract.

## App changes

1. Mac uses the same owner-authorized six-digit TV-code flow as iPhone/iPad,
   replacing the normal UI dispatch to the legacy handoff form. Each request
   carries the actual paired client type; Watch and other types remain excluded.
2. The approval receipt exposes an explicit stop action. A fresh installation and
   owner context, original issuer/route, owner token and original wall/monotonic
   lifetime are checked again before targeted revoke. The app sends display_id;
   it does not end the Session or revoke other screens. Unknown outcomes clear
   displayed approval and do not replay the request.
3. QR entry has an explicit system Paste action alongside the iOS scanner. QR
   capabilities are parsed by the existing bounded parser and are not displayed,
   logged or persisted. Selection of the saved HA installation remains explicit.
4. The rendezvous view has a distinct TV-code continuation for an existing active
   Session. It does not create a Session or grant approval as a side effect of QR
   acceptance. Text in all five languages describes the app confirmation.
5. Unsupported/unadmitted native A preparation stops before public inspect,
   authenticated owner reads or envelope construction. The exact signed finite
   native admission remains unchanged; ordinary builds do not gain runtime A.

## Verification and limits

Added test source covers Mac identity on all four owner routes, exact targeted
revoke fields, repeated-intent rejection, unknown revoke outcome, owner withdrawal,
changed issuer and unsupported clients. Tests have NOT been compiled or run.
Static checks passed: git diff --check, plutil for all five localization files,
identical unique localization key sets, targeted-revoke/identity source assertions,
and work-register validation. These are source checks, not runtime PASS.

A and B remain separate: the existing paired TV-code B route can be implemented
without A's App Attest admission. Full QR A→B runtime acceptance remains open
until the exact API/native contract and execution admission, an explicitly requested
signed build, and physical phone/HA/receiver/TV verification. The approved-screen
receipt and stop button are scoped to the current foreground consent form;
reopening does not reconstruct a display-management inventory or persist authority.
No claim of complete public VibeCast operation or installed-app repair is made.
