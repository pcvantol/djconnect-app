# Queue rendering identity correction — 2026-10-18

User clarification: the item exists once in the actual queue; investigate client rendering rather than waiting for a duplicate producer response.

Concrete client defect: QueueView used item.id (usually the track URI) as both SwiftUI ForEach identity and scroll target. normalizedQueueItems counted metadata signatures rather than actual row IDs. The same URI with differing metadata could retain duplicate row IDs. Generated #2 suffixes could also collide with real incoming IDs. Duplicate view identity makes row reuse/diffing undefined and can display stale/repeated content.

Correction: both iOS List and Mac LazyVStack identify queue occurrences by their original queue position. Search scroll targets use that same position, and play actions retain the original unfiltered offset. Model normalization now guarantees unique actual IDs independently of metadata and reserves all incoming IDs before assigning suffixes. Legitimately repeated tracks are retained; no content deduplication or backend mutation. Diagnostic wording now distinguishes normalized model count from an actually observed native row count.

Regression: metadata variants sharing one URI, real suffix collisions, repeat-read stability, shrinking to one item and clearing; existing repeated-track/widget and queue command tests also apply. The new identity regression failed on the old implementation (duplicate actual IDs) and passed after the correction. Final native compilation and 25 targeted queue/queued-flow tests passed sequentially in 4.809 seconds, including twenty-to-one replacement; git diff --check passed. Logs: /private/tmp/djc-queue-identity-before.log and /private/tmp/djc-queue-identity-after.log. The old screenshot's physical display state is not independently reproduced; the identity defect is separately testable. No new installed build claimed.

Subsequent combined installation: iPhone build40313 includes these source changes; native build/signature/install/readback passed. Launch was blocked because the phone was locked. MacBook remains40312; no new physical acceptance. See APPLE_ARTWORK_GESTURE_OVERLAY_40313_20261018.md. Server dosing remains separately qualified/installed by Core.


## Reopened: actual Discover-route recurrence, 18 October03:27

The owner's new screenshot repeats one track after play from Discover. Read-only
copy of the existing physical iPhone diagnostic log now gives decisive client-side
readback:03:27:17,03:27:28 and03:32:34 each report decoded_count=10,
normalized_count=10, distinct_tracks=1, distinct_row_ids=10. The app received ten
same-track records before rendering; its normalizer did not expand one into ten.
The prior row-ID defect remains separately corrected, but did not close this bug.

This proves duplication in the HA response as consumed by the phone, not that
Spotify's actual player queue contains ten entries, nor the exact upstream cause.
Core's local Spotify adapter passes the upstream queue through normalization and
retains repeated tracks. Capture that producer/upstream response and playback
context around Discover play before changing semantics. No blanket client track
deduplication, queue mutation or new fix claim. A bounded request to send this new
diagnosis to the existing Core chat is pending owner answer. Counts-only evidence:
[Discover recurrence](APPLE_QUEUE_DISCOVER_REPRO_20261018.json).
