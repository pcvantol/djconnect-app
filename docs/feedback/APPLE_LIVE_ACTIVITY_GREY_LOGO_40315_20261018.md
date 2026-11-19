# Live Activity / Dynamic Island grey mark — iPhone40315 — 2026-10-18

User screenshots show an opaque grey rectangle immediately below track/artist in both presentations. That slot is the Spotify attribution Image, not a progress indicator. The widget catalog provided a3432×940px1x image and framed it at70×21pt; framing does not resize the underlying archived image. Apple documents that Live Activity image assets must fit the presentation: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities . This is a concrete source-size defect matching the observed slot; physical resolution is not yet accepted.

Derived uncropped, aspect-preserving70×21/140×42/210×63px1x/2x/3x PNGs from the untouched canonical shared Spotify logo. Kept original rendering intent and attribution/link behavior. Inspected the3x output visually. Asset regression checks PNG signature and actual dimensions against display size and declared scale. The original shared/app logo remains unchanged.

Passive cover decoding also now uses the actual32/56/104pt slot at3x pixels with matching Image scale3, instead of a512px/scale1 image framed smaller. Orientation/aspect and grant lifetime checks remain; no cache, download, permission, producer or playback change.

Qualification:17targeted asset/passive tests PASS1.287s; ordinary iOS40315 native widget/app build and strict deep signing PASS. Previous full806test run belongs to40314; no unnecessary full rerun for this bounded asset change. No new physical Live Activity acceptance claimed. Source remains local/unpublished.

iPhone installation and independent40315 readback PASS. Normal launch was blocked by Locked/FBSOpenApplicationError7; visual ActivityKit acceptance remains open. MacBook remains40314 and iPad40290. Exact269-file native source manifest and qualification receipt are in /private/tmp/djc-live-activity-40315/.

Evidence: /private/tmp/djc-live-activity-40315/targeted-tests.log; ios-build.log; iphone-install.json; iphone-apps.json.
