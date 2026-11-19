# Large album artwork crossfade — 2026-10-18

Request: soften the arrival of replacement album artwork in DJ Session and Now Playing.

Both large-cover call sites opt into the shared CachedArtworkImage crossfade. The currently decoded image remains visible while a replacement downloads. Publishing the next successfully decoded image changes a URL identity inside a stable ZStack and applies an opacity-only easeInOut transition of 0.45 seconds. The glass color is sampled from the same image bytes and published alongside the image, so the frame fades with its cover. Now Playing no longer replaces the whole artwork renderer on every metadata track-key change, avoiding a premature fallback flash and the old scale/spring transition.

No transition occurs for metadata-only changes sharing the same artwork URL. Missing artwork transitions to the existing vinyl fallback. Invalid replacement pixels or exhausted existing fetch retries release the previous cover rather than retaining another track's art indefinitely. Existing cancellation/URL checks reject stale results after rapid skips. Reduce Motion disables the crossfade. Small thumbnails and protected SessionArtworkView behavior remain unchanged.

Validation: native Swift compilation passed; 19 existing artwork/fallback/tint regressions passed sequentially in 4.470 seconds. Log: /private/tmp/djc-large-artwork-fade-tests.log. git diff --check passed. No new installation or physical animation acceptance claimed.

Subsequent combined installation: iPhone build40313 includes these source changes; native build/signature/install/readback passed. Launch was blocked because the phone was locked. MacBook remains40312; no new physical acceptance. See APPLE_ARTWORK_GESTURE_OVERLAY_40313_20261018.md. Server dosing remains separately qualified/installed by Core.
