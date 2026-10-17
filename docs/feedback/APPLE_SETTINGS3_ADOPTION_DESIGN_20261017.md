# Apple settings3 adoption design and work record

Assignment DJC-PROFILE-SESSION-SETTINGS-CONSOLIDATION-V1-20261016. Human directly
requested completion2026-10-17. Same sole writer codex/apple-dj-presence-v1, start
cd23fa0708c881f8899b95b44029b2d119683071. Existing untracked project duplicates
and iPad WebSocket notes remain untouched. No scanner work or second writer.

Producer: definitive Core1329ad1ce8bd066d65a08b3988261a44e2cac730, Apple lane
6223987404. Read exact canonical settings/inventory, capabilities and actual
connected-ha-transport fixtures. Historical contract2 sections are not a fallback
interpretation of settings3. No backend contract change is proposed.

## Implementation boundary

- Typed six-field snapshots, options, migration, opaque binding, independent
  defaults/Session revisions and operation receipt; capability version3 required.
- One model/controller and one Settings -> Profile -> Your DJ editor. Only explicit
  accepted owner PATCH changes shared state; no local default upload or optimistic
  confirmed selection. Pending/conflict/uncertain/offline remain distinguishable.
- Stable UUIDv7 operation and exact binding/expected Session; never replay uncertain
  PATCH. Reconcile via original receipt, then fresh read, preserving generation and
  Profile/route/session fences; old receipt cannot overwrite a newer snapshot.
- Reuse existing authenticated client and foreground coordinator. Refresh on entry,
  foreground, paired authority/Session change and existing bounded foreground
  refresh; no new independent timer/controller or unauthenticated/private WS route.
- Shared quick controls route through the same model. Retire active local voice/
  gender and output overrides when shared ownership is negotiated; preserve
  genuinely local autoplay, output volume, permissions, haptics, connection choices
  and existing parked chat/DNA portability controls.
- Retain unavailable saved voice/output visibly; voice/gender choices come from
  producer inventory. Six-field explicit review for legacy unknown Mood; defaults
  are proposed choices, not silently accepted active state.
- Speech prepare3 uses effective shared settings/output and target-bound operations;
  text_only fences all synthesis/replay before preparation and byte/play acceptance.
  Speaker dispatch remains Core-owned; no HA speaker administration in client UI.
- Five languages, adaptive native layout and accessibility. Watch presentation must
  follow the same authoritative state where supported, not add local personal truth.

## Qualification and closure

Use pinned producer fixtures and meaningful client/controller tests for no-Session,
atomic partial changes, two-client invalidation/readback, per-field persistence,
receipt conflict/unknown, ABA/end/background, providerwithdrawal and text_only
fences. Build Mac/iPhone/iPad/Watch. Native render and real installed cross-device
Session/default/HA-restart/audible acceptance remain separate evidence steps.
No source, installed, audible or joint completion is claimed by this design record.
Update this record with actual implementation/validation results and remaining
constraints. Existing publication/signing authority remains unchanged.
