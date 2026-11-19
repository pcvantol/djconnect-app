# Physical iPhone Session diagnosis —18October2026

Owner requests direct iPhone debugging for stutter, jumping feed and unavailable
Session. Fresh read-only CoreDevice confirms ordinary40315, livePID17305 and
provides the existing app log. Instruments still lists the device offline; owner
has only Wi-Fi now and explicitly defers USB profiling until tomorrow. No new
installation, termination, pairing reset or CPU/GPU/FPS acceptance.

App log shows separate remote502 failures near03:38, then five history timeline
route_missing/404 failures03:49:10–03:50:03, with voice delivery uncertainty and
speech audio_fetch failures. Read-only installed HA-dev handler hash matches the
frozen Core candidate. SQLite confirms the Session started03:44:44 is ACTIVE,
history_enabled=true, same owner as the iPhone history requests.25such03:49
profile resolutions all resolve one explicit Profile. This rules out a blanket
claim that the active Session was deleted; the actual failing reference/transport
and handler refusal remain unproven. Local tunnel inspection1000requests showed
no direct historyHTTP404; do not equate synthesized transport diagnostics to
captured raw request/response proof.

The owner explicitly authorized the existing Core writer to investigate/repair
that404. A bounded evidence-bearing message was successfully sent to existing
Core chat01a120e2-b557-76c3-8568-129dbce2f2d2. No backend changes by Apple. Core
result and installed functional acceptance remain pending; this is not closure.

Separately reproduced client layout instability: every background loadTimeline
cleared an existing error before its read, then a failing read restored it. The
visible error block therefore collapsed/reappeared every polling cycle. A new
regression failed twice on old source, then passed after preserving the error
until a successful response. Confirmed entries and authority-denial behavior
remain intact. A confirmed empty-timeline label now also stays during background
reads instead of disappearing on loading=true.

Full819tests/10suites PASS89.983s. Ordinary signed iOS40323 build including
Watch/widgets PASS;276current input hashes match the source manifest. Five-language
1283keys and git diff --check PASS. No measured stutter/CPU/GPU improvement or
repair of the server404 follows from this bounded client correction. Preserve
phone40315 as the before-measurement; compare the candidate over USB tomorrow.

Counts-only and bounded-results receipt:
[debug receipt](APPLE_IPHONE_SESSION_DEBUG_20261018.json).
Raw device logs /private/tmp/djc-iphone-debug-20261018; source/test/native build
receipt inputs /private/tmp/djc-session-stability-40323.
