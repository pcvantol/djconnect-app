# Track Insight toolbar —40319,18October2026

Direct owner request from screenshot: put the two leftmost icons in their own
block at the far left. iOS/iPadOS TrackInsightView now places Share and Mood
in one topBarLeading ToolbarItemGroup. Connection and Refresh remain grouped
at topBarTrailing. Existing popover anchors/actions and Moment close control
are preserved; no business, speech or backend changes.

Ordinary signed iOS40319 build including Watch/widgets PASS; git diff --check
PASS.276current source inputs match the manifest at
/private/tmp/djc-insight-toolbar-40319/source-manifest.json. Build log is in that
directory. Existing40318clean stage was reused with the single UI file updated;
40318receipt remains a historical build-time hash record. No new tests for this
reversible placement edit. No installation or physical visual acceptance claimed.
