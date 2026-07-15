# Apple Governance Adoption

This repository adopts the DJConnect AI-Native Engineering Operating System
**version 2.2** from `pcvantol/djconnect`,
`docs/governance/PLATFORM_ARCHITECT_SYSTEM_INSTRUCTIONS.md`.

The central method is referenced, never copied. This repository owns Apple
implementation, validation and release reality. It has no repository-specific
exceptions to the method.

Every increment starts with `git switch main` and `git pull --ff-only`, verifies
current main and the predecessor PR, reconciles `MERGED_UNRECONCILED` records,
then performs an implementation-reality check. Lifecycle states are
`LOCAL_IN_PROGRESS`, `REVIEWABLE_FROZEN`, `MERGED_UNRECONCILED` and
`MERGED_RECONCILED`. Prompt History is immutable; branch cleanup is fail-closed
until merge, archived history, remote deletion and a clean tree are verified.
