# Artwork gesture overlay restoration — iPhone 40313 — 2026-10-18

Request: gesture overlays on the large DJ Session cover are no longer visible.

The cover now owns the layout bounds. Its native tap surface is attached as an overlay, and visual feedback is painted last in a separate centered overlay above both that native surface and the entire glass/image-crossfade subtree. An empty feedback view no longer participates in calculating the cover geometry. Feedback remains noninteractive. Existing one/two/three-tap arbitration, command guards, immediate pause/skip feedback durations, haptics and accepted/unconfirmed playback handling are unchanged. Resume retains the established no-flashing-Play behavior.

This is a presentation-layer correction; the screenshot alone does not prove why a particular gesture's feedback was absent. Existing device logs contain four historical recognized-gesture records but predate the last app startup; they are not current native gesture acceptance. The user clarification about whether playback commands still execute remains optional/pending.

Native Swift compilation and 19 focused artwork/fallback/acceptance/tint tests passed in 4.447 seconds. Final iOS native build40313 passed; ordinary bundle, no test bundles/resource forks, strict deep signature and bundle ID checked before install. devicectl installation passed and independent apps readback confirms dev.djconnect.ios bundleVersion40313. Normal launch refused with FBSOpenApplicationErrorDomain7/Locked; no physical overlay visibility acceptance is claimed.

Build40313 also includes the preceding local four-choice presence presentation, small-cover tint, Mac composer intent correction (source only on Mac), queue identity fix and large-cover crossfade. Core's actual three-level presence recalibration/migration remains separate and NOT_INSTALLED pending its qualified producer pin. MacBook remains40312; iPad40290.

Logs: /private/tmp/djc-artwork-gesture-overlay-tests.log; /private/tmp/djc-gesture-40313-ios-build.log; /private/tmp/djc-gesture-40313-install.json; /private/tmp/djc-gesture-40313-apps.json; /private/tmp/djc-gesture-40313-launch.log. Full Swift suite: 803 tests / 10 suites passed sequentially in 91.050 seconds, log /private/tmp/djc-ui-followups-40313-full-tests-final.log. The first broad run exposed missing supporting files in the isolated snapshot and one non-repeating localhost fixture parse error; supporting files were restored and the complete final run passed without source changes. Changes remain local/unpublished.
