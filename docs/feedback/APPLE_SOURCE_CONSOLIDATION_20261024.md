# Apple source consolidation — 24 October 2026

The owner resumed the existing Apple lane and explicitly authorized the open
merge work to main. This increment consolidates the already reviewed Bulletin,
contextual Help and ActivityKit token-custody changes; it adds no new platform
capability or runtime permission.

## Original source and review binding

Base: protected main `89c0e332deffa1ec58cc0ce82535430a555dea5f`.
The conflict-free integration commit is
`2d06f9aa654b60246d1d9f70a24779f15fbc3ebd`, tree
`41a59b3ddf005ba04f6c188c754bd12282ac9d90`.

- PR191, `2297089053691eaefcdbe3ae807a07b360f3e52f`: late ActivityKit token
  callbacks cannot overwrite a replacement or revive a dismissed/ended local
  presentation. Native ownership is recorded before immediate token observation.
- PR186, `8d5bafd644bbad48bb007e7b57e4e466c239cf7e`: Bulletin source links expose
  the original headline to accessibility while retaining provider/license and
  destination. Native qualification consumes the protected Core fixture.
- PR187, `3feaf46db27055bbac8044ca797316ea51285ae9`: Help has an explicit close
  control and revalidates at original track expiry; both conversation surfaces
  share the existing three-suggestion presentation and interaction qualification.

The 25 original paths are disjoint. Every integrated Git blob is identical to
its independently reviewed original; main's later VibeCast fixes are retained.
The independent bounded integration review found no new blocking interaction.
This report is the only additional path beyond those 25; exact final-commit
readback and normal protected CI remain separate from the integration review.

PR185 is closed as superseded by protected PR188, `5aca8c85ff27061342cac8499f3493d32d2bb6c4`.
All four older paths are already present there. The admission and tests also
contain the corrected per-field monotonic-deadline history, higher-sequence and
wall-rollback/ABA regressions. Fresh independent object comparison confirmed
supersedence; the uncorrected older head is not merged again. Its branch and
original evidence remain preserved.

## Actual validation of the combined source

Both original parent processes completed with exit 0 on `2d06f9a`:

- Serial Swift package run: 1,249 Swift Testing cases in 26 suites; 86 XCTest
  cases, five explicit skips and no failures.
- Native unsigned macOS Core test target with code coverage: 1,249 Swift Testing
  cases in 26 suites; 86 XCTest cases, five explicit skips and no failures.
- Localization validation: 1,447 keys. Apple work-register validation passes.
- Local contract security validation passes; HTTP covers 29 routes and WebSocket
  covers 18 messages/16 advertised routes. These are synthetic local servers,
  not an installed HA/provider qualification. The initial sandbox-denied
  loopback attempt is retained separately from the successful run.

The previous main190 coverage failure remains a failed original run. A fresh
minimal native framework probe passed one XCTest and one Swift Testing case;
the subsequent combined product run also passed. Neither establishes a root
cause or retroactively qualifies the failed run. No security reset, permission
change or testmanager/runner restart was performed. Main after this source merge
must produce its own original CI, coverage and formal evidence before Finalization.

The fresh canonical host verification exited 0/MATCH before source mutation.
The exact owner-approved expired verification group was preserved outside Git:
Core owns its 254-file action; Apple moved only the 99 receiver files on the
same volume, retaining all hashes, inodes, link counts and original times. No
tracked source, WIP, history or pairing state was deleted.

## Explicit remaining product gates

- Help's actual server catalogue remains unqualified; client presentation tests
  do not qualify or activate it. Failed paid producer runs remain failed and
  confer no new budget.
- Bulletin's actual paired Planner publication, physical narration and installed
  accessibility/audio acceptance remain open. It uses the existing Moment and
  autoplay policy; there is no client RSS/news generator or separate news UI.
- Widget/Activity push still requires its actual original owner/credential,
  registration factory and provider/native delivery. The remote Activity
  content/rights/clock profile is not admitted by local token custody or widget
  continuation. Simulator injection failed and is not a WidgetKit delivery PASS.
- VibeCast retains open key bootstrap/migration/factory and complete physical
  A/HA/B/receiver/render/revoke qualification. The owner selected a physical
  iPhone17Pro with HA-dev; its connection is deferred until the owner attaches it.
- No ordinary version bump, device installation, provider key/enrolment, runtime
  gate opening, remote Activity start or production deployment is part of this
  source consolidation. Subsequent source corrections and Finalization retain
  their own exact reviews and original qualification requirements.
