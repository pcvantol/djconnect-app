# VibeCast Pi Session decoder — Apple source Finalization

- **Assignment:** `DJC-VIBECAST-PI-OWNER-HANDOFF-V1-20261004`; the same selected
  first slice, with no second product pickup.
- **Decision:** Apple decoder source merged and exact-main qualified;
  `PI_QUAL=OPEN` for the separate physical nonterminal-update receipt.
- **Branch:** `codex/vibecast-pi-session-decoder-finalization` from exact Apple
  source merge `29f3ad55d74c155fbab51c039358cea871d4c512`.
- **Commit SHA:** Source merge
  `29f3ad55d74c155fbab51c039358cea871d4c512`; reviewed source head
  `6221beacb178bd26e614411c32c97ee646138165`.
- **Pull Request:** [Apple #91](https://github.com/pcvantol/djconnect-app/pull/91).
- **Predecessor:** [Apple PR #91](https://github.com/pcvantol/djconnect-app/pull/91)
  protected squash-merged from independently reviewed head
  `6221beacb178bd26e614411c32c97ee646138165` as
  `29f3ad55d74c155fbab51c039358cea871d4c512`.
- **Correction:** The HA-owned current direction is under
  `session.broadcast.planner.current_direction`. Apple no longer requires the
  absent `session.planner.current_direction`; the iPhone Session UI reads the
  broadcast field. The backend-shaped regression test prevents recurrence.
- **Validation:** Clean local Swift test run passed all 400 tests; unsigned iPhone
  18 Pro Simulator build passed. Exact PR-head
  [CI](https://github.com/pcvantol/djconnect-app/actions/runs/37207756250)
  and all applicable checks passed. Independent read-only source review found
  no P1/P2. Exact-main
  [CI](https://github.com/pcvantol/djconnect-app/actions/runs/37214330425),
  [Mac mini CI](https://github.com/pcvantol/djconnect-app/actions/runs/37214330165)
  and [post-merge evidence](https://github.com/pcvantol/djconnect-app/actions/runs/37214736801)
  passed for the merge SHA; the exact-main reconciliation status is success.
- **Automatic publication:** The unchanged `internal-ha-29f3ad55d74c155fbab51c039358cea871d4c512`
  prerelease targets the merge SHA and contains one qualification JSON. The
  owner explicitly approved this bounded automatic internal publication and
  the mandatory Finalization. No signing, public release, production deployment
  or workflow change occurred.
- **Physical reference receipt:** A precommit local candidate on the paired
  iPhone 18 Pro Simulator approved an ephemeral code on the actual 1200×1920
  Raspberry Pi. The Pi rendered the
  active Broadcast snapshot. During a controlled pause of the test-only
  Chromium network process, the WebSocket closed, a new socket and handshake
  appeared, a frame arrived and the same Session returned to Live. Ending the
  Session produced Idle and cleared the DJ Moment. The page URL and both browser
  storage areas had no token; a fresh temporary browser profile required a new
  code. The temporary Pi browser/profile were removed after testing. The live
  report predates reviewed head `6221beacb178bd26e614411c32c97ee646138165`
  and does not bind the installed binary to that head or the merge SHA; the
  exact-main evidence above qualifies the source, not this physical subset.
- **Outstanding blocker:** HA-dev's paired Pi-QA profile and Spotify-
  authorized iOS profile both have Profile Platform default backend
  `later_manual`. The Spotify-authorized iOS entry has stored OAuth and already
  selects `spotify_direct` in config-entry options, but the normal backend
  options flow does not update Profile Platform preferences or register a
  Spotify Direct backend there. After the owner's bounded HA-dev test approval
  and sign-in, the normal options were inspected and closed without submission;
  no HA-dev setting was changed. Session start resolves the profile backend,
  so no separate nonterminal track, DJ Moment or Session Flow update was
  produced during a live active Session. `PI_QUAL=OPEN`; a supported,
  reversible Profile Platform backend binding and then a physical Pi receipt
  remain the concrete acceptance gate. Source/browser E2E tests do not replace
  that receipt.
- **Created documents:** This immutable decoder Finalization report.
- **Updated documents:** `ENGINEERING_STATUS.md`, `MANAGEMENT_SUMMARY.md`,
  `REPOSITORY_STATUS.md` and `PROMPT_INDEX.md` were reconciled as one set. The
  earlier immutable source Finalization record remains unchanged.
- **Repository State:** `MERGED_RECONCILED` after this governance-only
  Finalization merges. **Workspace State:** `WORKSPACE_READY` only after the
  mandatory cleanup of this slice's local branches.
- **Recommended next prompt:** Complete the same first-slice
  nonterminal-update receipt after a supported, reversible HA-dev Profile
  Platform backend binding is available; then stop. The separate Cast slice
  remains outside this increment.
