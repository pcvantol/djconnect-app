# VibeCast Session locale handoff — Apple source Finalization

- **Assignment:** `DJC-VIBECAST-PI-OWNER-HANDOFF-V1-20261004`; the same selected
  first slice, with no second product pickup.
- **Decision:** Apple Session locale source merged and exact-main qualified;
  `PI_QUAL=OPEN` for the exact-candidate physical acceptance.
- **Branch:** `codex/vibecast-session-locale-finalization` from exact Apple
  source merge `f8e4bf9d8e4096983a04502245babd864abb04b2`.
- **Commit SHA:** Source merge
  `f8e4bf9d8e4096983a04502245babd864abb04b2`; reviewed source head
  `d7292b29851ce81f55c436b97e72e1ef8ddcc23a`.
- **Pull Request:** [Apple #93](https://github.com/pcvantol/djconnect-app/pull/93).
- **Predecessor:** [Apple PR #93](https://github.com/pcvantol/djconnect-app/pull/93)
  protected squash-merged from the independently reviewed head as exact main;
  the head and merge trees are identical.
- **Correction:** `DJConnectSessionStartRequest` now carries `language`, and
  the Apple app supplies `currentRequestLocale` when starting a Session. The
  exact Core main resolves that explicit value before the Assist fallback and
  freezes the supported language family in the backend-owned Runtime.
- **Validation:** The deterministic local suite passed all 401 tests; the
  unsigned iOS Simulator build, 976-key localization validation and 29-route
  HTTP contract validation passed. Independent source review found no
  actionable issue. Exact PR-head checks passed. Exact-main
  [CI](https://github.com/pcvantol/djconnect-app/actions/runs/37355321818),
  [Mac mini CI](https://github.com/pcvantol/djconnect-app/actions/runs/37355322019)
  and [post-merge evidence](https://github.com/pcvantol/djconnect-app/actions/runs/37355998819)
  passed for the merge SHA.
- **Automatic publication:** The unchanged
  `internal-ha-f8e4bf9d8e4096983a04502245babd864abb04b2` prerelease targets the
  merge SHA and contains one qualification JSON with SHA-256
  `ff90ebfadb70d29c167abee96fe4ffd900d347d461a7afecb99733388d96cde1`.
  The owner explicitly approved this bounded automatic internal publication
  and mandatory Finalization. No signing, public release, production
  deployment or workflow change occurred.
- **Physical acceptance boundary:** Core exact main
  `dfd78cca1f128285527631fdc4a06de560cad435` is installed in HA-dev. A signed
  iPhone candidate must still be built from exact Apple main and prove a real
  active Session, initial snapshot, nonterminal playback/Moment update visible
  on the physical portrait Pi, reconnect, Runtime-end cleanup, browser-token
  non-persistence and privacy boundaries. Source or browser tests do not
  replace this receipt. `PI_QUAL=OPEN` remains accurate.
- **Created documents:** This immutable locale-handoff Finalization report.
- **Updated documents:** `ENGINEERING_STATUS.md`, `MANAGEMENT_SUMMARY.md`,
  `REPOSITORY_STATUS.md` and `PROMPT_INDEX.md` were reconciled as one set. The
  earlier immutable Finalization records remain unchanged.
- **Repository State:** `MERGED_RECONCILED` after this governance-only
  Finalization merges. **Workspace State:** `WORKSPACE_READY` only after the
  mandatory cleanup of this slice's local branches.
- **Recommended next prompt:** Install the exact signed Apple main candidate,
  complete the same first-slice physical receipt, register `PI_QUAL=PASS` only
  on coherent evidence and stop. The Cast slice remains outside this increment.
