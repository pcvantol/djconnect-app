# Apple startup/resume connection recovery, 2026-10-17

Same Apple writer/branch, owner-reported long no-connection after start/resume.
No producer contract change or backend mutation.

## Evidence and root causes

The actual iPhone redacted diagnostic log shows ordinary build40237 start at
10:55:12 and successful Resume Now Playing status at10:55:13. Thus that start
was not an HTTP outage. SessionConnectionStatus and About nevertheless treated
hybrid recoveringOffline/localDegraded as the whole app offline, overriding
successful authenticated HTTP status. Hybrid lifecycle(active) also invalidated
route qualification on every duplicate active notification; AppModel scheduled
settings reads before its asynchronous transport resume. LAN preference cooldown
was reset on every active notification, and network return did not trigger a
fresh paired status read. Hybrid context requests inherited Foundation's long
default timeout; ordinary status had a ten-second generic API timeout before
external fallback.

## Fix

- Track the origin of a successfully authority-checked status response, only in
  foreground RAM. Reset on background/unpair/connection failure. Session and About
  share one effective mode resolver; a recovering optional Session transport cannot
  invalidate this HTTP proof. Terminal authority withdrawal still means offline.
- About can display that actual status origin and HTTP/HTTPS transport; configured
  URLs alone remain insufficient. Session-local degraded state is not local-ready.
- Repeated same-state lifecycle signals are idempotent. Resume transport before
  Session reads; Profile settings follow the critical Session read. Late cancelled
  context probes cannot publish authority/offline state.
- Status and authenticated transport-context LAN reads:2seconds; external TLS:8.
  Action operation timeout remains15seconds and uncertain writes are never replayed.
- Keep real failed-LAN cooldown through short app interruptions. Network change
  clears cooldown and schedules immediate existing paired refresh, without throttle
  or another timer. Known cellular-only path omits the local candidate when a
  configured external URL exists. Qualified local-HTTP policy remains unchanged.

## Qualification

27 targeted transport/connection tests pass, including duplicate active, actual
background/resume requalification, LAN failure -> authenticated TLS, context timeout
budgets and confirmed HTTP vs optional Session recovery/terminal authority.
Final full Swift suite and physical iPhone cold/resume acceptance are recorded
below when complete. Mac/iOS native build40238 and strict deep signature passed;
ordinary apps installed on iPhone/iPad/Mac mini, previous Mac app retained.

Physical Wi-Fi/cellular handoff, MacBook installation and HA-dev direct-local
security qualification are separate and not claimed by these tests. No hidden
change to pairing, HA provider, Profile defaults or Session lifecycle.

Final Swift regression suite:728 tests in10 suites PASS,85.622seconds.
Physical iPhone40238: testColdStartAndResumeConnectWithoutManualRefresh PASS,
9.545seconds overall including terminate/launch, tab navigation, Home and activate.
The connection predicate was already satisfied on its first evaluation at7.00s
of this UI flow; after activate it was satisfied on the first evaluation at9.21s.
This is not a precise handshake benchmark; no manual refresh was used.
Both devices report ordinary installed version40238. Mac /Applications also40238,
strict deep codesign succeeds. Source remains same-writer uncommitted WIP; no PR
or protected delivery/merge claim.

Corrected physical DJ-voice UI test also PASS on40238. No device settings changed
by either UI test. Final git diff --check passes.
