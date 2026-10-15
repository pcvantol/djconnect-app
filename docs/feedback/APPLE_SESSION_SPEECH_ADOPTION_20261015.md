# Apple Session Speech adoption — initial contract adapter

User directly requested the next selected lane step after artwork increments
26eb8e2/44bdb94. Same sole writer and branch; outstanding real-HA/native/hardware
artwork acceptance remains separately OPEN, not retroactively closed.

## Exact initial producer

Qualified local/unpublished Core candidate6b26158ad4b696c8b5a391eaa72c29ceb20f92a6,
runtimec39a4f8020fb21a9d40da22af0928a420c97a44a. Imported the exact
qualified-runtime.http.json fixture as Tests/Fixtures/session-speech-core-6b26158a.json.
SHA2568c2fb025d7e93d43220276a915b3964ce962e653c20ecd9f3a7e02a3fb15646a matches
Apple-lane handoff6197254132. This is not published main or installed availability.

## Implemented bounded increment

Typed exact turn/Moment/entry references; ephemeral descriptors preserve original
text/revisions/Persona/locale/attribution and deadline. Mixed/oversized references,
changed UTF-8 text, segment bounds/order and withdrawn/expired descriptors cannot
execute. Optional provider voice options hide unsupported gender choices.

Added private paired POST voice-options/prepare/audio adapters. Strict speech
routes use only their specified top-level device_id/client_type and versioned
payload, without the legacy generic API envelope or a token in the JSON body.
Transport has no URLCache/cookies/credential store, refuses redirects, limits two
concurrent transfers, bounds JSON64KiB/audio2MiB and complete requests22s. Actual
RIFF PCM structure is checked. Missing404/410 is separate from authentication401
and policy403; none of these adapter methods mutates pairing. No private GET,
resubmitted Ask DJ question/music action, network voice fallback or persistence.

These APIs are not yet called by production UI. No automatic speech-contract
opt-in was enabled. Shared player/Listen/Stop/autoplay queue, live Persona CAS/UI,
WAV opt-in, native voice selection and audible acceptance remain OPEN.

Seven focused contract/URLSession tests PASS against the exact fixture and an
explicit synthetic byte transport. Full612 shared tests PASS:
/private/tmp/djc-speech-40092-regression.log. iOS/Watch and signed Mac builds PASS:
/private/tmp/djc-speech-40092-ios.log and /private/tmp/djc-speech-40092-mac.log.
No install, source push, PR, protected publication or native/audible PASS.

## Confirmed producer discrepancy and pending replacement pin

The initial accepted_reply descriptor lists only local_on_device, but the same
fixture subsequently prepares ha_configured for that exact turn. Apple reported
this concrete mismatch to the existing authorized Core task and retains the
conservative original-processors check; no silent client allowance was added.

Core confirmed the finding against6b26158a and reports a local fix in its same
Speech slice: available turn/live/retained descriptors advertise permitted
prepare attempts [local_on_device,ha_configured], plus
processor_qualification_required:true. Explicit paired preparation must still
qualify source/provider/voice/locale; it may return unavailable/processors[]
without fallback. Reads perform no provider/TTS work. The list is not a ready-
audio grant. Core reports107 owning tests PASS, but its exact replacement pin,
actual HA fixture and re-review have NOT yet been handed to Apple.

Next: receive and checksum the new exact producer fixture/pin, adopt that declared
meaning explicitly and add regression coverage for advertised attempt versus
qualified/denied prepared output. Do not reinterpret the old6b/c39 fixture or claim
the new producer delivered. Core's separate documentary Finalization1176 does
not constitute published Speech source. Continue shared native player only within
these authority boundaries; no widget/passive/private-content rights follow.
