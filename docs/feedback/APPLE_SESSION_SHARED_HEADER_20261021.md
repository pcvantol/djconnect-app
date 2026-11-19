# One shared Session header — 21 October 2026

Flow and Forecast previously occupied two overlapping scroll hosts. The Flow host was hidden while Forecast separately created `scrollingCurrent(activeSession)`, duplicating current artwork, playback controls and the persona/avatar header. The Forecast host also escaped Flow's 1000pt content width cap.

The live Session now has one scroll host and one current header, positioned before the mode conditional. Only the lower section switches between the Flow history/search content and `SessionForecastContent`. Both modes inherit the same content width and header geometry. The old standalone Forecast wrapper remains only for isolated component callers; the live Session no longer invokes it or supplies a second header.

Forecast scene/owner/epoch/freshness task context moves intact to the lower content component. Search/query state and per-mode position bindings remain owned by the Session. Existing archive content remains in the Flow branch. Composer, toolbar and playback actions remain outside this change.

Validation: Mac compile PASS; two native layout tests PASS (no second scroll host in actual Forecast content; supplied header top difference 0pt at widths 500 and 900). The updated Forecast owner-context regression passes all 16 cases. Total 3 test functions, 18 cases, 0 failures, 0 skips. `git diff --check` PASS. Raw evidence and source hashes are bound in the adjacent JSON.

These tests qualify the actual lower component and supplied marker geometry. They do not establish physical full-root switching, artwork/AV playback continuity, iOS runtime or device installation. Existing unrelated build warnings remain in the private log.
