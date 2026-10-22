# Partial artwork in Discover — 2026-10-22

Status: OPEN, producer repair requested from the existing Core writer.

The owner's screenshot shows one loaded cover alongside placeholders in
“More like your earlier choices”. A new ordinary GET of the configured server's
Discovery feed used the existing paired Mac identity. Authentication stayed in
RAM. The response and images were inspected in RAM; no personal response,
identifiers, image addresses, credentials or artwork pixels were exported.
Only aggregate counts were recorded:

- Feed HTTP200; accepted recommendations: six items (four tracks, one album,
  one playlist).
- One item has `image_url`; five have none. No delivered image URL is expired.
- The supplied image downloads successfully (HTTP200, valid image signature).

This proves missing display references for five cards in this current read.
It does not establish a failure of AsyncImage for those cards, or explain every
historical screenshot. No feed-refresh POST, model/provider lookup, playback,
pairing change or server mutation was performed.

Apple's current renderer passes permitted delivered addresses to AsyncImage.
The inspected Core source projects an image only from a qualified exact-owner
private reference; accepted-recommendation recording reuses listening-profile
references and does not preserve arbitrary client-supplied images. The earlier
2026-10-16 missing-artwork diagnosis remains historical evidence of its own read.

The existing Core writer received the fresh aggregate evidence and a request
for a bounded producer repair. Original owner, exact subject/album edition,
privacy and expiry boundaries remain required. A current cover or name match
cannot fill these placeholders. Apple acceptance remains open until a qualified
producer correction delivers actual references and native pixel rendering is
verified.
