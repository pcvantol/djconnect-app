# Status endpoint synchronization

Owner requests automatic internal/external HA URL changes after pairing.
Producer already emits ha_local_url/ha_remote_url on authenticated status. Apple
Envelope drops them and refreshStatus ignores them. Playback status often bypasses
POST status entirely. Decode the optional fields, adopt validated endpoints only
from the same paired installation and still-current request context; preserve
omitted/invalid fields. Explicit remote_supported=false withdraws remote route.
Bound metadata heartbeat to once per minute/foreground, including when playback
exists. No pair/token replacement, operation replay, credentials in URLs, new
backend wire fields or silent adoption of another installation. Route changes
rebuild existing transport and reset old local probe/pinning state.

Implemented optional Envelope fields; same-install/current-route admission,
origin-only HTTPS remote or existing qualified-local candidate classification,
missing/invalid field preservation and explicit remote withdrawal. Persist both
routes and rebuild transport without pairing/token changes. Old local route
reporters cannot pin the obsolete URL back. Authenticated metadata heartbeat is
coalesced/bounded to 60 seconds and retriggered on foreground, independent of
whether playback is present; transient metadata failure preserves playback.

Validation: shared Swift build PASS; 2 dedicated endpoint tests PASS
(/private/tmp/djc-endpoint-sync-tests.log); unsigned iPhone/iPad+Watch build PASS
(/private/tmp/djc-endpoint-sync-ios-build.log). Expanded status/pairing/fallback
selection: 91 PASS, 1 FAIL (92 tests), log
/private/tmp/djc-endpoint-sync-related-tests.log. Failure is
activeMoodLateFailureAfterBackgroundCannotRestoreOldStatus: fixture advertises
legacy Mood CAS1 and expects /session/mood. Existing settings3 capability code
already gates activeMoodAvailable on sharedSettingsAvailable, so this old test
cannot enter its CAS branch. Endpoint adoption is not called in that test; do
not call the expanded selection green or settings consolidation completed.
No installed URL-switch/real HA change acceptance claimed in this source update.
