# Ask DJ text replay unavailable — HA-dev

Owner reports that the bottom speech-play button under an Ask DJ playlist answer
shows “Niet beschikbaar”. Requested operation is reading the answer text only,
not starting one of its playlists. Screenshot21:22; standing environment HA-dev.

Read only the existing iPhone app diagnostic file, not its token/preferences or
conversation store. Five retained events at21:21:12/14/14/15/57 show
`phase=prepare`, `reason=source_processor_not_qualified`. No new speech request,
question replay, playlist playback, clear, pairing or provider change was issued.
Private raw log and filtered receipt remain under
`/private/tmp/djc-tts-text-replay-diagnosis/`; do not publish the raw log.

Consumer trace: SharedDJSpeechActions selects the exact retained-entry or granted
speech reference. playSharedDJSpeech calls contract3 prepare, then the functional
unavailable/prepared-source branch records this reason and sets local delivery
unavailable. That branch returns before audio_fetch or AVAudioPlayer creation.
Thus this evidence identifies preparation rejection, not a playback-button mixup
or device audio-output failure. Exact HTTP status and unique per-turn correlation
are not recorded in these events and are not claimed.

Read-only Core source has two producer branches for this reason: unqualified
processor_basis, or local-only source admission with a processor outside
qualified_local. Which branch applies to this stored answer remains a producer
investigation. Existing Core writer received the filtered phase/reason/times.
The client must not fabricate a grant, alter accepted text/hash, substitute a
voice provider or bypass source admission. No backend contract change or second
writer was introduced.

Status: OPEN, original reason observed; server source/provider qualification
correction and positive installed text-replay acceptance still required. No
source/runtime correction, new build, test PASS or audio acceptance is claimed
for this diagnostic increment.

Core subsequently reports a version gap: HA-dev177 installed files match
main6a3adbc8; the accepted-text/provider correction is in uninstalled Draft1197.
The candidate retains source/settings/lifecycle fences and changes the accepted
source/provider path. This is Core lane source/deployment readback, not installed
acceptance by Apple. The original playlist answer's exact admission basis is
still unknown, so candidate publication/deployment alone is not claimed to solve
every occurrence. Core release remains subject to its existing quality gate.
