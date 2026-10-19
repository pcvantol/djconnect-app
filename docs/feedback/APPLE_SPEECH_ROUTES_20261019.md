# Native speech route correction — 2026-10-19

The Apple client now selects Speech3 local_on_device for admitted contribution
replay and automatic playback when the device override is enabled. HA synthesis
and audio fetch are skipped for that local leg. Backend settings, exact accepted
source, revisions, segment admission, expiry and cancellation retain authority.
The HA voice picker is hidden without changing its saved Profile preference.
Disabling Apple STT and returning from menu interruptions refresh HA input
configuration; microphone capture still performs fresh admission.

The current Session card border follows the confirmed mood palette and increases
from 1.25 to 2.25 pt. Avatar glyph changes no longer use a moving symbol replacement;
a fixed centered canvas keeps activity animation independent of card layout.

## Validation

- 899 serial Swift tests passed, including switching Apple STT back to HA with
  status-only qualification and no audio upload.
- Native macOS build 40356 succeeded after all UI changes.
- Ordinary MacBook build 40355: user confirmed Apple STT recognition/submission
  and audible Apple TTS preview. HA STT returned a transcript from the recording.
- Ask DJ text and voice both returned HTTP 503 conversation_agent_scope_unqualified.
  This is a Core-owned agent configuration qualification failure after STT; no
  backend configuration, source or Profile preference was altered to bypass it.
- HA speaker output is unconfigured. Automatic response playback could not be
  qualified after the Ask DJ failure.
- Preview hung once and was force-quit; retry worked. No hang sample was captured.
- A separate 15:55:57 MacBook crash is confirmed as an AppKit constraints loop
  after album-art playback/favorite interaction. Its cause remains open.

Installed visual confirmation of the avatar/ring changes and acoustic completion
of admitted contribution playback remain required; build/tests are not that proof.
