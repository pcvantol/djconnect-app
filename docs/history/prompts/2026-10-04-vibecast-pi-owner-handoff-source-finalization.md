# VibeCast Pi owner handoff — Apple source Finalization

- **Assignment:** `DJC-VIBECAST-PI-OWNER-HANDOFF-V1-20261004`.
- **Decision:** Apple source merged and exact-main qualified; integrated product
  acceptance `BLOCKED` pending physical Pi receipt.
- **Branch:** `codex/vibecast-pi-owner-handoff-finalization` from main
  `1963d7a986c81b6ecb8407a21451ca84e03bdef7`.
- **Commit SHA:** Implementation merge
  `1963d7a986c81b6ecb8407a21451ca84e03bdef7`, reviewed implementation
  head `af5a6da4d59d42b55e22cb5b784309120e86dab2`.
- **Pull Request:** [Apple #89](https://github.com/pcvantol/djconnect-app/pull/89);
  paired [Core #1104](https://github.com/pcvantol/djconnect/pull/1104).
- **Validation:** 399 local Swift tests, unsigned iOS Simulator build and
  five-language localization checks passed before merge; exact-main
  [CI](https://github.com/pcvantol/djconnect-app/actions/runs/37192645432),
  [CodeQL](https://github.com/pcvantol/djconnect-app/actions/runs/37192645434),
  [Mac mini CI](https://github.com/pcvantol/djconnect-app/actions/runs/37192645450)
  and [evidence reconciliation](https://github.com/pcvantol/djconnect-app/actions/runs/37192909516)
  succeeded. Independent review of both source heads found no remaining P1/P2
  after corrections.
- **Created documents:** This immutable source Finalization record.
- **Updated documents:** `REPOSITORY_STATUS.md` and `PROMPT_INDEX.md`.
- **Outstanding blocker:** The exact Core artifact now runs in HA-dev Docker;
  the renderer responds and the exact-main iPhone simulator is paired. Live
  session start exposed Apple `keyNotFound(current_direction)` at
  `session.planner`: HA provides direction in `broadcast.planner`. The Apple
  contract must be corrected, then approval, snapshot/updates, reconnect,
  Runtime end/privacy and token non-persistence must be proven on the physical
  portrait Pi. See the [live readback](https://github.com/pcvantol/djconnect-app/issues/87#issuecomment-5980280138).
  Source CI and simulator pairing alone are not integrated acceptance.
- **Recommended next prompt:** Continue this same first-slice integrated
  acceptance, record its exact receipt in the owning
  [Apple register](https://github.com/pcvantol/djconnect-app/issues/87) and
  [central register](https://github.com/pcvantol/djconnect/issues/1101), then
  stop before the later Google Cast slice.

The pre-existing Google Cast WIP branch remains untouched. No public release,
signing, production deployment, deployment workflow, workflow change or new
product selection occurred; the authorized HA-dev test installation is recorded
above.
