# Native Forecast filter presentation — 20 October 2026

Tests-only native macOS qualification based on `a92f4b1a53e62448775279afd6db198f78f5e50f`. Production sources are unchanged.

The opt-in `DJCONNECT_FORECAST_FILTER_DIR` hosts the actual `SessionTimelineScreen` with the existing paired GET-only fixture in its own offscreen dark AppKit window. The final 600 × 1400 viewport shows all three authored cards. It selects Forecast through the real segmented control, edits the native search field and delivers its native edit notification. This is not physical keyboard input.

Five final captures were inspected:

| Native query | Visible authored sections |
| --- | --- |
| Empty | Now; The coming minutes; What I am aiming for |
| STEADY | What I am aiming for (case-insensitive body match) |
| MINUTES | The coming minutes (case-insensitive title match) |
| zz-no-authored-match-zz | None |
| Cleared | All three original sections restored |

The producer summary stays visible throughout, including when no sections match. It is not rewritten or fabricated as a search result. The exact visible producer projection remains equal after every edit. The unsent Ask DJ draft, Session ID and playback value remain unchanged; the existing transport fence admits only GET and rejects command/message effects.

The final Swift Testing run passed one function with 16 lifecycle cases, with the native filter sequence executed in the current-owner case. Test assertions cover real field edits and unchanged model state. The section-presentation findings above come from inspection of the five actual native captures. SwiftUI exposed no NSTextView strings for its selectable text in this host; the empty arrays in the evidence are not text or accessibility acceptance. VoiceOver, arbitrary locales, physical input, iOS runtime, ordinary installed apps, current HA/server/provider and populated Flow history remain unqualified by this test. The synthetic Flow timeline still intentionally returns 404. No iOS compilation was repeated for this tests-only change.

Final log and captures: `/private/tmp/djc-forecast-filter-final-20261020.log` and `/private/tmp/djc-forecast-filter-final-20261020/`. The earlier 600 × 1100 probe and its partial bottom card remain at `/private/tmp/djc-forecast-filter-probe-20261020.log` and directory; the final taller captures supersede it for full-card inspection. Receipt hashes pin test source, unchanged renderer, producer fixture, logs and captures. `git diff --check` passed. No push, PR, merge, installation, recovery bundle or external effect was performed.

Next independent point: qualify whether currently displayed native Forecast content withdraws when the existing owner authority is suspended. Use the actual model and synthetic transport; preserve draft/Session/playback and distinguish rendered withdrawal from source-only state checks. Do not repeat the unchanged accessibility tree probes or stalled iOS runner.
