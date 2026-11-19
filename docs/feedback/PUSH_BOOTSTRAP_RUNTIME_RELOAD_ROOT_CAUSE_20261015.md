# Push bootstrap and false pairing withdrawal — root-cause finding

## Reproduced defect

Central install-token bootstrap succeeded with HTTP200 at11:45:47.090. The same
historic HA-dev window records runtime restoration at11:45:47.093. Mac40062 then
logged Applying app error state: auth stale HTTP401, with no retained corresponding
HTTP API failure entry. The original live wire frame was not retained, so the
historic transport event itself is not claimed as captured.

The installed Core source has a reproducible false-withdrawal path:

1. central_api._persist_install_settings saves the central install token in
   config-entry options. Push status also persists CONF_LAST_PUSH_STATUS.
2. _entry_reload_signature excludes only Spotify refresh-token/device-status
   cache fields, so these push writes can trigger full runtime reloads.
3. paired_live.immediate_authority compares runtime object identity. Any
   replacement is reported as pairing_revoked, even if the persisted paired
   device-token and identity are unchanged.
4. Apple previously converted this live code into authStale(statusCode:401)
   locally, then deleted the credential. This synthetic status is not proof of
   an actual failed canonical HTTP request.

A read-only source comparison confirms both implicated installed HA-dev functions
are identical to the investigated Core source. Evidence:
/private/tmp/djc-push-root-installed-source.json.
An isolated reproduction invokes the actual update listener with test doubles,
performs no live HA updates, and verifies reload/runtime replacement while the
paired credential remains equal:
/private/tmp/djc-push-core-reload-repro.py and its JSON result.
Four Apple regression tests first failed on the previous implementation.

## Implemented Apple correction — build40068

A live authority-loss event still immediately withdraws all private projections,
voice work and widgets. It now retains the credential while independently
validating the paired identity through the existing canonical HTTP status
heartbeat. It does not retry push registration or any playback/session action.
A qualified DJConnect unauthorized/pairing_revoked HTTP response withdraws the
credential. Unqualified HTML/proxy401, malformed responses, temporary503 or
network loss do not. Temporary503/network status validation is bounded to three
attempts; existing configured route selection may use its read fallback.

Late responses cannot affect a changed token, HA configuration or backgrounded
app. Success schedules normal foreground refresh from fresh owner data and never
reinstates old private projections. Generic not_configured during a paired
runtime outage no longer erases the credential. Push-specific auth failures also
use independent validation; a failure clears an earlier green push registration
flag rather than presenting stale confirmation.

## Core companion change still required

The existing Core writer owns the separate runtime/persistence correction:
avoid unnecessary teardown for hot-read push/install/status persistence, retain
normal reload for configuration changes that require it, and distinguish runtime
replacement/reload from true device pairing revocation. Cover central bootstrap,
status persistence, token rotation, overlapping requests, actual removal/token
revocation and retained session/operation recovery. This is a request for a
bounded producer fix, not permission to relax authorization or restore tokens.

An async owner question asks authorization to message that existing Core task;
it remains unanswered at this checkpoint. No Core source was changed, no second
Core writer was created, and no Python HA deployment/restart was performed here.

## Verification and acceptance

Final Swift suite:580 tests PASS31.696s. Native Apple Development signed Mac and
iOS builds40068 PASS. Tests include status success after live replacement, real
credential rejection, unqualified proxy401, bounded503, background cancellation,
changed credential/configuration, and actual push-registration failure paths.
Existing privacy tests continue to verify immediate clearing; they now allow
only the status heartbeat as an additional POST, never a command replay.

Two existing asynchronous test fixtures required completion-aware waiting and
normal post-pair status-read handling; no output-selection product source changed.
Logs: /private/tmp/djc-push-root-acceptance-tests.log,
/private/tmp/djc-push-root-mac-final.log, /private/tmp/djc-push-root-ios-final.log.

Ordinary Mac mini40068 installed/launched PID22107, strict/deep signature,
installed hashes, entitlements and preferences verified. Receipt:
/private/tmp/djc-push-root-mac-install.json. Physical iPad40068 installed and
launched. MacBook/iPhone not updated in this checkpoint. The Mac mini was already
unpaired before the fix; no lost token was restored and no speculative re-pair
was performed. Actual post-fix APNs registration/delivery remains OPEN. Software
reproduction and installation are not a real testpush PASS.
