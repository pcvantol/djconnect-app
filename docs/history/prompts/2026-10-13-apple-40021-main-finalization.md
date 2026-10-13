# Apple build40021 source — separate Finalization snapshot

Owner explicitly requested the preserved40021 changes merged to main before the
selected Presence slice. [Source PR #105](https://github.com/pcvantol/djconnect-app/pull/105)
protected merged reviewed head `6edfcb0c1dddde38398d23dbee93a6b557b742e2` as
`357251cedc4b78a4f9d5b446d3cdafc610cedc40`; both have tree
`d6ae93ee6fd3eb64a1c9ab6756f17cac87c9dd35`. Parent main was
`11ecab47bff28eaf6d7231f63477d893c0e91cb7`.

## Objective and source outcome

All previously local Apple40021 followups now belong to protected main. They
preserve Session/archive presentation, glass controls, floating Ask DJ, native
typing/caret and Mood-crash fixes, Profile Music DNA consent/Discover loading,
and the bounded cancellation/rejection and Broadcast HTTP recovery changes.
Independent review additionally corrected HTTP auth/Profile-denial withdrawal
through the existing paired-live callback, clearing private state and fencing
late old history. No new transport controller or Core contract was introduced.

This documentary branch, `codex/apple-40021-finalization`, starts from the exact
source main. It changes rolling status, handoff, prompt history and portable
qualification records only; production source/test/project bytes stay unchanged.
Original Apple WIP, sole writer and earlier closed assignments are preserved.

## Verification and protected delivery

498 shared tests, fresh unsigned Mac/iOS Simulator builds, five languages with
1065 keys,29 HTTP routes,18 WebSocket messages/16 advertised routes and fixture
security PASS. The native AppModel HTTP withdrawal regression covers both
unauthorized and invalid_profile and rejects a delayed old history response.
Independent technical/privacy and UX AI source reviews give bounded GO on the
exact reviewed head. Earlier compiler metadata and old-cache preparation
failures are retained; the final fresh builds pass without source rollback.

Premerge CI38438848001, Trusted Delivery38438847924 and official exact-head
Owner Authorization38439052617 PASS. Owner authorization was explicitly
provided in the writer chat for that exact source SHA. Source-main
CI/coverage38439881390 and automatic durable evidence38441132690 PASS.
Downloaded coverage, runner and owner ZIP hashes match GitHub metadata;
coverage and main runner records bind exact source-main357251c. Premerge runner
evidence uses GitHub's temporary PR merge SHA and is not mislabeled main.

Published formal asset SHA256
`e88a7deb7a705520fce9ceb9569041a0b2136e306fbb3c68519c6455667432ba`
matches GitHub metadata. Canonical integrity
`33cad4dcf1cff06067adb9d10499f616df22b48ad0bab9813579e59bd48957d5`
and all12 formal required checks/redaction validate under pinned policy
`ebbb35f038a7a3c7d46c12660968bcd50eb67580`.
See [portable readback](../../verification/40021-source-finalization/source-main-readback.json)
and the unchanged [formal source record](../../verification/40021-source-finalization/formal-source-evidence.json).

The optional TDE observe workflow is explicitly nonblocking and did not qualify:
runner Python3.9 is below published TDE1.1.1 minimum3.11. No workflow/runner
change, waiver of a required check or TDE assessment PASS is claimed.

## Installed baseline and recovery

The Mac40021 installation task was already officially closed. Its preserved
source manifest SHA256
`11c6f3e85edf43262c6398c0ab765f158d7227f7bd8059cedbd16c89828f7f5a`
matched all514 files at fresh admission, zero mismatches. Actual installed tracked
tree `1ce640a530307de6e80bc51c48a4d2fa1e24940f` is preserved as local
`7baa9a4928585e83ddd7d5f59e517c810df54dd7`; HEADffc6588 alone was not the
installed source. The subsequent review privacy correction is not installed.

Local installation archives, signed binding, source patch/snapshot, Mac mini
backup/preferences/receipt, saved MacBook receipt and MacBook40020 backup remain
unchanged in their existing recovery locations. No install/signing or pairing
reset ran. The original primary dirty checkout, recovery branches and Finder
project duplicates remain preserved. Cleanup must retain their explicit recovery
purpose and cannot force-delete them as stale branches.

## Qualification and remaining boundaries

Source delivery: bounded PASS, with separately observed TDE limitation.
Documentary Finalization is prepared for review; execution and reconciliation
remain pending its own grant/merge/readback. Product Acceptance remains PARTIAL. Physical scrolling,
VoiceOver, fullscreen hover, microphone/provider/voice and actual LAN/cellular
transition acceptance are not inferred from software tests or old demo captures.
Favorite/top artist strips lack real thumbnails because the current name/value
producer contract supplies no image field. Full local action WebSocket support
and parity remain in the separate selected transport workpackage; the audited
issuer404 is not resolved by this preservation merge.

Finalization has its own exact-candidate publication/protected-merge grant and
readback. Until that succeeds, state is MERGED_UNRECONCILED. Only after its
exact-main/formal verification and safe cleanup may MERGED_RECONCILED and
WORKSPACE_READY be declared in the terminal owning-register receipt. This record
does not preclaim the future merge SHA or artifact results.

## Program and bounded continuation

Generation2, DJConnect Product Development, Apple native client. Current
increment is40021 source Finalization. Canonical owner queue remains in
[Apple #87](https://github.com/pcvantol/djconnect-app/issues/87) and Core's maintained
roadmap; this repository creates no second canonical roadmap.

| Existing work | Current evidence/status | Gate |
| --- | --- | --- |
| Apple DJ presence control | Planned; selected in pickup6150506243, Core#1150/#1151 delivered | Fresh post-Finalization ACK/base/branch, then only this slice |
| Apple hybrid transport adoption | Selected dependent workpackage6149955349 | Precise future Core contract and own admission |
| Apple Forecast view | Existing Planned consumer | Own selection and producer/native qualification |
| Apple history summary | Existing Planned consumer; Core source#1162/#1163 delivered | Own selection and admission |

This is a tentative evidence-backed projection, not reprioritization or dispatch.
Recommended next action: after this exact Finalization finishes, continue only
the already selected `DJC-APPLE-DJ-PRESENCE-V1-20261011`, same writer, actual new
main/tree/WIP admission, five-state native control using existing Core v1. No
Presence source has started in this increment. No Core writes, transport rebuild,
Forecast/summary implementation, installation, HA/Pages/public release or new
provider route is included.
