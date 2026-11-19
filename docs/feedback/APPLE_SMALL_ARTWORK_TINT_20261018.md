# Small session artwork: sampled glass frame — 2026-10-18

Request: make the glass border of small album covers follow the displayed artwork.

SessionArtworkView now derives the tint directly from the admitted decoded CGImage, before publishing the image. It uses the exact same inset, fill, opacity, corner radius and border as the large album artwork renderer. The existing average-color sampler and shared glass surface are reused; artwork sizing, aspect ratio and attribution behavior remain unchanged.

Protected artwork never enters the public URL/tint caches and no additional fetch is issued. The ephemeral tint is cleared with the pixels when the task changes, loses authority, expires or is cancelled. Existing media/epoch/generation and admission checks still gate display. No backend contract or stored data changes.

Qualification: native Swift compilation passed; 18 existing targeted artwork/presence tests passed sequentially in 4.375 seconds, including protected no-store/no-cache artwork, scoped grants, restoration and cross-screen tint reuse. Log: /private/tmp/djc-small-artwork-tint-tests.log. git diff --check passed. No new installed build or physical visual acceptance claimed.

Subsequent combined installation: iPhone build40313 includes these source changes; native build/signature/install/readback passed. Launch was blocked because the phone was locked. MacBook remains40312; no new physical acceptance. See APPLE_ARTWORK_GESTURE_OVERLAY_40313_20261018.md. Server dosing remains separately qualified/installed by Core.
