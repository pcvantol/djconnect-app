# Music DNA, Discover, Track Insight and Ask DJ scroll work

Source-only extension of the owner-requested scroll work. Existing ownership, requests, playback, expiry and deletion paths remain unchanged. No native build, test execution, preview, installation or FPS/latency acceptance under explicit-build-only instruction; last installed40447 unchanged.

## Music DNA

MusicDNAAdaptiveCardLayout previously measured every card again in both sizeThatFits and placeSubviews. Its Layout.Cache now reuses the measured frames/height for the same width, minimum column width, spacing and subview count. SwiftUI updateCache discards measurements when subviews change. This cache contains geometry only. Existing shortest-column/source/accessibility order is retained. Track-list labels use Equatable value rows (complete track plus resolved URL), leaving artwork resolution outside equality.

## Discover

Split card artwork and details into value-only Equatable views: artwork compares resolved URL/loading, details compare the complete item. Model observation, current URL resolution, Button callback/haptic and sheet selection remain in the parent. AsyncImage transport, URL admission, placeholders, clipping and existing source rights/expiry behavior are unchanged; no new image store or longer retention. Existing LazyVStack/LazyHStack virtualization remains.

## Track Insight

Outer content now uses LazyVStack. Hero lifetime onAppear/onDisappear gates its existing animation-active input, while existing foreground/playback/reduce-motion gates remain. This is lazy mount lifetime, not a claim of exact per-pixel visibility. Analysis and metric content compare their full insight/language and metrics mood input; environment changes remain SwiftUI-owned. Current metrics and source/context remain backend-owned. No values or music progress are inferred.

## Ask DJ

Previously timeline and search getters repeatedly sorted the whole message array, including from row search-membership queries. Keep transient view-only ordered persistent/timeline arrays, search IDs and a Set for row membership. Rebuild on appearance, persistent messages or either transient message changes; search-text changes rebuild only search matches. Preserve original chronology comparator, separate transient inclusion and persistent-only search. Clear derived arrays when screen disappears. Message changes still run existing selection normalization/scroll positioning. No durable cache, action copying into equality, request replay or owner scope change. Only value-only Markdown text/highlight uses EquatableView, avoiding repeated parsing when unchanged; action/context-menu/deletion/speech closures remain live.

## Pending validation

Source diff and owning-register checks only. Next explicitly requested build must compile and exercise all four screens on iPad/Mac: long content and continuous playback, DNA layout with resizing/Dynamic Type and changed subviews, Discover loading/detail and updated URLs, Insight lazy hero pause/resume/layout and environment changes, Ask DJ history arrivals/streaming/replacement/deletion/transient speech/search/selection/reopen/context changes. Compare actual scrolling/frame pacing and memory before claiming a measured improvement. PR179 remains source-only; no merge or installed result.
