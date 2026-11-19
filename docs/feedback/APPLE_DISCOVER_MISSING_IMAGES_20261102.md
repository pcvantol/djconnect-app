# Discover missing artwork — installed-source diagnosis

Status: **cause reproduced; producer correction still required**. This is not
an image-loading fix or installed acceptance. Existing Apple draft PR295 remains
the collection point. No Core source, storage or running service was changed.

## Actual observation

Read-only inspection of the local `homeassistant` container found the six exact
recommendations from the owner's screenshot in Music DNA recommendation records.
Only their title, kind, field names and artwork-presence booleans were inspected;
no conversation bodies, credentials, owner identifiers or full records were
exported. Every accepted record lacks both an image URL and an artwork reference.

The installed `_profile_from_memory` and `_sections_from_profile` functions were
then executed in an independent Python process with that matching stored profile
and its one currently valid artwork owner. This did not call providers, create
image grants, change data or enter the running HA process. At this later read,
all six projected items lacked `_artwork` and `image_url`:

| Item from screenshot | Kind | Stored image/reference | Projected image/reference |
| --- | --- | --- | --- |
| HAEVN Discography | playlist | absent | absent |
| Truth Is A Beautiful Thing (Deluxe) | album | absent | absent |
| Come Undone | track | absent | absent |
| Coco Jamboo | track | absent | absent |
| The Sea - Symphonic Version | track | absent | absent |
| Ride The Lightning (Remastered) | album | absent | absent |

The screenshot's Sea image is historical evidence: its earlier grant/cache was
not captured, so this investigation does not assert precisely when or how it
was available. The later read must not be presented as the screenshot's original
HTTP response or the MacBook's actual network trace.

## Causal path

- Core `music_discovery._profile_from_memory.accepted_with_current_artwork`
  attempts to borrow a still-valid server reference for the exact URI from
  existing recent/top-track/artist data. It does not retrieve fresh metadata for
  all accepted recommendations.
- `_items_from_recommendations` can therefore emit a valid recommendation with
  no image reference. `project_discovery_images` only creates an image URL when
  a valid original reference exists; it cannot repair absent source material.
- The bounded artwork subject/media URI allowlist also excludes `playlist`.
  Playlist artwork needs explicit Core support, not an Apple host exception.
- Apple decodes `image_url` and its supported aliases. Both card and detail use
  `resolvedMusicDiscoveryImageURL`: exact HTTPS `i.scdn.co` or the existing
  configured HA route. A missing URL correctly renders the placeholder. Their
  `AsyncImage` input is URL-valued, including refreshed grant identities.

This establishes a real upstream omission for these stored items; it does not
exclude a separate transport failure for a different item with a valid URL.
No unrelated artwork is substituted by title, artist or current playback.

## Exact source identity

The installed `music_discovery.py` and `discovery_artwork.py` match the local
protected Core c874b92a08593ea9cd34c113b311e20d2a02177e files:

| Installed file | SHA256 |
| --- | --- |
| music_discovery.py | 2e613ffed84b4007dc04777938304026af922854a033e26ba789c0033ccd372e |
| discovery_artwork.py | 61dad3ef457e66a502c354ed23a5168a1cee548c4ebe93370ba0f317c7f92e33 |
| music_dna.py | 93820285c2ffda0794263f643fbf434ccb8c8162865e55d6997e22fa7b9d7915 |

Installed `music_dna.py` differs from that Core checkout (local SHA256
8f77afe5b2e7a88f7eacda8b7dd2da7f8ba29c958851a23eb6d89d0660644300).
The reproduction imported the **installed** function, not the newer local copy.
This is a file-level identity check, not a claim that all installed Core matches
protected main.

## Required owning Core correction

Use the existing authenticated Discover read/refresh and existing image fields.
Enrich accepted track/album/artist recommendations from authorized metadata for
the exact provider URI when their artwork evidence is absent/expired. Bound and
deduplicate provider reads, preserve original owner/account/privacy checks before
and after awaits, and issue fresh leases only from current provider evidence.
Do not extend old capture clocks or use arbitrary external URL fetches. Qualify
playlist subjects separately against the existing provider's actual capabilities.
Document any real contract change in canonical Core architecture/SYNC_PROMPTS
before Apple adoption; a new endpoint is not presumed necessary.

Required regression evidence: these mixed six kinds, old accepted records,
expired and unavailable metadata, owner changes during lookup, no provider
support, refresh and delayed image responses. Then verify actual feed image
presence plus successful image bytes and native rendering on the affected
MacBook. Preserve a truthful placeholder for genuinely unavailable artwork.

The Apple lane has prepared this bounded handoff in the existing PR. It has not
opened a competing Core writer, contacted another lane, deployed Core, or
claimed that these missing images are repaired.
