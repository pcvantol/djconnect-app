# Persona popover parity

Owner requested the Mood/Presence presentation and UX for Persona, removal of the
transient changing-Persona label/spinner, and preservation of the toolbar.

The original toolbar-owned Persona popover used a separate presentation anchor.
iOS Persona now joins the same SessionControlPopoverHost/geometry-anchor as Mood
and Presence. It reuses SessionGlassChoiceSelector:4glass segmented icon choices,
centered title and confirmed name. No pending progress row/temporary changing copy;
pending disables duplicate writes without changing layout. Actual errors remain.
Mac uses the same content/width/focus/Escape behavior as the existing controls.

Backend mutation, same-session/epoch/owner guards and confirmed selection are
preserved. Unknown confirmation selects no option (-1), not a fabricated Home DJ.
Session/Profile/scene changes dismiss and invalidate the captured presentation.
All existing five-language names and accessibility labels/IDs are reused.

5 Persona regression tests PASS, including4negative reply cases. Ordinary signed
iOS/Mac builds40234 and final40235 PASS. Native iPhone40234 test PASS: all4 options,
first option below original toolbar's bottom edge, Mood control still present.
Screenshot exported/visually inspected: toolbar fully visible, Persona bubble
below, glass choices and existing Festival-dj confirmation, no spinner. No write
or persona change was made. The same screenshot independently shows the previous
current-track Bluetooth footer fix rendered on the actual active iPhone route.
Private native evidence /private/tmp/djc-personapopover40234-native.xcresult and
/private/tmp/djc-personapopover40234-screens. Final40235 runtime readback follows.

Final40235 native iPhone test PASS, /private/tmp/djc-personapopover40235-native.xcresult
and log; ordinary app installed/read back40235 on iPhone/iPad and local Mac mini.
No iPad/macOS visual-runtime PASS inferred from installation. Previous Mac40234
preserved. This is the bounded Persona UX fix, not closure of shared settings.
