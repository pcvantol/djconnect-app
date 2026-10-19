# Stash consolidation checkpoint — 19 October 2026

Owner request: compare every retained stash, consolidate outstanding work, then
continue from one clean main checkpoint. Comparison base:
`17477f07b3ec79769079fe24e4fca0c220dabdf3`. One existing checkout/writer; no
parallel worktree. This audit covers all12 original stash entries, including
untracked parents and four historical screenshots.

## Disposition

| Original entry | Commit | Decision |
| --- | --- | --- |
| stash@{0} | `cdb803b703d567cccb45cf1032c68e22895589e8` | SUPERSEDED_ON_MAIN: Moment decoder/flow revisions, same-Session and generation fences, locale keys, native current card, fixture server/generator/receipt, independent Session/player navigation and iOS/Mac interaction tests are present in evolved forms. All four original Moment contract tests remain; current decoder has stricter source/lifetime admission. The generated project blob also exists in main history. |
| stash@{1} | `4f915713bbd8c84a2d18372c6f7a66d417ddda38` | IN_MAIN_HISTORY: Both untracked distribution/smoke workflows have exact blob matches in main history; current files contain later maintained pins/changes. |
| stash@{2} | `551221c042b658883477028df10507ec3b158670` | IN_MAIN: The requested share-card spectrum removal is already present: no TrackInsightPremiumSpectrum call or spectrum layout properties remain in TrackInsightShareViews.swift. |
| stash@{3} | `4cc67bb997acbb3ad5384fce816b9fe5d9830b4e` | IN_MAIN: Final offline state, device-vs-LAN reachability, retry/settings banner and optional mood percentages are present. Watch model and all five locale files have exact historical matches; current root/model retains the evolved implementation. |
| stash@{4} | `073c6c7fed4a87e372afd1f88b252c15b007043c` | IN_MAIN_HISTORY: Both Watch networking blobs have exact historical main matches; current Watch retains companion reachability, offline gating and network refresh. |
| stash@{5} | `c876a27be9a65cf9e526077e91cccb2c024355ee` | IN_MAIN: Earlier partial offline patch is subsumed by the final device/LAN distinction and current cross-platform offline UI. Locale blobs match main history. |
| stash@{6} | `83952930f8eb45b7ed49bcf9b43e49a87d1b724d` | IN_MAIN: Earlier network polling and system-settings helper patch is subsumed by the final implementation. Current network callback updates both timers; locale blobs match main history. |
| stash@{7} | `4837e48a7a2f6cc01ea1f4e05af20d14fcd6ef73` | RECOVER_MISSING_WATCH_ICONS: Offline UI/retry and optional percent handling are already present. Recover only missing party.popper.fill selector and Music DNA mood/mix icons, using the same backend-confirmed zone as the displayed mood text, and topZone for the mix; preserve unknown fallback. |
| stash@{8} | `afbe52a9105fb886e5abc4363753c2a551605b26` | RETIRED_EXPERIMENT: Old Party! screenshot test targets an obsolete private-chat mirror and its demo-only identifiers. Preserve in archive; do not reintroduce that page or its tests into current Session/VibeCast navigation. |
| stash@{9} | `7b79b112d076be593ea738617db7d46638e95661` | IN_MAIN_HISTORY: The iOS launch-fixture blob has an exact historical main match; current runtime fixtures have evolved. |
| stash@{10} | `94e5c4f6e405dfbba57397d2863397b302ff35f6` | RETIRED_EXPERIMENT: Old Party! page mirrored private Ask DJ history and initiated audio from view/message appearance. Current Session and backend-owned VibeCast/source/speech admission supersede it; restoring it would bypass current rendering and audio boundaries. |
| stash@{11} | `ce5482ddc9b60a50514ada36c202005a265293a7` | MIXED_ARCHIVED: iOS launcher blob exists in main history. Party demo seeding, unconditional view-driven audio, old Party page/test are obsolete as above. Four screenshots are historical evidence, preserved byte-for-byte in the untracked archive; not shipping assets. |

## Result and recovery

The only missing production change found is the Watch mood icon correction.
Restore the party icon in the Watch mood picker and matching confirmed mood
icons in Music DNA. No backend change, new settings, private-chat mirroring or
automatic speech behavior is introduced. Existing functional acceptance gates
remain open; stash retirement does not close Apple127 or prove physical Watch UX.

Recovery lives in the ignored `build/recovery/stash-consolidation-20261019/`:
all12 original commit IDs in `stash-history.bundle`, tracked snapshots/patches,
untracked-parent snapshots, comparison inventory and SHA256 manifest. Every
snapshot member was compared byte-for-byte against its original Git blob.
`git bundle verify` passes; its four prerequisites are in the retained main
history. Preserve this recovery directory during build/storage cleanup. No
screenshots or other recovery evidence are deleted.

After protected merge and exact-main readback, active stash references may be
removed only if the fresh inventory still matches the twelve audited hashes and
all recovery checks pass. The new checkpoint is the resulting merged main SHA;
the PR and local checkpoint readback bind it to this audit. No active work is
carried forward in a hidden stash.

## Validation boundary

Watch native compilation and ordinary PR checks are required before merge.
No new UI assertions mirror this simple icon mapping. No physical installation
or Watch sound/interaction acceptance is claimed.
