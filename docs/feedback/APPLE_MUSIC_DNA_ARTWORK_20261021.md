# Music DNA artwork — 2026-10-21

Status: OPEN. Producer correction requested from Core with explicit user
authorization. No source or installed artwork fix is claimed.

## Confirmed cause

An ordinary paired Music DNA profile read succeeded. Its response contained
nested private `artwork` references, but no display `image_url`,
`album_image_url`, `artist_image_url` or `image_expires_at` fields. Personal
response contents and identifiers are deliberately excluded from this report.

In the inspected Core source, `music_dna.py` returns `_profile_payload(memory)`.
Compact tracks/artists retain artwork references. The existing scoped image
delivery projection in `discovery_artwork.py` handles Discovery sections/items;
it does not project the Music DNA profile. Retained provider asset references
are not usable client display URLs.

Apple's `DJConnectMusicDNATrack` and `DJConnectMusicDNANameValue` already decode
display URL fields. `resolvedMusicDNAArtworkURL` resolves permitted URLs through
the shared artwork route. Its Discovery fallback requires the same Profile,
exact URI and kind, a current lease and one unambiguous reference. That fallback
cannot supply the complete dashboard.

## Remaining Apple scope after producer contract

- Adopt Core's synthetic fixtures and exact display URL/expiry contract.
- Render track and artist artwork in recent/favorite/top-range cards.
- Add the supplied identity and display fields to playtime artist/album,
  repeat-magnet, taste-anchor and positive-signal models where Core provides
  them, then connect those cards to the shared artwork loader. Several of these
  currently render static icons or text only.
- Cover exact identity, album edition, expiry, changed owner, missing images,
  relative delivery URLs and active local/remote routing. Compile the shared
  UI for macOS and iOS; qualify actual installed delivery separately.

Do not derive CDN URLs from private asset IDs, match images by display names,
invent artist identities, renew expired grants through a client transformation,
or start per-card provider lookups. Portable exports must not acquire private
delivery references.

No new provider/model call, forced profile refresh, setting, playback command,
installation or deployment was performed for this diagnosis. The Core handoff
contains technical contract findings only, without personal profile contents,
identifiers or private evidence locations.
