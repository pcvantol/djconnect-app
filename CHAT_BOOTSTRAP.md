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
