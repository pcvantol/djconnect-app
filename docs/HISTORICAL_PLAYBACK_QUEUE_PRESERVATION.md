# Observed recording play button: queue preservation

Owner request, 2026-10-22: a play control on an observed-music card must start
that exact recording immediately, replacing the current recording, while the
remaining queue retains its items and their order. The request describes play
now, not ordinary append-to-end, a playlist restart or a reconstructed queue.

## Existing producer and consumer gap

Protected Core c7d6219a9ba1deb427ec436ce4cf132543db9d0f provides
`historical_exact_track_playback` v1. Timeline/open reads can negotiate
`historical_playback_contract_version:1`. A retained eligible observation can
then return `historical_track` / `play_history_item`, with only the original
session/entry reference. Core reopens that reference and owns exact recording,
source/account, retention and output-choice checks. Apple must never derive a
play URI from the card's text, title, artwork or Spotify link.

The existing Apple timeline read does not negotiate this optional contract and
its history DTO does not decode these optional actions. The generic card already
supports a white replay button, but production observed rows have no admitted
callback. This explains a missing control at source level; the photographed
row's actual eligibility has not been read or proven.

The existing Core historical action resolves an exact recording and calls the
common recommendation handler. A track reaches `run_music_command(..., "play",
uri)`, then `SpotifyBackend.play` sends `PUT /me/player/play` with a URI list.
The historical contract and its inspected tests do not establish the requested
queue-prefix/remainder invariant. Apple must not label that path as queue
preserving without producer qualification.

Spotify's documented queue endpoint has no insertion-position argument; its
scope documentation describes adding at the end. The queue endpoint also says
execution ordering with other Player endpoints is not guaranteed. A client-side
append-plus-next sequence therefore does not prove the requested operation.
References:
- https://developer.spotify.com/documentation/web-api/reference/add-to-queue
- https://developer.spotify.com/documentation/web-api/concepts/scopes
- https://developer.spotify.com/documentation/web-api/reference/start-a-users-playback

## Required owning-lane delivery

- Core must establish supported provider behavior for immediate exact-recording
  playback while preserving the queue remainder, or report typed unsupported.
  No silent queue rebuild, drop, reorder, playlist mutation or synthetic success.
- Reuse the existing paired effect owner and exact retained session/entry action.
  Existing output selection, original authority/expiry, stable operation identity,
  cancellation and uncertain-outcome duplicate prevention remain required.
- Causal producer tests need a populated queue, repeated recordings/editions,
  no active output and chooser continuation, concurrent taps, provider failure,
  uncertain completion, owner/source withdrawal and original-row deletion.
- Apple then negotiates the qualified contract, decodes only closed original
  server actions, connects the existing white per-card control and preserves
  its current owner/row/retention/foreground checks. Unknown or unsupported
  actions confer no dispatch permission.
- Source/build, actual dispatch, queue readback and physical/audible acceptance
  are distinct. No live playback or queue mutation was used for this diagnosis.

Specific authorization for the necessary Core handoff has been requested from
the owner. No cross-repository mutation or unqualified button dispatch is made.
