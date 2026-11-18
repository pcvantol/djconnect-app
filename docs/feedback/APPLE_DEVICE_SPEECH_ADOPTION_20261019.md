# Apple129: selection-bound device speech availability

## Producer handoff refresh — 21 October 2026

Fresh read-only Core #1212 now confirms the protected Finalization pin
`ff1758344a863d2ec897b993c76b9c73a93c1631` and declares its HA-dev installation
with 206 integration files verified. This supersedes the historical installed-pin
statement below. That is producer-reported installed metadata evidence, not a
fresh Apple runtime/STT/TTS/hearing observation.

Independent local readback of that immutable producer pin confirms the original
15-case `ha-status-metadata.json` is byte-identical to the Apple fixture:
SHA-256 `111c71284630366d3fd8a19946013b853f78c6d02f784fa60cdf7596ebef4f6b`.
No fixture or protocol update is needed for this handoff. The consumer contract
at that pin hashes to `074892c1aacfd7ea18c4fa425c296840fea9a44a8c99d0b7d03e52e2d33bfdee`.
Raw readback: `/private/tmp/djc-apple129-producer-readback-20261021.json`.
No unchanged green model checks were rerun, audio generated, OS permission queried
or backend mutated. Native route presentation, actual speech and physical
acceptance remain separate work; Apple129 is not closed by this reconciliation.

Source: https://github.com/pcvantol/djconnect/issues/1212

Bounded consumer slice for Core source1221, merge
604b80f806425cb53165a17faf783bfd6248af17. The original fifteen-case metadata
receipt is imported byte-for-byte as Tests/Fixtures/device-speech-core-604b80f8.json.
Core DEVICE_SPEECH_CAPABILITIES_V1.md is authority. Metadata is configuration
qualification, never completed recognition, synthesis, playback or audibility.
Core's last declared HA-dev installed pin remains f8b28d2b; this new producer's
installation and actual native speech acceptance remain separate and OPEN.

Pair/status DTOs expose optional schema1 discovery. Legacy endpoint support
booleans do not qualify HA input/output. Closed authority/version, supported
locale family, configured/available state and independent target checks qualify
routes; operational retry delay is separate from configuration state. Original
failure observations with elapsed backoff may retry. No gender is invented.

Presentation retains only a RAM snapshot bound to installation, endpoints,
paired credential, authorized Profile and device language. Each in-flight read
also fences the response epoch. Failed/missing status
withdraws availability. HA input and output actions are unavailable without
that evidence. Saved output/voice preferences remain unchanged. The Profile output picker remains
governed by backend-advertised choices, including during runtime outages/backoff;
only execution controls use ephemeral device availability. Apple STT and
native TTS preview/Watch preparation retain their independent existing admission.
Explicit text_only and prepare3/source fences remain authoritative.

HA capture, final ordinary/profile audio submission, contribution replay/autoplay
prepared-but-inactive HA touch synthesis/audio and Watch-proxied HA audio refresh through the same paired client's existing
status route before use. The read bypasses caching, checks installation/locale
and cancellation, then applies current UI/context checks before crossing the
speech boundary. It performs no provider/model/audio work. There is no silent
fallback between Apple and HA. Native Watch speech preparation is not gated by
HA synthesis availability. Interactive Watch HA input checks its own current
registration/token and installation, without requiring the phone to be foreground
or importing its metadata into the phone Profile presentation.

Validation and delivery evidence is kept in build/qualification/device-speech-40354.
Source tests/builds do not establish installed HA support, real microphone/STT,
voice hearing or multi-device acceptance. Apple129 remains open for that proof.

## Ask DJ text and deferred autoplay

The pinned Core604b80f8 common dialogue path never synthesizes from a text request:
ask_dj/__init__.py669-678 returns accepted_reference/deferred for current_turn;
ask_dj/service.py441-461 uses requested audio only as autoplay eligibility on the
accepted source. Profile settings3 always negotiates speech_contract_version3.
That intent must survive provider loss so actual prepare3 can reauthorize it;
the consumer's prepare3 route is freshly gated. The existing autoplay tests and
Profile payload test preserve this behavior without treating the flag as audio.

Unnegotiated compatibility text has no such producer guarantee. Phone fallback
and Watch text (including old companion requests) therefore explicitly request
never for inline audio, leaving text delivery intact and saved preferences alone.
Native/manual source replay remains separately admitted. The obsolete private
legacy audio-mode reader is retired; no stored user preference is erased.
