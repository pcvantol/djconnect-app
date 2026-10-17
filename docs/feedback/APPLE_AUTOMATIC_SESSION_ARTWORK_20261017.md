# Automatic Session artwork presentation

Owner request 2026-10-17: remove the manual purple refresh action; load artwork
for visible contribution bubbles and prefetch nearby entries during scrolling.
Same Apple writer; existing settings3 work remains in place.

Use the existing qualified exact-entry media/prepare contract, followed by the
existing authenticated, no-store image loader. No new backend contract, provider
lookup, borrowed playback cover, persisted image or bulk historical backfill.
Ordinary history/search GETs remain pure. Viewport presentation separately queues
visible retained media entries first, plus one adjacent contribution on each side.
One preparation at a time; replace stale queued work when scrolling, coalesce
in-flight entries, and throttle failed/missing results for 30 seconds. Owner reset
and background cancel the queue. Existing grants, rights, original expiry and
late-response fences remain authoritative. No refresh button or error row.

Qualification: exercise automatic viewport scheduling, repeated visibility,
neighbor bounds, missing/failure throttling and owner/background withdrawal;
compile shared Mac/iOS presentation. Runtime provider availability remains a
separate concern: absence of an authorized source leaves the original text intact.

Validation: shared Swift build PASS; 13 focused artwork/viewport tests PASS
(`/private/tmp/djc-auto-art-tests.log`). Automatic visibility test verifies one
preparation per original target across repeated notifications, no history-read
preparation, failure throttling, text/order preservation and no playback commands.
Window test verifies visible-first ordering, adjacent bound and expired exclusion.
Existing transport tests cover authenticated pixels, subject/rights/expiry fences.
Unsigned iOS build including Watch dependencies PASS
(`/private/tmp/djc-auto-art-ios-build.log`); shared Mac source compiled with SwiftPM.
No installation or physical scrolling/provider acceptance claimed in this change.

## Actual iPhone root-cause audit40249→40250

Capability and grant admission succeeded, but three ready playback-observed image
GETs failed400: the client sent identity headers but omitted required device_id
and client_type query fields. Core profile-context validation requires the query
client type. The fixture had checked headers only.

The client now shares a paired-owner GET builder for history and private image
reads, retaining no-store/redirect/byte/decode/expiry boundaries. Regression
assertions cover the exact identity query and no-store. Same real signed iPhone
probe on40250 loaded pixels for all three previously failing projections. One
real dj_moment remains unavailable/insufficient_identity from prepare; forwarded
to the sole Core writer. This is not repaired by borrowing current playback art.
Native scroll presentation acceptance remains separately recorded. No provider
credentials, original text or private resource URLs were exported.

Actual40250physical scroll snapshot visually verifies automatically loaded art
in playback and DJ-contribution bubbles with no refresh tap. The first UI probe
failed an invalid isHittable heuristic on decorative images; it is retained as
failed. The separate snapshot probe reports5loaded image elements and its actual
screenshot was inspected. Artwork renderer/pixel success does not repair the
separate insufficient_identity producer outcome or qualify every subject/target.
