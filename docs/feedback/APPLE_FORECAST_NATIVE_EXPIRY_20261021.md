# Native Forecast lease expiry — 21 October 2026

Tests-only qualification based on `8a553f82c80c8d28dec57505d0300f109511917e`. No production source change was required.

The opt-in `DJCONNECT_FORECAST_EXPIRY_DIR` shortens only the current synthetic test response's `valid_until` to six seconds. The checked-in producer fixture remains byte-identical. The existing fixture still supplies the same authored text, paired owner and exact GET contract; optional imagery remains absent rather than fabricated.

The actual `SessionForecastPanel` runs in its own offscreen dark 600 × 1000 AppKit window with the existing canvas and an empty header. It uses the real clock and production expiry machinery. There is no clock injection, owner withdrawal, forced refresh or manual UI replacement. The test waits until the admitted deadline plus 0.4 seconds and captures the panel **before** querying the expired visible projection.

Both final captures were inspected: initially the summary and all three authored cards are visible; after expiry they disappear and the honest unavailable notice replaces them. The existing retry presentation remains available because owner/read admission is still valid. The model then confirms no visible projection, unchanged owner response epoch, retained owner and valid read admission. Forecast reads remain **2 → 2**. The unsent draft, Session ID and playback value remain unchanged. The GET-only fence rejects command/message effects.

Final Swift Testing result: **one function with 16 lifecycle cases PASS**, with the expiry sequence running in the current-owner case. Production sources were unchanged, so no iOS build or broader unchanged green checks were repeated. `git diff --check` passed. An earlier successful probe is retained; its optional timestamp-to-JSON compiler warning was removed by explicitly unwrapping the admitted timestamp before the final run.

Final private evidence: `/private/tmp/djc-forecast-expiry-final-20261021.log` and `/private/tmp/djc-forecast-expiry-final-20261021/` (two inspected captures and metrics). Earlier probe: `/private/tmp/djc-forecast-expiry-native-20261021.log` and directory. ISO timestamps in the metrics have whole-second resolution; the runtime assertion compares actual Dates after waiting beyond the deadline.

This is native macOS panel expiry evidence over synthetic HTTP. It does not qualify physical input, VoiceOver, optional artwork expiry, other locales/geometry, full-root navigation, iOS runtime, ordinary installed apps or current HA/server/provider behavior. No push, PR, merge, installation, SDK effect, deployment or recovery bundle was performed.

Next independent point: inspect qualified populated Flow timeline fixtures and their real request contract. If they fit the current paired owner/session, qualify preservation of a nonzero native Flow reading position across Forecast selection. The previous scroll proof used an explicitly unavailable 404 Flow and retained position zero; it does not establish populated-history restoration. Do not invent history facts or endpoints, and do not rerun unchanged failed AX/iOS runner probes.
