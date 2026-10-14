# Apple Presence final pre-delivery qualification — 2026-10-14

This is a pre-delivery checkpoint, not completed Finalization.

Same sole writer and branch `codex/apple-dj-presence-v1`. Source candidate
`6bb90167cbc0d751424701f89c86b7a2e9bfed0c`, tree
`396e27faa7895b89c8f1919a8731551d4dccf202`, base
`a522596f5c232cb0f73351146a34392c9a0d711f`. Existing 40021 fixes,
installed snapshot, settings, backups and both untracked project copies remain.

## Current evidence

- Full frozen 523-file qualification input: 514 shared Swift tests PASS.
  The first 69-file export lacked repository workflows/plists/Tools fixtures,
  failed 11 checks and is retained as failed preparation, not PASS.
- Unsigned Mac and iOS Simulator builds PASS. All compiled Sources files in
  the build input match this candidate byte-for-byte. No signing or installation.
- 1081 localization keys, 29 HTTP routes, 18 WebSocket messages/16 advertised
  routes and fixture security PASS. Postman validator is absent; existing CI
  explicitly skips this optional gate. The accidental direct local invocation
  failed MODULE_NOT_FOUND and is not counted as a validation PASS.
- Fresh native ordinary-paired Core five-position test PASS on own iPhone
  (NL) and iPad (EN, largest accessibility text, landscape), one test each,
  zero failures. Native confirmed values/revisions, pending versus confirmed,
  paused playback and Session/Mood/user-token invariance are asserted.
  Product Sources match the candidate; the existing test bundle reuses the
  unchanged Presence test function. Prior five-language receipts remain
  separately bound to their original candidates.
- Full-display iPad capture independently reviewed: bounded largest-text
  containment/readability GO. It captures a scroll position, not all five
  choices and confirmation at once. No cropped XCTest image is promoted.
- Independent technical/privacy/concurrency and source UX reviews give bounded
  GO for exact `6bb9016`/tree above. Mac layout/keyboard, current output-card
  contrast and native Play Now interaction remain separate open evidence.

The portable [qualification record](apple-presence-predelivery/qualification-6bb9016.json)
binds private logs/input manifests/native summaries by hashes without retaining
human screenshots, account data or credentials in Git.

## Remaining gates and queue

Mandatory Mac native proof is blocked before application start by the invalid
SDK test-runner signature. The earlier automatic approval rejection is retained;
no repair/bypass has executed. A narrow Owner permission request remains pending.
Native proof must use a distinct temporary app identity to preserve the ordinary
installed app and its process/settings. Do not reuse an older proof app as
current-candidate acceptance.

No source PR, protected merge, exact-main artifact readback or documentary
Finalization has occurred for Presence. New exact-SHA Owner Authorization is
required for the actual source and then separate Finalization candidates; earlier
PR105/106 grants are not reused. Remote main remains the reconciled 40021 base.

The Owner now authorizes automatic pickup of the next selected queue item AFTER
this assignment completes, superseding the original single-slice stop boundary.
This does not grant signing, installation, Core writes or unbound publication.
The selected hybrid transport consumer still requires its real producer contract
and fresh admission. Do not silently start another slice or second writer while
Presence remains unfinished.
