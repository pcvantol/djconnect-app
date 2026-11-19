# Apple passive Session contributions: grant and publication recovery

Scope: existing Apple writer, `codex/passive-session-contributions`, stacked on
history-summary PR116 (`6a7fd8d02b74c8a84de500272edec728062e3393`). This is a
bounded correction to the existing passive1 consumer, not a new delivery contract.

## Reproduced defects and correction

The home widget incorrectly required `cache_policy.locked_display=true` even
though the canonical passive1 contract permits a widget grant without locked
display. The client now requests locked display only for Live Activities and
uses the DTO's purpose-specific validation. A missing locked-display permission
still rejects a Live Activity. The prior test helper overwrote the fixture policy
for both surfaces; it now preserves their different permission requirements.

A publication invalidation arriving while optional artwork IO kept a surface
busy could be discarded. Invalidations now coalesce per granted surface and
schedule a pure reread after the busy operation finishes. Reads keep the existing
rate bound, owner epoch, grant version, delivery sequence and original expiry.
No authorization replay, new consent, background loop or lease renewal is added.
Suspension and owner/session changes clear pending work.

Both defects failed their targeted regressions before the fixes. The corrected
focused passive suite passes **18 tests**; the full suite passes **843 tests /
10 suites in 92.879 seconds**. Source-level qualification does not establish the
exact cause of a particular installed widget's neutral fallback.

Ordinary signed **40337** iOS/Watch/widget and macOS builds pass. Strict signature
checks pass outside the restricted trust context; both ordinary products contain
zero test bundles. Installed version40337 is independently read back and the app
opened on iPad, MacBook and Mac mini. Previous Mac apps remain recoverable and
pairing storage is unchanged. iPhone/Watch have no new installation proof.

The retained redacted iPad40336 log also records valid accepted caches with
`playback=false contribution=false artwork=0`, a rejected Live Activity response,
then temporary503 reads and Profile revalidation. These are separate findings:
the two Apple defects alone do not explain all empty-widget observations. The
existing Core writer received this functional evidence for producer diagnosis.

## Integral work still open

Core is repairing a producer mismatch: researched `public_artist_narration_v1`
can appear in a v1 passive envelope whose Apple consumer admits only the original
qualified bases. Apple does not broaden this allowlist without the negotiated
source-rights, attribution and omission-reason contract and producer fixtures.

The owner selected best-effort quiet updates. The intended path is event-driven:
accepted publication, track change, session end or authority withdrawal targets
the registered device/surface, with coalescing. An ordinary silent notification
may wake the app for an authorized pure read and widget reload. A Live Activity
requires its separate ActivityKit token for direct update/end. No per-second
progress pushes or push-to-start are selected. Missed delivery must retain the
original expiry and recover only through a later permitted refresh.

Current implementation remains foreground-only with bounded OS snapshots; it
does not yet register ActivityKit push tokens or accept a passive silent-push
category. Core owns the selected registration/routing/rights contract and any
relay coordination. Private Ask DJ/history data, grant handles and bearer tokens
must not enter App Group snapshots or public push payloads.

Native widget/Live Activity rendering, background delivery and end-user acceptance
remain separate qualification gates. Native IDE-session startup and manual GUI
automation remain unavailable in this environment. USB scroll profiling stays
owner-deferred; this test run is not a performance qualification.
