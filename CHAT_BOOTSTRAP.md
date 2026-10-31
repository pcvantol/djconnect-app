# Deprecated

Read `BOOTSTRAP_CODEX_SESSION.md`.

For the current Apple release-runner and dual-Mac deployment assumptions, read
`docs/RELEASE.md`. This deprecated pointer does not define a separate release
contract.

Current installation qualification: `Tools/qualification/install_ordinary_macos.py`
validates ordinary bundle identity, signatures, executable modes and framework
symlinks. CI runs its preservation regressions. Current local work/evidence and
remaining release gates: `docs/feedback/APPLE_INTEGRAL_EXECUTION_20261017.md`.

CI also runs the isolated VibeCast binding/binary-input package. These tests use
injected SDK closures only; they neither arm the separate hosted diagnostic nor
generate keys/captures. See `Tools/qualification/vibecast-native/API_BINARY_INTAKE.md`
for the separate app/profile and joint API experiment gates.

CodeQL maintenance: PR180 now pins all three firmware-analysis action references
to 4.39.0 (`6f2ac81f5cd81fe351a197ba0b00d91d03cd2aee`). Its original main
qualification is recorded in `docs/feedback/APPLE_CODEQL_180_SOURCE_RECEIPT_20261024.json`.
This workflow-only update is not an app version or device-installation receipt.

TDE observe diagnostics: Source #243 preserves original CLI stdout/stderr/exits and
BLOCKED decisions, and publishes supplemental public Runtime diagnostics only as
`NOT_QUALIFIED`. Observe success is not a successful TDE assessment. Original
source qualification and remaining analyzer gates are recorded in
`docs/feedback/APPLE_TDE_OBSERVE_DIAGNOSTICS_243_SOURCE_FINALIZATION_20261030.md`.

Parallel validation preparation (2026-10-31): independent client fixtures retain
per-runtime caps and child-task ownership, while CI validators/packages/native
builds use bounded workers and isolated output roots. Source review, exact-head
CI and protected delivery are still required; local results are not installation
or physical acceptance. See `docs/feedback/APPLE_PARALLEL_CLIENT_VALIDATION_20261031.md`
and `docs/DEVELOPMENT.md`. This note does not declare protected delivery.
