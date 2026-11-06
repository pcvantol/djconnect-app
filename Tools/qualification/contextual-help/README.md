# Native Help regression

Run this slower native suite explicitly, before a relevant release or after
changes to Help, suggestions, the composer or native layout. It is not part of
every-PR CI and makes no model/provider calls.

```
python3 Tools/qualification/contextual-help/run_native_help.py \
  --platform iOS \
  --destination 'platform=iOS Simulator,id=<owned-iphone-or-ipad-id>' \
  --jose-checkout '<clean-pinned-JOSESwift-checkout>' \
  --output '/Volumes/Shared Data/tmp/pcvantol/<new-unique-run>'
```

For Mac, select `--platform macOS --destination platform=macOS`. Use separate
output directories for iPhone, iPad and Mac. The runner retains the full XCTest
result, logs, source/diff identity and a receipt, including failures. It runs
each test once and never hides a failure with an automatic retry.

## Current catalogue coverage

`HELP_CURRENT_CATALOGUE=1` uses the real byte-verified bundled revision-2
catalogue and the original all-14-entry projection in
`Tests/Fixtures/askdj-help-r5-core-wire.json`. The view context is a declared
disposable test context, not an operator's live Profile or new producer
admission. Test resources remain outside shipping targets.

- Every published option is selected in NL and EN on both `ask_dj` and
  `active_session`: 56 native selections. Expected text comes from the original
  catalogue. Placeholder options produce a draft; complete options forward the
  original complete prompt to a probe.
- The production suggestion selector and native suggestion rows produce three
  distinct stable choices and forward exactly the displayed text: 12 native
  selections covering both languages and surfaces.
- The current production `AskDJHelpPanel` and `AskDJFullCatalogueReference`
  render the catalogue. A test-only entry adapter opens the panel. That adapter
  does not qualify the shipping composer's entry, focus or network reader.

The fixture supplies prerequisites for all 14 options. In the real client,
missing prerequisites must keep corresponding options disabled. EN/NL are
published; DE/FR/ES route qualification remains pending and must not be enabled
by this test.

## Separate integration evidence

`PASS_NATIVE_COMPONENT_ONLY` is not a Core Golden, provider, playback, speech,
history or physical Watch verdict. The host cannot send commands or play audio.
Real end-to-end runs must bind the actual paired client, original server turn,
answer/history identity, Core installation and provider/effect evidence through
the qualified Core native Golden contract. The older 167-step adapter is not a
current admission. Missing native/provider coverage remains NOT_RUN or blocked,
never a pass inferred from component screenshots.

The generator retains historical synthetic-reference, placeholder-composer and
tokenless composer-popout probes. They are isolated component tests, not current
server route or paid Golden qualification. Composer probes disable Send, voice
and background work and never borrow installation tokens.

### Explicit landscape visibility regression

The disposable host also renders the shipping `ForYouLandscape` with a decorative
recipe and navigation/scroll controls. Run
`NativeHelpUITests/testForYouAnimationStopsAndReplaysAfterViewportAndPageReturn`
explicitly with the generated `NativeHelpUI` scheme. It compares the actual
landscape screenshots after the two-second window and after viewport/page return.
This is a renderer-only regression; it does not fetch an offer or exercise Core,
pairing, playback or a physical Watch. It is deliberately outside ordinary PR CI.
