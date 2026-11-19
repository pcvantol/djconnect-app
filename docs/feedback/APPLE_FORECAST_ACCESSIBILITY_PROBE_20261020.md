# Forecast native accessibility inspection — 20 October 2026

**Result: INCONCLUSIVE_HOST_ACCESSIBILITY_TREE.** Local diagnostic work based on `ade91f1a401148aa9f72e187e7b20fc0d68599ab`; no production source change or accessibility acceptance.

## Actual inspection

The opt-in `DJCONNECT_FORECAST_ACCESSIBILITY_DIR` records the public accessibility hierarchy and native control metadata from the existing paired GET-only fixture and actual `SessionTimelineScreen`. It uses its own offscreen 600 × 900 dark AppKit host. It selects Flow → Forecast → Flow through the actual native segmented control and retains the draft, Session ID and playback assertions. No system VoiceOver setting, cross-process accessibility access or ordinary installed app is involved.

Both protocol-only traversal and public object-valued accessibility selectors found only the root AXGroup, with no virtual SwiftUI children. Native descendants did include the two-segment picker (Flow / Vooruitblik, selection 0 → 1 → 0) and the Forecast search field (placeholder “Zoek in de vooruitblik”). Their accessibility metadata reported AXUnknown, no exposed element and empty labels in this host. This cannot establish that the actual product has missing labels or that hidden Flow content is correctly excluded from accessibility navigation.

The first two probes failed their explicit tree-size prerequisite (three issues per run). Those are retained as diagnostic failures, not product counterproof. The final recorder stores `INCONCLUSIVE_HOST_ACCESSIBILITY_TREE` in each snapshot; its fixture/lifecycle checks pass with 16 cases. That test result does not qualify labels, heading traits, reading order, spoken VoiceOver, hidden-content traversal or source-Link accessibility.

## Source review and next point

The current source already supplies a localized Forecast search accessibility label, header traits on the Forecast title and section titles, and `.accessibilityHidden(displayingForecast)` on Flow. Source review cannot replace the missing runtime accessibility hierarchy. No corrective production change is justified by this host result.

Do not repeat these unchanged offscreen tree probes. A future full accessibility qualification needs a host that actually exposes the SwiftUI hierarchy, then explicit labels/traits/order/hidden-content checks. Physical VoiceOver remains a separate acceptance step. Continue independent Apple work from the current lane, including native Forecast filtered-section presentation if useful. The production display-consent owner guard is iOS-only; a macOS model must not impersonate an iOS owner to manufacture qualification. Do not repeat the stalled iOS runner unchanged.

## Private evidence

- `/private/tmp/djc-forecast-accessibility-probe-20261020.log` and directory: protocol-only prerequisite failure.
- `/private/tmp/djc-forecast-accessibility-tree-20261020.log` and directory: public-selector prerequisite failure.
- `/private/tmp/djc-forecast-accessibility-controls-20261020.log` and directory: initial native-control metadata.
- `/private/tmp/djc-forecast-accessibility-final-20261020.log` and directory: final recorder, explicit inconclusive status and 16 lifecycle cases.

The receipt hashes source/fixture and private evidence. No push, PR, installation, HA/provider/SDK effect or recovery bundle was performed. Existing scroll and keyboard qualification remains separately scoped to its original evidence.
