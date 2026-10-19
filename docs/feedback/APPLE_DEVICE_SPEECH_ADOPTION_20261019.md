# Apple129: selection-bound device speech availability

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
that evidence. Saved output/voice preferences remain unchanged. Apple STT and
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
