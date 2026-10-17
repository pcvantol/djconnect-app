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

## 40093 — exact processor-advertisement correction adopted

Received Core's exact independently reviewed LOCAL/UNPUBLISHED candidate
323a3db47d98cc035a0d10ce3936edb3e01406f8, runtimefix
27c22afdaca8a7a701ba839928c9d16ed8acd794. Imported its actual HTTP fixture as
Tests/Fixtures/session-speech-processor-core-323a3db4.json; SHA256
91458a38cd1c13ecbefdb482a6068b45e1168771cd92b8ca4ead16812e06bfed matches the
handoff. All143 source hashes in that fixture match the exact runtime Git object,
zero mismatches. This does not independently rerun Core's HA qualification.

Canonical contract on this candidate explicitly defines processors as permitted
prepare attempts and processor_qualification_required:true. Apple now decodes that
field, distinguishes the advertised attempt from ready audio, and uses the new
accepted descriptor for its HA-first-prepare transport test. Explicit preparation
must still preserve exact text/revisions/Persona/locale/attribution/deadline and
produce ready effective-voice/audio metadata before download. Denial has empty
processors/segments and no audio reference. There is no automatic provider/voice
fallback. Old6b descriptors still cannot attempt an unadvertised HA route; the
historical fixture is retained unchanged. A previously advertised legacy route
may receive the additive qualification-required flag in a prepared response;
that never adds a route to the original descriptor.

Eight focused tests PASS, including first HA preparation from the corrected
accepted_reply, no audio download from an initial advertisement, no widening of
old6b input and the exact provider-gender denial. Full-suite and native-target
build results are recorded below/in the feedback status ledger. No UI caller,
JSON/WAV opt-in, playback/autoplay or installation was enabled. Native/audible
acceptance and the final protected-main producer pin remain OPEN.

## Shared local playback ownership — 40094

Added one device-local playback coordinator and connected both existing response
AVPlayer and demo AVSpeechSynthesizer output to it. Every request owns a distinct
ticket, including repeated requests for the same URL. Stop invalidates that ticket
before clearing output. The manual replay action acquires ownership synchronously,
before scheduling its Task. Checks after audio-session suspension suppress stopped
or replaced requests; obsolete completion/error handlers cannot clear newer output
or display a stale failure. Output replacement stops both engines. Pairing loss,
Profile-conversation authority revocation and active-session replacement/end also
invalidate ownership. An original optional deadline stops output automatically;
legacy playback retains its 120-second safety bound. No content is persisted.

This is actual integration with the existing player, not yet execution of the new
private Speech adapter. Core qualification, prepared audio/local voice selection,
new manual Listen UI, autoplay publication deduplication, Persona CAS and native
or audible acceptance remain OPEN. No Speech opt-in, install or publication.

Validation: all619 shared tests PASS, including six coordinator tests and the
Stop-before-queued-task-start race. iOS/Watch and signed Mac builds PASS. Logs:
`/private/tmp/djc-speech-40094-{regression,ios,mac}.log`. All three changed code/test
files exactly match the isolated build snapshot. These are source/build and
modeled scheduling results, not installed/audible acceptance.
