# Scoped content deletion without Session reconstruction — 22 October 2026

The owner reports visual flicker/full Session reconstruction when deleting one
contribution. The former success path called `suspend`, clearing every cached
Session/list/entry and then rebuilding them through network reads. A higher
Profile clear revision could repeat this during the same acknowledged deletion.

After the original owner-bound receipt is admitted, remove only its affected
entries from existing timeline/search/history projections. Preserve unrelated
rows, headers, reading anchors and their original retention/source deadlines.
Retire in-flight reads, navigation tasks, command/speech leases and cursors with
a new epoch; do not preserve execution grants. A same-owner clear within this
specific readback uses the same scoped fence, retaining the mounted projections
and the freshly negotiated capability flags (including false/revoked flags).
Ordinary clear/owner withdrawal/lifecycle suspension still clears private data.

Readback remains required before settling the existing durable journal. Merge
fresh timeline detail into the preserved loaded window, restoring server-owned
unavailable placeholders as supplied. A confirmed-removal revision drives a
220ms native fade/layout animation, respecting Reduce Motion. Pending deletion
warnings appear only after active deletion processing ends, avoiding a transient
warning banner during an ordinary successful request. No optimistic removal
before confirmation, mutation retry or backend contract change was introduced.

Existing causal deletion regressions now observe timeline/list publisher values
through receipt and readback and assert surviving entries never disappear,
including clear-revision and capability-revocation cases. Tests are prepared but
NOT RUN under the owner's no-build instruction. Swift syntax parsing and diff
checks PASS only. Native animation/viewport acceptance awaits an explicit build.


Validation update, night of22October: the preserved source now compiled and its software regressions ran in the full serial lane suite:1,164tests/24suites PASS121.521s. Log `/private/tmp/djc-apple-night-20261022/full-lane-tests-first.log`. Earlier no-build/unrun statements above describe the earlier checkpoint. This result is not native visual, installed-client, producer qualification or physical acceptance.

## Native context-menu stability follow-up

The closure-only environment value invalidated dependent views on ordinary updates. It now carries a stable view identity, exact target and model owner identity; permission remains separately rechecked by the existing begin/prepare path. The native regression uses the real AskDJMessageBubble with synthetic environment updates every100ms and no model/server delete. The deletion item remains mounted during a two-second hold, then invokes the test callback exactly once: iPad18.124sPASS and Mac13.774sPASS (`stable-delete-native-{ipad,mac}.xcresult`). This proves that bounded menu behavior, not physical deletion acceptance or haptic output.
