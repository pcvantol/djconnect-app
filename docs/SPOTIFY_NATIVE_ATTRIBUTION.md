# Native Spotify attribution

The native Session renderer uses the unmodified official white full logo from
https://developer.spotify.com/images/guidelines/design/2024-spotify-full-logo.zip
(downloaded 2026-10-08), under the current Spotify integration guidelines:
https://developer.spotify.com/documentation/design

File: `Apps/Shared/Assets.xcassets/SpotifyAttribution.imageset/Spotify_Full_Logo_RGB_White.png`.
SHA256: `14a6a4faf018cf8b2f46a35a272db84b3d6b61a094707f225eb0106ea90ef979`.
No recoloring, cropping, tracing or generated substitute. The original image is
scaled proportionally to 110pt width inside an isolated black background with
16pt clearance. The full logo is also a link to the exact producer album URL.

Only native_delivery v1 qualified current associated-playback cards with original
source/display deadlines, required Spotify attribution, recognized metadata-display
license, safe exact Spotify album link and a loaded packaged logo may render.
There is no Spotify historical Flow grant. Missing asset/link/expiry/authority
fails closed. The source metadata/text remain unchanged. No provider calls,
new account, model/TTS permission or local facts are introduced.

The pinned producer capture uses the existing native-source-policy test scenario
and actual Runtime publication. Its normalized catalog inputs are synthetic,
not a live provider/installed HA qualification.
