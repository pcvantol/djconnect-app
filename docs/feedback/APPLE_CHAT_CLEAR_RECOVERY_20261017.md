# Ask DJ offline after clearing chat — 17 October 2026

The owner reported that clearing Ask DJ chat displays Ask DJ offline and disables
the composer while the HA connection remains available.

Root cause: clearExistingHistory validates the same Profile, invalidates old
content and restores the owner. Applying the clear response then sees its higher
clear_revision and calls suspend again, withdrawing that just-confirmed owner.
The same revision-driven invalidation also affects clears observed from another
client and admitted responses carrying a newer clear revision.

The correction invalidates content, pending work, playback/result leases and the
response epoch while retaining the admitted Profile owner on these clear paths.
Actual Profile/authentication failures, scope changes and lifecycle suspension
still use authority-withdrawing suspend. Revisions continue to reject old
history; the correction does not synthesize connection state or bypass pairing.

Validation: two clear scenarios (local toolbar action and remote clear revision)
retain composer eligibility, reject pre-clear history and send a new question
through the real HTTP client/decoder fixture. Nine existing authority-failure
scenarios still withdraw private state and recover correctly. Targeted2tests/
11cases PASS1.078s. Full Swift786tests/10suites PASS87.359s, serial, isolated
native builder. This is source/fixture proof, not physical iPad acceptance.

The change is on the existing Apple follow-up branch with the requested neutral
system launch and history-row play presentation. Core history replay actions
remain a separate named producer dependency. No backend change is needed for
the clear-state correction. Device installation is recorded separately after
actual success/readback; public merge and formal source Finalization are not
claimed by this document.
