# Session history contract repair — 40334

The current failure is a producer/consumer representation mismatch. Authenticated
Core history reads returned HTTP200 and qualified `owner_metadata_narration_v1`
contributions. Apple40331 admitted only two older archive bases and rejected the
whole page as `invalidResponse`. This is separate from the original uncaptured
HTTP404, which remains open.

The consumer now recognizes Core's four explicit archive bases and six entry
kinds. `dj_publication` and `dj_silence` retain identity/order but require no text,
sources, media or speech. They render as localized, source-free receipts without
Ask DJ, artwork or replay actions. Researched narration retains the supplied
source/license/revision links. No client facts, reconstructed text or retention
extensions are introduced.

Core's corrective version2 contract is discovered through
`contract_versions.session_history_entries:2`. The app opts in on history
list/detail/tail/anchor/search and POST-open, checks both response version fields,
and invalidates old cursors/projections when switching representation. A typed
`history_contract_upgrade_required` response stops automatic history retries and
offers a localized update message without clearing pairing. Existing owner,
source, privacy, bounds and expiry checks remain enforced.

Canonical producer document: `pcvantol/djconnect`,
`docs/product/SESSION_CONVERSATION_HISTORY_CONTRACT.md`, corrective18October
section. Definitive synthetic connected-query fixture:
`Tests/Fixtures/session-history-retention-bases-v2.json`, SHA256
`da5d8674dc49adb1cc0fabcca51d4f8b730d31f1179462160d1f68aa97e19b14`.
Its source pins identify the actual Core projection/query/speech inputs.
The original v1fixture600e6c… is retained as historical evidence of the mixed
schema1 page; its manually assembled envelope omitted `window_limit` and is not
used as a valid window-response fixture.

## Executed verification

- Before the fix, both new narration-basis request regressions fail with
  `invalidResponse`; negative owner/history-fence checks pass.
- Full final Swift suite:828tests/10suites PASS91.278s. Includes complete mixed
  page, same-identity withdrawal/cache replacement, forbidden receipt contents,
  request/response versions and bounded recovery without token loss/retry loops.
- Physical iPad40333:15entries/five new narrations; reopen PASS/no duplicates.
  Explicitly authorized stop/start/read/stop/archive/read/start-new lifecycle
  PASS; a new Session is left active.
- Physical final iPad40334:18entries/six new narrations; reopen PASS/no duplicates.
- Physical MacBook40334:12entries/three new narrations; reopen PASS/no duplicates.
  Its local signing failed; the exact Mac mini-signed products were transferred
  and executed without rebuilding or changing credentials.
- Mac mini native history check SKIP: no ordinary paired app context. It is not
  counted as a successful live history check.
- Ordinary40334 installed/read back/launched on iPad, MacBook and Mac mini.
  Strict deep signatures pass; no `.xctest` remains in ordinary app bundles.
  All161 product source inputs match the build stage exactly. Existing pairing
  and app data are preserved; previous Mac app bundles are retained privately.
- Localization1291keys and whitespace checks PASS.

## Installed Core and native v2 round trip

The existing Core writer installed the minimal history-only HA-dev artifact
`778610708c2aaf0bc97c4db88f1d125c9458c62d43d610d9081c3f1f0b8fa33b`:
199containerfiles verified, zero mismatches, configuration check PASS, database
integrity `ok` and storage schema10 unchanged. Its archive digest was independently
read back by Apple. The restart preserved the previous Runtime as INTERRUPTED;
no retained history was cleared.

Apple then repeated the explicitly authorized physical iPad40334 lifecycle over
installed v2: start/read/stop/archive-read/start-new PASS, leaving the new Session
active. Final paired native iPad AND MacBook40334 read/reopen each returned the
same current three-entry Session with one metadata narration, all contract-valid
and zero duplicate IDs. The final bounded paired HTTP check independently read
capability2, v1tail409 `history_contract_upgrade_required` with no source/entries,
and v2tail200/schema2/declared2/window_limit20. Ordinary apps were restored and
launched after these tests; no diagnostic app is left installed on iPad or Macs.

Private final receipts: `ipad-v2-live-lifecycle.xcresult`,
`ipad-v2-live-read.xcresult`, `protocol-after-active.jsonl`, and the ordinary
post-v2 installation/launch readbacks in the private evidence directory.
MacBook: `/private/tmp/djc-history40334-macbook-v2-live.xcresult`.

Private receipts, native results, build logs and source manifest are under
`/private/tmp/djc-session-integral-20261018`; MacBook native result is
`/private/tmp/djc-history40334-macbook-signed.xcresult` on that host. They contain
no published transcript or credential export. Source/fixture evidence does not
stand in for an installed producer handshake.

## Remaining boundaries

Core's minimal history-only HA-dev correction and live Apple v2 negotiation are
qualified above. This is a private dev repair, not a protected source-main or
production-delivery claim. Older/offline iPhone/Watch40331 are not updated
by these three-device installations. Original404, audible speech acceptance and
the owner-deferred USB CPU/GPU/memory investigation are separate open findings.

This build also includes the requested shared Ask DJ long-press menus with white
icons and removal of the duplicate inline Feedback link. The menu interaction
and white-icon screenshot were verified independently in the40332 simulator
candidate before this history repair.
