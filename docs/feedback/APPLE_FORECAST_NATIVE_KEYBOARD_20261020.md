# Forecast native Command-F qualification

Local test-only continuation from
`2543eef8a2067e21a42cadbbc0c3f86f5ec983bb` on the sole Apple writer. No
production source, producer contract, installation or publication changes.

The opt-in `DJCONNECT_FORECAST_KEYBOARD_DIR` reuses the existing paired Forecast
fixture and its real appmodel decode/state route. Only the current-context case
advertises the already supported Flow text-search contract for this probe. Its
own offscreen AppKit window hosts `SessionTimelineScreen` in a NavigationStack;
three native Command-F events are dispatched through that window's
`performKeyEquivalent`. No system keyboard events are injected and no ordinary
application is launched.

The completed native sequence verifies:

- From Forecast, Command-F selects Flow, mounts the actual Flow search field
  and gives its native text editor first-responder focus.
- Forecast's independently entered query survives switching away and back.
- Command-F from Forecast restores an already-open Flow search rather than
  closing it; the same shortcut in Flow retains its normal close action.
- The unsent Ask DJ draft, active Session ID and Session playback projection
  remain unchanged. The fixture's final ledger permits only GET requests and
  excludes command/message routes.

The final targeted Swift Testing function passed all **16 parameterized
transport/lifecycle cases**, including the opt-in native window sequence.
`git diff --check` also passes. No source correction was needed: this supplies
missing evidence for the existing keyboard behavior.

Three window captures show Forecast, focused Flow search and Flow after closing
search. The fixture deliberately has no timeline response, so Flow displays its
existing unavailable/retry state. This is not populated timeline/search-result
acceptance or full-header visual qualification. The first pass also succeeded;
the final pass adds explicit Session-ID/playback invariance checks.

Reproduce with an unused private output directory:

```sh
DJCONNECT_FORECAST_KEYBOARD_DIR="$FORECAST_KEYBOARD_OUTPUT" \
  swift test --scratch-path "$SWIFT_SCRATCH" --no-parallel \
  --filter forecastNativeOwnerReadRetainsDraftAndFencesLateBackgroundResponse
```

Final private log: `/private/tmp/djc-forecast-keyboard-final-20261020.log`.
Captures: `/private/tmp/djc-forecast-keyboard-final-20261020/`.
Input/evidence hashes are in the adjacent JSON receipt. Existing unrelated test
compiler warnings are retained in the log, with no test failures.

This qualifies native key-equivalent routing and text focus in the bounded Mac
test host. It does not qualify physical keyboard input, VoiceOver, iOS keyboard
or composer behavior, scroll-position restoration, ordinary installed apps,
current HA/provider behavior or external browser actions. Those remain open.
No unchanged failed full-host source-Link probe or stalled iOS runner was
repeated. This candidate remains local; earlier publication restrictions and
the pending exact-8462454 draft-PR question remain in force.
