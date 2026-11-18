# Configured HA TTS provider follow-up

Owner request (2026-10-17): remove the Core local-provider restriction for speaking
already accepted DJ contributions and answers. Use whichever TTS provider the
user configured in HA (OpenAI, Piper, Nabu Casa or another supported HA entity).
Do not change the selected Assist pipeline/provider as a workaround.

Existing Core writer is active in Codex task `Pak VibeCast shared renderer op`
(`01a120e2-b557-76c3-8568-129dbce2f2d2`), currently in
`/private/tmp/djc-askdj-golden-release/source`. No second Core writer was started
and no Core product/configuration/deployment file was changed by Apple.
The owner explicitly authorized messaging that existing task. The complete
request and device evidence were sent successfully on2026-10-17; Core delivery
and the follow-up Spotify/OpenAI device qualification remain pending.

Actual HA-dev/iPhone evidence: prepare3 returned unavailable with reason
`source_processor_not_qualified` for the current Spotify-backed Moment using
the selected `tts.openai_tts` pipeline. This is a producer decision, not an
AVAudioPlayer error. Installed `session_speech.py` requires `qualified_local`
for `spotify_owner_local_read_v1` and `retained_owner_local_read_v1` after resolving
the configured provider. That source-specific locality restriction is the
concrete owner-requested change. Provider compatibility itself already uses the
configured HA TTS entity; unknown entities are not generally forbidden.

Before code, update canonical SYNC_PROMPTS.md and the owning speech/source-policy
contract/design in the Core writer. Distinguish literal synthesis of accepted
owner-visible text from new LLM narration, recommendation or disclosure to other
owners. Preserve exact reference/text, profile authority, settings3/output,
provider withdrawal, source deletion, retention, private short audio grants and
bounded transport. Do not turn this into arbitrary caller text or a provider
fallback. Cover both live Moment and retained/previous-session answers.

Required regression: configured cloud TTS can synthesize the accepted DJ text
where locality used to be the sole refusal; configured local provider still
works; unavailable/missing provider, stale references, text_only, owner/privacy
withdrawal and expired sources remain rejected. Qualify real HA-dev with current
Apple manual prepare3, byte retrieval and actual output. OpenAI/Piper/Nabu Casa
fixture compatibility and physically tested providers must be reported separately.
No new wire fields are assumed by Apple; notify the existing Apple writer if the
producer contract/fixtures or accepted source descriptors change.

Apple 40218 separately fixes a real local timing bug: the later minted Core audio
expiry may exceed an already running 300-second attempt by preparation time.
Cap to min(prepared expiry, original local attempt expiry), never extend it.
On iPhone a retained CC0 Wikidata contribution now passes actual player start,
stop and replay (native XCTest, not human audible acceptance). Playback-observation
rows no longer expose unsupported speech actions. Neither fix removes the Core
provider gate described above.

Provider-default interoperability note sent under the same authorization:
configured_processor can emit null voice_id/voice_name when a provider has no
voice inventory; current Apple Voice decoder requires strings and speechAudio
requires nonempty voiceID. Core must explicitly hand off the permitted default
representation/nullability and provider/voice fence with fixtures. Do not invent
a voice or silently make the provider unavailable. Consumer adoption of this
clarified contract remains part of follow-up, not an already proven any-provider
claim.

Owner added Chatterbox as intended future provider: a locally hosted TTS server
with the user's own voice. Added this requirement to the same authorized Core
handoff. Keep HA/provider/voice contract neutral; do not bake a fixed list into
Apple or substitute a voice because inventory is absent. This does not claim a
Chatterbox adapter is already present or authorize an installation from Apple.

Apple40221 compatibility implemented from actual producer null/default semantics:
voice_id/voice_name may be absent only as metadata, with qualified selection
requiring a nonempty actual ID or explicit voice_selection=provider_default.
Named provider/voice matching remains exact. Both prepare3 validation and private
speechAudio admit the provider default; no arbitrary voice is synthesized locally.
Tests exercise positive null/default prepare+real private WAV byte fetch and
negative null/configured selection, in addition to existing settings/provider/
text/fence/source/format tests. Thirty related tests pass; fifteen owning settings
tests with added byte-fetch proof pass. These are fixture/controller results,
not real Chatterbox/NabuCasa/provider-default hardware claims.
