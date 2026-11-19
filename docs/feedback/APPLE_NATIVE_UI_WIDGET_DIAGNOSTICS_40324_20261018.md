# Native UI follow-up and widget diagnostics —40324,18October2026

Owner: continue open points and tests. Existing sole writer/branch/WIP retained.
Current276input source transferred to the already-authorized private MacBook
simulator environment and reverified after all changes. No physical install,
backend mutation, source PR/merge or release in this increment.

## Found and repaired

The initial native iPhone round ran six actual app tests. Four cases passed;
two failed with seven assertions because connection/refresh were missing after
placing the main controls in a native leading ToolbarItemGroup. Successful source
compilation had not established that native arrangement's reachability.

Compact iPhone now uses one bounded leading toolbar item with a horizontal row
of44point targets. This preserves More→Mood→Presence→Persona→End at the left
without iOS automatically hiding the independent connection/refresh group at the
right. Expanded iPad retains direct native actions with no extra overflow menu.
The scoped-search tests now use More first where needed, preserving direct iPad
search and existing anchored popover dismissal before search-field focus.

All six iPhone native cases now pass: circular playback controls, floating
composer/scoped search, scrolling hero/jump return, menu across eight seconds
of playback ticks, rightmost refresh/explicit left-item order, and VibeCast's
existing demo blocking dialog. One iPad test passes with both portrait and
landscape assertions. These are native simulator presentation checks using
isolated demo data, not production pairing/TV, real covers or backend acceptance.
The final toolbar, open-menu and iPad-landscape attachments were visually viewed.

## Make the unresolved widget loss observable

PassiveSessionSurfaceModel now emits bounded lifecycle diagnostics for changed
OS configuration, owner/Session reset, settings revalidation, authorization failure,
read refusal/withdrawal, first valid cache and original deadline expiry. Logged
values are surface/stage/booleans/counts and fixed error classes; never grant IDs,
source text, server error messages, Profile/Session identifiers or credentials.
No progress-tick logging, fresh grant retry or cache deadline extension is added.
AppModel writes these through the existing diagnostic log, without publishing a
new product state. A regression proves a widget read refusal is identifiable,
private fields absent and automatic authorization still happens only once.

This is diagnostic progress, not a widget fix. Existing Core writer reports its
current actual active-history page/tail read200 through the paired iPhone identity;
original failing reference and later widget withdrawal remain unproven. It is
continuing producer diagnostics without extending the120second data deadline.

## Final qualification

- Full820tests/10suites PASS90.838seconds;15targeted passive tests PASS0.768seconds.
- Native iPhone6/6 and iPad1/1 PASS; iPad includes portrait/landscape. Native test
  execution bundles finalized and screenshots exported. Ordinary signed iOS/Watch
  build40324 and strict/deep signature PASS; no installation or audible acceptance.
-276local/current and remote source hashes match;1283keys/five languages and
  git diff --check PASS. Bounded receipts/source hashes at
  [results](APPLE_NATIVE_UI_WIDGET_DIAGNOSTICS_40324_20261018.json).
- The first failed round's test cases completed, but Xcode hung collecting verbose
  failure diagnostics; only its exact owned xcodebuild process was interrupted.
  The final run used collect-test-diagnostics never and completed normally.

Physical CPU/GPU/memory/stutter profiling remains deferred to tomorrow via USB by
the owner. Phone40315 remains preserved for the before-measurement. Actual Session404,
widget rich-data continuity, queue recurrence and physical Watch sound remain open.
No measured performance improvement or complete closure of those items is claimed.
