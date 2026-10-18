# Requested voice preview, Apple consumer proposal 2026-10-17

Human asks for a Preview button under voice preference in DJ voice popover.
It must speak a short neutral phrase with the confirmed selected HA provider/voice
and deliver to client, configured HA speaker, or both according to confirmed
Profile announcement_output. Text-only hides voice preference, preview and local
autoplay; retained-voice explanation stays white. Never attach settings to a bubble.

At the original request, source had no voice-preview operation/source grant. Existing speech prepare3
accepts only accepted turn/Moment/entry references, never arbitrary caller text.
Do not fabricate a turn, mutate history, use an unrelated old bubble, call generic
HA TTS services directly or substitute the Apple system voice.

Requested producer-owned contract:
- Bounded private paired owner preview capability, no active Session requirement.
- Fixed neutral producer text localized in five supported languages; no arbitrary
  caller text or provider/voice overrides. Use current confirmed Profile/Session
  voice+gender and output. No intelligence/history/Session side effects.
- Exact settings/voice/owner fences, server clock expiry, redirect-free private
  client audio grant; same asset owner and configured provider as speech3.
- Target-aware replay-safe speaker dispatch, per-target outcomes, no rerouting an
  unavailable speaker and no false audible PASS. Text-only zero synthesis/output.
- API/source pin, request/response/error fixtures, settings/provider withdrawal,
  cancellation, duplicate press and both-target partial failure tests.

Existing sole Core writer must update canonical SYNC_PROMPTS/design first and
provide the actual wire contract. Apple can then implement typed transport and
one Preview/Stop control in the popover using the common playback coordinator.
No inactive Preview button is being shipped as if this capability already exists.

## 18 October follow-up: still not delivered

The owner again reports the agreed example missing from the renamed Speech
preferences pop-out. Current Core main `28153891` contains a `speech/preview`
producer and actual operation fixtures. However, its canonical SYNC/product
handoff still explicitly withholds the qualified producer pin/consumer rollout
and says the private installed HA-dev build predates it. This is source presence,
not a qualified installed function. The Apple configured-provider consumer and
Preview/Stop control are still absent.

The existing authorized Core chat was asked to complete that qualification and
HA-dev delivery and supply the exact contract/pin plus actual capability proof.
Apple inspected the existing paired operation and bounded private-audio/playback
owners for the follow-up. No new endpoint, fake contribution, arbitrary text or
Apple-voice substitution was added. The separate device-native Apple sample is
not completion of the configured HA voice preview request.
