# Compact observed-playback card and single Spotify footer — 40303

Owner requested removal of the duplicate Spotify logo directly under the artwork,
retaining the footer logo. On iPad/Mac the artwork and playback heading/title/
artist/album now share a horizontal block, with date, source links and the single
Spotify footer below it. iPhone retains the vertical information layout.

SessionArtworkView can defer attribution to its enclosing card; default behavior
remains attribution visible for other callers. History cards suppress the inner
logo only when their footer supplies the Spotify link, choosing the admitted
artwork source when present. Native Moment cards also avoid repeating an existing
Spotify footer. No artwork grant, source URL, expiry or playback authority was
created/renewed. Missing footer attribution does not silently remove the artwork
renderer attribution fallback.

Wide observed-playback cards use the backend's structured title/artist/album;
unstructured legacy text remains a fallback. Search highlights are projected
from original UTF16 ranges into their field, preserving Unicode boundaries.
No text parsing into invented metadata or change to the retained original text.

Swift parse/diff checks, native signed iOS40303 build, strict signature and
ordinary-product checks PASS. Unicode/field highlight regression PASS0.001s.
iPhone40303 installed, independently read back and launched. Device updates
remain iPhone only under the standing installation direction; the new
iPad/Mac layout is source work until those devices receive a later installation.
Physical viewport acceptance and a new full-suite PASS are not claimed.
Private receipts: `/private/tmp/djc-playback-card-40303/` and
`/private/tmp/djc-playback-card-40303-ios-build.log`.
