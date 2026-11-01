# Apple TDE 1.1.2 adoption

## Problem and repair

Published TDE 1.1.1 pins Lizard 1.23.0. Its Swift reader mistakes member calls
and initializer references for declarations, producing conflicting symbol
identities on Apple main 73d114a. The original assessment and qualification
fail closed with BLOCKED/exit 3. Original reports remain unchanged.

TDE source PR #164 / main `3ca0041cbd768b2b9d767df4c87b803f486ac189`
prepares runtime 1.1.2 with the qualified upstream Lizard 1.24.3 repair and
patch-aware analyzer discovery. Its 162-test suite succeeds (one opt-in Docker
test skipped), and six real Swift qualification targets pass on Linux, macOS
and Windows with Python 3.11/3.13. The candidate is RELEASE_QUALIFIED and
RELEASE_CERTIFIED in run 41286370399. Human approval explicitly covers the
certified bundle, Git tag/GitHub Release, PyPI, Docker Hub and Apple adoption.

## Bounded consumer change

Only the exact public runtime pin and corresponding diagnostic messages change
from 1.1.1 to 1.1.2. The standard profile, declared policy, thresholds, original
CLI stdout/stderr/exits, supplemental NOT_QUALIFIED diagnostics and non-blocking
Observe behavior remain unchanged. No app build number, shipping implementation,
source exclusion, finding suppression or native/push qualification changes.

The installed candidate wheel already produced VALID evidence for all four
capabilities on unchanged Apple main with its original xccov artifact. Runtime
qualification is QUALIFIED, while actual policy findings produce FAIL/FAILED
and exit 2. This is a meaningful code-quality outcome, not a broken analyzer
or an excuse to relabel debt as PASS. Public-package installation and current
PR/main hosted results are qualified separately during delivery.


## Published runtime verification

Publication run [41287426907](https://github.com/pcvantol/technical-debt-engine/actions/runs/41287426907)
succeeded via the existing protected `internal-release` environment after the
explicit human approval for all three targets. The release is
[1.1.2](https://github.com/pcvantol/technical-debt-engine/releases/tag/1.1.2),
bound to TDE main `3ca0041` and certified candidate run 41286370399.
Public PyPI wheel/source downloads are byte-identical to the certified bundle;
the public Docker index and both amd64/arm64 manifests match its OCI provenance.
No package was rebuilt during publication.

Published wheel SHA256: `72007fabb5eeb23d4acffc8aa868cffd214ee3d3ab362e4c56c3049f143163e8`.
Published source archive SHA256: `32fcaeaaa9f738a1aaed72f3b8d930cf85d88ee858c48e6361317f11d6659033`.
Public index: `sha256:1e5560d230843f870fa5112a2aed0fead90bf6b0d4c98e14e8370a1a3bb6d627`.
The independent original-publication verification receipt is hash-bound as
`505562b8a6b8d8674618112be5fc829a65863992886da384ce0db5607b607ed3`.

Consumer validation before PR: four existing Observe diagnostic regressions
pass, including preservation of real workflow stdout/stderr, exits and decisions;
`git diff --check` passes. Current-head hosted CI and actual TDE assessment remain
separate delivery checks; no new positive push or device acceptance is claimed.
