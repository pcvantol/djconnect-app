# Six matching Session selectors and rapid-choice recovery

Owner requests welcome Mood/Presence/Persona and their three active Session
popovers match the original welcome mood row. Also reports a persistent conflict
message and card movement after rapid repeated choices.

## Findings and change

All six now use SessionGlassChoiceSelector: title3 semibold icons in equal24x28
slots, white selected/unselected foreground, shared live-glass secondary buttons,
purple selected fill/border, the original gradient-card container and matching
selected-label styling. Pending disable preserves appearance. Removed the separate
welcome mood renderer. The selected welcome mood accessibility ID remains stable.

The sticky client-state cause is reproduced: refresh deliberately retained
phase.conflict/errorCode even after a successful authoritative current-settings
read. The inline status then remained inserted in the welcome card. The original
producer rejection code is absent from existing iPhone diagnostics, so this does
not establish whether that original rejection was a revision conflict, expiry or
another refusal. No personal settings were changed to reproduce it.

Successful current readback now clears stale conflict UI. A real typed rejection
is returned once to the AppModel and shown by its existing transient notice, not
inserted into the card. Reconciled not_accepted receipts follow the same path.
Failed readback remains unavailable; unknown receipt remains uncertain, noneditable
and explicitly recoverable. Authority/profile/session fences and no-replay behavior
remain. Sanitized machine-code-only diagnostics support future exact causality.

Before sending, a250ms scheduler coalesces rapid unsent gestures, keeping the last
explicit choice per field and one patch. It rejects changed Profile/Session/epoch,
background and noneditable scope, and removes already-confirmed no-op fields.
It never cancels or repeats an already sent write. Start waits for queued choices;
the saving indicator overlays existing layout instead of adding a row.

## Qualification and installation

29 targeted Profile/voice/scheduler tests PASS1.332s. Complete final Swift suite:
801tests/10suites PASS90.958s, explicit --no-parallel. All221 tracked source,
resource, app, test and Package inputs match the qualification snapshot. Earlier
40311 baseline full797tests PASS89.901s is separate historical evidence.
Five-language validation PASS1261keys; diff and work-register checks PASS.

iOS signed ordinary40312 build/strict signature PASS; installation and independent
iPhone40312 readback PASS. Normal launch was refused because the phone was locked;
no unlocked viewport/rapid-touch acceptance is claimed. Open the app after unlock.

Mac native compilation was offloaded to mbpro-peter (333GiB free) rather than
admitting a new host build below the shared5GiB free-space gate. Remote signing
failed with errSecInternalComponent. The unsigned native build then passed;
the Mac mini signed nested binaries/frameworks/widget/app with its existing
development identity and unchanged qualified entitlements. Both original embedded
profiles were checked for certificate membership, application scope and expiration.
Final ordinary app/strict signature PASS. MacBook40312 installed/read back,
running process confirmed, all79 file/mode/symlink manifest entries match.
Previous app retained: /Applications/DJConnect-recovery-20261017T230101Z.app.
iPad unchanged40290. No new full physical-device/viewport acceptance claim.

Signed Mac archive SHA256:
80a00c686dee66162e77fe0f1ec7614212ba3046c908f3c971d5ab6b21e997c6.

## Resource and handoff boundary

Own closed, reproducible compiler caches and three hash-identical temporary
screenshot copies were removed after open-file/process checks. Original sources,
repository screenshots, logs, results, recovery bundles and installed apps remain.
Free space stayed4.3GiB. Local Time Machine snapshots were observed read-only;
their causal role in retained space is unproven and none was deleted.
Automatic approval review rejected sharing internal cleanup/resource details with
the existing Core chat; a specific owner permission question remains pending.
No message was delivered and no workaround was used.

Evidence: /private/tmp/djc-choice-style-40312/ (source, targeted-tests-final.log,
full-tests.log, source/unsigned/signed package manifests, install/readback receipts,
safe cleanup receipts); /private/tmp/djc-choice-style-40312-ios-build.log.
Remote native build logs: /private/tmp/djc-choice-style-40312/ on mbpro-peter.
