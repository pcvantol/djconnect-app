# Apple Track Insight — empty panels and evidence boundaries

Consumer correction for [Apple #296](https://github.com/pcvantol/djconnect-app/issues/296),
in the existing owning Apple writer and draft [PR295](https://github.com/pcvantol/djconnect-app/pull/295).
Base before this correction: `97570d9649a5985df3c4a2dd55d1be3e4191dfa6`.
The exact consumer commit is the PR head and published receipt; no second writer,
Core mutation, protected merge or device installation is part of this work.

## Existing producer, no new measurement admission

[Core #1421](https://github.com/pcvantol/djconnect/pull/1421) was read at
`7f8ca85791d9f91a153ae6906b0e1b348275a6cc`, OPEN DRAFT, not merged/delivered/installed.
Its checked current-credit retrieval keeps the existing wire and the protected
`unmeasured_metadata_only_v1` / `qualified_credit_and_interpretation_v1` bases.
It is not an operative installed pin and does not establish an audio provider.
The Apple fix already applies to these existing bases. Current-selector and
explicit Moment requests, original authority, lease and stale-response guards
remain unchanged; no legacy title/artist hint replaces current selection.

## Presentation

- `TrackInsightDisplayMetrics` projects current supplied fields only. The two
  non-measurement bases, explicit `measured_audio:false`, legacy unavailable
  responses and unrecognized nonempty bases cannot grant the six audio panels.
  A CC0 credit grants checked context/source, not energy/danceability/intensity
  or mood/vibe/texture. Genre metadata remains independently displayable.
- The existing basis-less legacy analysis contract keeps individually present
  fields, without being promoted to measured-audio evidence. Numeric display
  requires finite normalized values in 0...1. The existing parser's percentage
  compatibility remains 0...100; negative, nonfinite and over-100 input is rejected,
  not saturated into a fake zero or one. Zero itself remains a real supplied value.
- Individual absent rings/labels and entire empty rows/grid are omitted. The same
  projection is used by the Watch, exports and new widget snapshots; widget
  construction/load also rejects invalid numeric values.
- A real producer explanation is retained. The known legacy no-measurement
  fallback is localized honestly in five languages instead of becoming a generic
  promise that analysis will appear. Checked CC0 context and its source link stay
  separate from explicitly labelled interpretation. No serialized debug object
  is turned into prose. The decorative hero identifies itself as visual animation,
  not an audio measurement.
- No artwork/title/genre-derived metrics, previous-track values, local model,
  provider readiness, Profile or durable intelligence is invented.

## Verification

- `track-insight-empty-panels-r1`: focused source/presentation regressions pass.
- `track-insight-native-r3`: native AppKit grid fitting proves an empty grid has
  no height, zero retains its numeric row, and a genre-only result has no numeric
  row at 430/820/1200 points. Fifteen native snapshots cover five UI languages,
  these widths and larger text with an existing original CC0 producer fixture.
  The narrow Dutch and medium English snapshots were visually inspected.
  This is macOS component rendering, not native iPhone/iPad/Watch acceptance.
- Native r1 initially used an unsupported writable Reduce Motion test environment
  key; test-only correction removes that injection. Native r2 ImageRenderer did
  not render AppKit Link; r3 uses actual NSHostingView/AppKit snapshots. Only r3
  is the source-link visual evidence. Reduced-motion production guards remain;
  system Reduce Motion and VoiceOver interaction are not newly qualified here.
- `track-insight-empty-panels-full-r2`: 1,636 tests in 60 suites pass, unchanged
  source during execution. This includes current selection, explicit Moment,
  source/owner/track changes and stale-result regressions. The first full run
  caught an old widget test expecting invalid values to clamp to 0/100%; its
  expectations now require absence, while a separate valid-zero regression remains.
- `track-insight-ios-watch-build-r2`: iOS/iPadOS simulator and embedded watchOS
  targets build, including both iOS simulator architectures.
- Repository validation output: `validation-track-insight-r2` (final committed
  candidate, all nine groups required).

Run outputs, source hashes and published readback are retained under the existing
batch evidence directory outside the repository. The PR supplies the exact
consumer delta for normal independent readonly review; no review approval,
Core delivery, installed runtime, actual provider measurement or product-wide
acceptance is inferred from these tests/builds. #296 is not auto-closed here.
