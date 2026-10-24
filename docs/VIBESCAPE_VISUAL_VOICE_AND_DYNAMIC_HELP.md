# Visual voice control and dynamic glass help

Owner explicitly chose commands that control visuals, and requested server-provided commands plus a glass popover anchored to a help icon beside the microphone. The controls now share a row above the horizontal intensity panel. Popover controls remain visible while help/voice is active. The popup contains local touch/slider instructions; its voice examples and scope labels come only from a fresh authenticated capabilities GET on each opening/retry. No cached/static voice-command fallback. Missing/incompatible catalogue shows unavailable/retry. Five-language client chrome is localized; example text is server-owned.

Read-only Core source pin83744790decc6ef8940795dc2c9c0e3fb058173b already defines visual_director_catalogue.py and closed POST /vibescape/{context,interpret,revoke}. Client adds those DTOs and routes, using a flat body rather than the generic identified envelope, original device bearer, bounded no-store/no-cookie/no-redirect transport, and no operation replay or general conversation fallback. Public catalogue fixture was copied by executing its state-free capability() function, no paired data/network/runtime call.

A separate visual voice controller requests native microphone/speech permission and uses on-device-only recognition. Generic Ask DJ recording/wakeword guards in VibeScape are unchanged. Capture is at most8s, with a temporary WAV removed on finish/cancel. Only bounded recognized text goes to the visual interpret endpoint. Before recording, obtain a fresh server context; admit its server occurrence, retain the original≤15s lease, and bind the turn to owner/session/epoch/visit/scene revision. Local expiry cancels recording/transcription and deletes its file. Recheck immediately before send and before application. Reply must echo visit/turn/revision/lease/occurrence/original expiry. Only known patch/undo/reset/hold/variant directives reach the existing native scene methods; finite/bounded patches retain existing validation. Context withdrawal/scene change/close/background cancels work; best-effort revoke is gated to original owner/epoch/connection. No playback command, server audio upload, transcript history, provider lookup or renewed source lifetime.

Permission panels may briefly inactivate a scene without closing VibeScape; capture waits for foreground again. Actual background still closes/revokes. Disabled global voice, unsupported renderer, demo, concurrent ordinary recording or busy processing cannot start the microphone. On-device STT/language availability is checked at use; no cloud fallback.

Validation: source review, localization plutil, diff/work-register checks only. Added unrun wire regressions for two fresh catalogue GETs and exact closed context POST fields/authentication/no generic route. Existing native scene/turn-fence cancellation/expiry tests remain. No build, test compilation/execution, device permission/recording, live HTTP request, native render, install or GPU-application acceptance under explicit-build-only instruction. Last installed40447 unchanged; source pending in PR179, no merge. Next owner-requested build must verify all DTOs, actual iPad/Mac permission lifecycle and on-device recognition, fresh-help updates/failure, two-tap stop, timeout/delete races, source/scene/owner changes, no stale application/retry, popover anchoring and audio-session restoration.


## Transient permission interruptions — 25 October 2026

An actual isolated iPhone screen probe exposed a denial callback completing
before the deferred inactive-scene notification: the trace was active/mic0,
inactive/mic2/mode1, then active/mic2/mode0. The earlier awaitingPermission-only
exception therefore closed the visual visit. Original failing runs remain FAIL.
The local scene now survives a transient inactive phase while display-wake and
Metal rendering pause. Non-permission voice work is cancelled; the real OS
permission request may finish. Background, disappearance, owner/epoch/Session
loss and original visit expiry still close/revoke. No capture resumes itself.

Help has a live screen-active flag and original generation/owner/Session fences
across awaits. Inactivation discards its displayed/in-flight response; returning
to an admitted active screen rereads only an already-open help popover. No
background publication, static fallback, or new source lifetime is granted.
See VISUAL_INTERRUPTION_AND_SHARED_BULLETIN_20261025.md for bounded source and
qualification scope. The old historical build-only record above is preserved.
