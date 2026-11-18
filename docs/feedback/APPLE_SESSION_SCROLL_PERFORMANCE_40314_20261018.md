# Session scrolling and artwork reuse — build40314 — 2026-10-18

User reports MacBook CPU95% and stuttering, especially iPhone, when scrolling a long Session; asks whether previously seen artwork is cached/buffered/offline.

## Findings and changes

- History date parsing constructed one/two ISO8601DateFormatters on every call. Retention/admission checks run repeatedly during visibility changes. Replaced this with locked reusable parsers and an NSCache of up to2048 immutable parsed timestamps; current-time retention decisions are still evaluated by callers, never cached or extended.
- Artwork prefetch previously checked retention for every loaded entry before locating visible rows. It now locates visible IDs first and only checks those and the nearest eligible retained neighbors. A1000-entry mixed-retention test verifies equivalence and exact expiry.
- Each protected image currentness check flattened/copied all timeline, historical-match and search entries. It now short-circuits the original collections without allocating a combined history array. Scope/epoch/media/retention admission checks remain intact.
- Static observed-playback cards used a1Hz timer. They now use the existing minute/exact-retention-deadline schedule.
- Generic artwork cached compressed bytes but recreated platform images as rows remounted. Added a memory-pressure-sensitive NSCache with60-entry/32MiB cost limits, actual prepared-pixel costs and exact existing byte-cache expiry matching. ImageIO prepares original-size/oriented pixels away from the MainActor; subsequent views reuse the prepared Image and sampled tint. No new disk cache. Expired/no-store/no-cache/max-age0 results cannot populate this cache. Protected SessionArtworkView does not use this loader.

## Contract boundary

The currently supplied SessionMedia contract explicitly requires cache_policy=no-store, forbids persistence and constrains grants to the original expiry/profile/session/media. Its pixels remain view-local and are discarded on expiry/cancellation; scrolling back can therefore fetch/decode again. No new cross-row or offline retention of protected images has been introduced. An asynchronous owner question asks permission to send a bounded temporary-memory-reuse contract request to the existing Core chat. No permission/reply has arrived and no message was sent for that request.

## Qualification and installation

- Targeted9tests PASS0.338s, including4HTTP cache-policy cases, stable object reuse only for a permitted HTTP lifetime, expiry rejection, concurrent timestamp equivalence and1000-entry prefetch equivalence. /private/tmp/djc-scroll-performance-tests-final.log.
- Full806tests/10suites PASS88.601s. /private/tmp/djc-scroll-40314/full-tests.log.
- Standalone same-input2000-timestamp microbenchmark, actual old/new parser implementations: old0.507319s, new cold0.041262s, warm0.000285s. Equal date results asserted. /private/tmp/djc-scroll-date-benchmark.json. This is a component benchmark on the build host, not end-user scrolling/CPU/FPS acceptance.
- Both native builds40314 passed. iPhone ordinary signature/bundle checks, install and independent bundleVersion40314 readback passed. No new iPhone launch attempt after the previous build's Locked result.
- MacBook native unsigned compilation from267hash-verified source files passed. Final local signing uses the unchanged entitlements/valid matching provisioning profiles and existing identity. Strict signature +79-entry bundle manifest + independent installed40314/running readback passed. Signed archive SHA256 b15a9f1f488b944ce0535d5d2c4882b2c035f1fdb000c6c7444950ce1068ac92. Previous Mac40312 retained as /Applications/DJConnect-recovery-20261017T234156Z.app.
- iPad40290 unchanged. No physical long-session CPU/FPS trace or new visual acceptance claimed. Source remains local/unpublished.
- Qualification/source hashes: /private/tmp/djc-scroll-40314/qualification.json. git diff --check passed.
