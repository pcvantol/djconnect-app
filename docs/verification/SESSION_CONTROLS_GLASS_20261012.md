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


## Subsequent UI and state corrections

All outer hero/card surfaces now use `DJConnectCardAppearance` for radius, border opacity and border width. Compact conversation bubbles have one explicit central radius in the same appearance family. Button, field, row and artwork geometries remain presentation-specific. Native glass borders render before the glass modifier, preserving visible contribution glyphs.

The idle Session mood choices share a continuous calm background bar. The start action uses the existing primary lilac pill style. Welcome copy is larger and artwork tiles remain horizontal. Unselected sidebar symbols explicitly use the purple accent; selected symbols use white. The Mac window root fits smaller displays and clamps restored frames to the visible screen, addressing simultaneous sidebar and Ask DJ clipping.

Stopping Demo from an unpaired state restores the ordinary mandatory pairing gate, including in the native review_demo fixture. The existing sheet prevents interactive dismissal and offers Demo again. A model regression exercises stop, failed dismissal, and restart. The status popup has no close X and uses native outside dismissal. History now has a centered icon/title empty/error state; its static content passes touches to the List, while Retry stays interactive. History and other refresh buttons/gestures are guarded against unpaired and Demo states.

Legacy native AirPlay is removed end-to-end: toolbar route pickers, hidden AVPlayer, local HTTP stream server, 90-second renderer and silent-audio encoding, external-display controllers/windows, obsolete preference and strings. Ordinary Track Insight image/short-video sharing and canonical Session VibeCast receiver approval remain intact. Local-network permission copy now describes Home Assistant access.

This continuation is not an installed-device or physical performance acceptance. Final source qualification, native reruns and exact candidate review are recorded in the private delivery receipt; installation and new Mac signing require the corresponding scoped authority.


## Native iPad navigation and first-open mood binding

The custom iPad top strip is replaced by a native UIKit tab-bar controller containing the same five destinations as compact Apple presentation. Compact controller traits position the system Liquid Glass tab bar at the bottom; each destination preserves expanded content layout through a dedicated presentation environment value while native tab/toolbar traits remain compact. Queue, earlier sessions and the remaining destinations stay reachable through More. The dedicated iPad test checks the native tab-bar frame and destination reachability.

Native paired qualification exposed a first-open mood popup issue: its boolean presentation closure could capture nil Session-ID/epoch before the corresponding State values were visible. Presentation now uses an identifiable immutable MoodIntent item. The selected Session-ID and history epoch remain bound through dispatch; existing model-side authority and server revision guards are unchanged. Session, authority-epoch and scene transitions dismiss the item.

The native navigation continuation reserves offline notices using each destination's bottom safe-area inset rather than covering the tab bar. A controlled More destination item routes external player, queue, playlist and archive selections; repeated home-screen actions reset the More navigation identity. Native tab-bar-only presentation is explicit.

More menu rows and external requests now use the same bound destination item. A nil external request leaves manual navigation untouched. The native test exercises centre taps as actual touch events and separately records framework AX hit-testing; these are distinct from VoiceOver acceptance.

The iPad host explicitly bridges scene phase, dark appearance and tint into its SwiftUI screens. Rotation preserves the controller and its navigation state. The native Ask DJ→More test dismisses the existing optional Music DNA consent sheet before asserting tab hit-testing; earlier undismissed-sheet failures remain diagnostic evidence, not menu acceptance.


## Final local qualification

- 477 general Swift tests PASS; localization keys match across five languages (1,053 each).
- Unsigned macOS and generic iOS builds PASS.
- Native iPhone: controlled More destinations/offline interaction, Demo exit/required pairing/restart, and mood/status/playback time/glyph selection PASS.
- Native iPad: genuine pinned-Core paired mood confirmation, foreground recovery, independent player and 503→pull-from-error→archive recovery PASS; controlled More destinations/offline interaction and Demo exit/required pairing/restart PASS. Final portrait/landscape native tab-bar test waits for consent dismissal to complete, confirms normal hit testing and navigation, and PASS.
- Earlier menu failures while the optional Music DNA consent sheet was open, and its dismissal transition had not completed, are retained as diagnostic evidence. They are not accepted as successful menu tests.
- Native Mac window/popover readback still requires a newly bound temporary signing grant. Physical installation and physical iPad performance remain pending; no Store/HA deployment occurred.
