# Session controls and glass followup — build 40016

This bounded Apple-client followup starts from reconciled main `7900ec77455234879a35844b477c6d1e46412cef`; one reused writer on `codex/apple-session-mood-toolbar` preserves the original primary WIP and completed #95/#96. No backend code, intelligence, retention, Profile scope or transport contract changes.

## Result

Session mood moves to a toolbar icon and native popover, with the existing dots/line/labels directly on the glass shell. Now Playing and Ask DJ no longer expose a mood selector. A mood intent captures Session-ID/response epoch and rejects stale actions before dispatch; unchanged server CAS fields remain authoritative. The pairing row moves from the player to a dismissible status-dot popup in the active/idle Session toolbar. Offline/provider errors are red, session recovery/live-unavailable orange, healthy paired connectivity green and Demo purple; the popup distinguishes current health from retained pairing.

End requires a localized confirm/cancel alert bound to the clicked Session-ID, and Session changes dismiss it. Context glyphs sit inside the top-right of each bubble without a separate button row. Native glass surfaces are grouped for rendering, with Reduce Transparency fallback. Contribution glyphs and border highlights render before the glass modifier so the container captures their foreground correctly; the native iPad proof shows visible/hittable glyphs and successful context selection. Current music displays elapsed/total and remaining minutes:seconds from the received projection. Timeline ticks happen at minute boundaries and exact server retention deadlines; background polling does not add a loading row to a populated timeline.

## Evidence and limits

- Full general Swift run: 477 reported tests PASS (existing gated producer qualification remains separate). HTTP mock responses are isolated per test session, and lifecycle tests await actual async observations instead of assuming 100ms MainActor availability.
- Native iPhone/iPad tests exercised opening/dismissing mood and status, mood change, and elapsed/remaining labels. Native Demo archive/end/restart tests exercised cancel (session preserved) and confirm (session ends). Latest health presentation regression covers six combinations.
- Shared glass-container iPad simulator test and scroll benchmark PASS as test execution; not a physical performance acceptance. Exploratory measurements before the final foreground-layer correction: baseline CPU 3.450s (CV23.026%), initial glass 3.388s (CV21.358%), grouped glass 2.955s (CV4.119%). The baseline variability prevents an independent improvement claim. Peak memory grows from 60.4MB to 78.0MB. Physical iPad FPS/hitches are NOT_RUN.
- Apple recommends grouping multiple custom glass surfaces with GlassEffectContainer: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
- Native Mac followup screen proof, final source delivery and physical 40016 installation remain pending. Prior ordinary MacBook/iPad40015 installation is retained. Owner connected the physical iPhone and requested inclusion; fresh readback shows ordinary build40012 before this update. No Store/HA deployment.
- Client date-parser optimization is not part of this change. Automatic approval review rejected that mutation under the separate Core-lane boundary; targeted permission remains pending.

Product acceptance: PARTIAL. Source is local pending delivery. Simulator, unsigned compilation and scripted Demo are not physical/provider/voice acceptance.
