# Native avatar motion and haptic feedback — 20 October 2026

Owner requested independent Apple work on avatar animation, glass interactions,
layout, accessibility and stability while Core delivers, then explicitly added
haptic feedback on avatar taps/reactions. This is the first bounded native slice,
not completion of all five areas or activation of Persona touch.

## Implemented

The foreground avatar now requires an active scene before running its speaking,
listening or preparing animation. It observes actual power/thermal notifications
and rereads those values on foreground return, in addition to respecting the
read-only OS Reduce Motion preference. Mood, activity and actual audio admission
are unchanged. Inactive scenes do not keep a hidden animation running; resume
restarts the same bounded graphic without moving its center.

An admitted explicit avatar interaction issues a light selection haptic. A valid
current response invokes one success feedback callback; repeated audio callbacks,
cancellation and late/stale responses cannot replay admission feedback. The
controller injects feedback so regressions do not drive physical haptic hardware.
The app wires these hooks to the existing iOS and macOS feedback implementation.
No synthetic speech envelope or backend reaction is generated locally.

PersonaReactionConsumerGate remains false. The existing separately qualified
producer/installed/native admission is still required before the real touch
control is activated. This source does not enable an unsupported server feature
or claim that physical haptics have been felt on an iPhone/trackpad.

## Executed evidence

A native NSHostingView/NSWindow frame probe first reproduced background motion:
six distinct speaking frames while active AND six while inactive; the latter
failed its regression. After the fix the same native window traversed speaking,
background, resumed speaking, listening and rest. Six samples per phase yielded
6 / 1 / 6 / 6 / 1 unique frames respectively, with a stable160pt square canvas.
Selected real frames were visually inspected. Explicit local activity is used;
this proves native rendering/lifecycle, not real microphone, audio or server E2E.
The opt-in test uses DJCONNECT_NATIVE_MOTION_DIR and skips without that request
or if actual OS motion/power/thermal policy disallows active motion. It never
changes those system preferences. CI does not silently claim this opt-in proof.

Full local regression after the product-source changes:72 XCTest cases and902
Swift Testing cases,974 total, PASS including the actual native motion probe.
Subsequently the existing five current-card render cases were expanded to320pt
and620pt:10 cases PASS. Compact Moment and wide quiet renders were inspected;
the single avatar and top-aligned text remain inside the same card. CI must
qualify the complete final candidate including those five additional cases.
Haptic regressions cover cancellation before result, one accepted response,
repeated audio callbacks and stale-owner responses.

Private source-bound logs and30 native frame PNGs are retained under
build/qualification/native-motion-glass/. Earlier failed harness attempts are
preserved: the read-only accessibility environment cannot be overwritten;
offscreen glass accessibility returned no AX children; offscreen glass caching
failed its harness assumption/transition. These are not product failures or
accessibility acceptance. The reliable avatar frame probe is retained separately.
A separate unique-bundle Mac UI test app was built for existing avatar/favorite/
artwork checks. Its first unsigned runner had an invalid resource signature;
ordinary ad-hoc signing required production capabilities/profiles. A restricted
sandbox diagnostic identity (no push/app-group rights) was then signed without
account/profile changes. UI test execution/acceptance is still pending and must
be recorded independently; compilation/signature alone is not a click PASS.
No shipping entitlement or project identity was changed by these diagnostics.

## Still open

Full glass press/hover/keyboard/VoiceOver acceptance, actual physical haptics,
long-running stability/performance and installed iPhone/iPad/Mac acceptance remain
open. No measured performance gain, all-UI completion, real speech/touch or
whole-Core-product acceptance is inferred. Ordinary installed apps, playback,
pairing and API/HA service state were not changed. No deployment/install is part
of this source slice; existing VibeCast binary-profile admission remains separate.
