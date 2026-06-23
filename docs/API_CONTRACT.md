# Home Assistant API Contract

This document captures the app-to-Home Assistant DJConnect contract used by
`DJConnectCore`.

## Identity

Every app installation needs a stable `device_id`. Home Assistant should treat
the Apple client as an app client identified by `client_type`, not as an ESP
emulator.

The suffix should stay stable across app launches. Explicit user pairing reset
clears the bearer token, generates a new app code, and creates a fresh local
install identity.

```json
{
  "device_id": "djconnect-ios-8F3A2C91B45D",
  "device_name": "DJConnect iPhone",
  "client_type": "ios",
  "firmware": "3.1.23",
  "app_version": "3.1.23",
  "platform": "ios"
}
```

Use `client_type` for DJConnect client identity:

- `ios`
- `macos`
- `watchos`
- `esp32`

Do not use `device_type` for client identity.

## Auth Headers

JSON requests:

```http
Authorization: Bearer <djconnect_bearer_token>
X-DJConnect-Device-ID: <device_id>
Content-Type: application/json
```

Voice upload:

```http
Authorization: Bearer <djconnect_bearer_token>
X-DJConnect-Device-ID: <device_id>
Content-Type: audio/wav
```

Ask DJ clients may include optional context hints on status payloads and raw
voice uploads:

```http
X-DJConnect-Mood: 0-100
X-DJConnect-DJ-Style: warm_radio_dj
X-DJConnect-Memory-Key: <backend-normalized memory key hint>
```

The same values may appear in JSON status payloads as `mood`, `dj_style`, and
`memory_key`. Home Assistant owns DJ Memory and may normalize or ignore the
client-provided memory key. Clients must not store long-term DJ Memory locally.

## Pairing

```http
POST /api/djconnect/pair
Content-Type: application/json
X-DJConnect-Device-ID: <device_id>
```

Payload:

```json
{
  "device_id": "djconnect-macos-8F3A2C91B45D",
  "device_name": "DJConnect Mac",
  "client_type": "macos",
  "firmware": "3.1.23",
  "app_version": "3.1.23",
  "platform": "macos",
  "pair_code": "123456",
  "pairing_code": "123456",
  "pairing_token": "123456"
}
```

Standalone watchOS clients use the same pairing endpoint and token contract,
with `device_id` such as `djconnect-watchos-8F3A2C91B45D`,
`client_type: "watchos"`, and `platform: "watchos"`.

The app-generated code is sent as `pair_code`, `pairing_code`, and
`pairing_token` for compatibility with current Home Assistant integration
builds. The user confirms or enters the same value in the Home Assistant
DJConnect setup flow. The app keeps polling this endpoint with the generated
code until Home Assistant returns a DJConnect bearer token.

Expected response:

```json
{
  "success": true,
  "device_token": "<djconnect bearer token>",
  "device_id": "djconnect-macos-8F3A2C91B45D",
  "client_type": "macos",
  "ha_local_url": "http://192.168.1.13:8123",
  "device_language": "nl",
  "language": "nl"
}
```

The app also accepts `bearer_token` or `token` for compatibility, but
`device_token` is preferred while the Home Assistant route keeps that field
name. After successful pairing, the app stores only the returned DJConnect
bearer token in app-private storage and persists `ha_local_url`, `device_id`, and
`client_type`. App-to-HA runtime traffic must always use `ha_local_url`;
cloud/remote URLs are reserved for Home Assistant-owned Spotify OAuth config
flows and are not used for status, command, or voice requests. Do not use legacy
`ha_url`.

## Local App Web API

The iOS/macOS/watchOS app hosts a small local Web API for Home Assistant -> app
traffic while the app is active/reachable. While the app is pairable, it
advertises Bonjour/mDNS service `_djconnect._tcp` with TXT fields including
`name`, `device_id`, `version`, `paired`, `pairing_status`, `api`, `model`,
`client_type`, `local_url`, `pair_code`, `pairing_code`, `pairing_token`, and
the `/api/device/*` paths. Standalone watchOS discovery uses the same service
with `client_type: "watchos"` and a `djconnect-watchos-...` device ID while the
Watch app is open and pairable.
Once pairing is complete, the app keeps the local HTTP API available while it
is running, but disables Bonjour advertising to reduce network and battery
impact. Explicit pairing reset enables Bonjour advertising again.

User-facing app text calls this endpoint the `Client adres`. The URL shown
in the pairing sheet must be the URL Home Assistant uses for the local
callback. After successful local pairing, the app pins that URL in local state
and keeps it stable until explicit pairing reset.

Open endpoints:

```http
GET /api/device/info
GET /api/device/pairing-info
```

Pairing callback:

```http
POST /api/device/pair
Content-Type: application/json
```

`POST /api/device/pair` accepts this app installation's `device_id`,
`client_type`, visible app `pair_code`, returned `device_token`, HA URLs, and
language metadata. It stores only the DJConnect bearer token and HA/app
settings.

Expected callback payload:

```json
{
  "pair_code": "555293",
  "device_id": "djconnect-macos-8F3A2C91B45D",
  "device_name": "DJConnect Mac",
  "client_type": "macos",
  "device_language": "nl",
  "language": "nl",
  "device_token": "<djconnect bearer token>",
  "ha_local_url": "http://192.168.1.13:8123",
  "assist_pipeline_id": "preferred"
}
```

Success response:

```json
{
  "success": true,
  "device_id": "djconnect-macos-8F3A2C91B45D",
  "client_type": "macos",
  "paired": true
}
```

Protected endpoints require:

```http
Authorization: Bearer <device_token>
```

```http
POST /api/device/command
POST /api/device/dj_response
POST /api/device/forget
```

## APNs Push Registration

Apple clients register APNs device tokens with Home Assistant through the
authenticated Home Assistant endpoint:

```http
POST /api/djconnect/push/register
Authorization: Bearer <device_token>
Content-Type: application/json
```

macOS clients must send `client_type: "macos"` and a matching `device_id` in
the form `djconnect-macos-XXXXXXXXXXXX`, where the suffix is the first 12
alphanumeric characters of the stable app install/client ID. iOS and watchOS use
the same contract with their own `client_type` and device ID prefixes.

Expected macOS payload:

```json
{
  "client_type": "macos",
  "device_id": "djconnect-macos-8F3A2C91B45D",
  "push_token": "<apns-device-token>",
  "push_environment": "sandbox",
  "app_bundle_id": "dev.djconnect.mac",
  "app_version": "3.1.46",
  "locale": "nl-NL",
  "notification_categories": ["ask_dj"],
  "bootstrap_proof": "<short-lived proof when available>"
}
```

The app registers after APNs returns a device token and Home Assistant auth is
available. It retries registration when the APNs token, environment, bundle ID,
app version, locale, Home Assistant pairing, or local registration state
changes. Registration failures must be logged without bearer tokens, APNs
tokens, or `bootstrap_proof` values.

Home Assistant may respond with `push_supported`, `push_registered`,
`push_environment`, and `last_push_error`. Expected recoverable failures include
`missing_bootstrap_proof`, `missing_install_token`, and
`push_relay_unavailable`; normal Ask DJ traffic must continue even when push is
disabled or best-effort.

Unpairing or logout calls:

```http
POST /api/djconnect/push/unregister
Authorization: Bearer <device_token>
```

The Apple app does not implement ESP-only `/api/device/reboot` or
`/api/device/ota` routes.

Demo Mode is not part of the Home Assistant API contract. It is local sample
state for App Store review and UI inspection, and must not create HA devices,
entities, tokens, or backend traffic. Demo Mode may show and play a local sample
DJ announcement, but that audio/text is not a backend response and must not be
treated as successful HA voice validation.

## Status

```http
POST /api/djconnect/status
```

Minimum payload:

```json
{
  "device_id": "djconnect-ios-8F3A2C91B45D",
  "device_name": "DJConnect iPhone",
  "client_type": "ios",
  "ha_pairing_status": "paired",
  "firmware": "3.1.23",
  "app_version": "3.1.23",
  "state": "online",
  "status": "online",
  "battery_percent": 85,
  "language": "nl",
  "theme": "dark",
  "log_level": "info",
  "ha_local_url": "http://192.168.1.13:8123",
  "local_url": "http://192.168.1.105:51193"
}
```

## Commands

```http
POST /api/djconnect/command
```

Command payloads are focused on playback commands and client identity. Do not
send partial status snapshots in `/api/djconnect/command`; use
`/api/djconnect/status` as the authoritative source for client status and
settings mirrored into Home Assistant entities.

Examples:

```json
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"status"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"devices"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"queue","limit":100}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"playlists","limit":100}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"pause"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"play"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"next"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"previous"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"seek_relative","value":15000}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"seek_relative","value":-15000}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_volume","value":35}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_shuffle","value":true}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_repeat","value":"context"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"start_liked_proxy","play":true}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"start_playlist","value":"spotify:playlist:...","play":true}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"play_context_at","value":{"context_uri":"spotify:playlist:...","offset_uri":"spotify:track:..."},"play":true}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_output","value":"Living Room","play":true}
```

The Apple app treats playback-changing commands such as `play`, `pause`,
`next`, `previous`, `seek_relative`, `set_output`, playlist starts, and queue
context starts as state-changing. After posting them, it immediately refreshes
the rich Now Playing snapshot through the `status` command so button state,
album art, progress, output, and volume reflect the backend source of truth.

The Apple app output selector may prepend a local `Geen`/`None` no-output
choice. It must not synthesize local `iPhone standaard` or `Mac standaard`
outputs, because those are not backend playback devices. When `Geen` is
selected, the app blocks playback-start commands until the user chooses a real
backend output.

Home Assistant owns Spotify source and liked/default playlist configuration.
Clients must not show, document, or send user-configurable `spotify_source` or
`liked_proxy_playlist_uri` options in new setup, settings, or command flows.
Playback remains backend-mediated through generic DJConnect commands; older
Home Assistant integrations may defensively tolerate legacy values, but current
clients should not rely on them.

Command responses are transport/command success first and playback-state
second. A response with `success:true` and `playback.has_playback:false` means
the Home Assistant command route worked but Spotify has no active playback; it
is not an app error state. In that case the playback snapshot is valid but
empty, and playback fields may be `null` or empty strings, including
`progress_ms`, `duration_ms`, `volume_percent`, `device.volume_percent`,
`title`, `track_name`, `artist`, `album_name`, `uri`, `context_uri`,
`queue_context`, and artwork URLs. Clients must keep those fields optional and
must not fail decoding because no playback is active.

`seek_relative` uses an integer `value` in milliseconds. Positive values seek
forward in the current track; negative values seek backward. Home Assistant
should clamp the target position to the current track duration and return a
normal command/status response. ESP clients may omit this UI feature.

When the playback backend is unavailable, clients keep the pairing token and
show playback as unavailable with guidance to refresh Spotify authorization in
Home Assistant. When later status/command responses report the backend healthy
again, clients should clear recoverable Spotify authorization messages and
return the DJ request panel to its default microphone instruction.

## Queue

The app loads queue data with:

```json
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"queue","limit":100}
```

Preferred success shape:

```json
{
  "success": true,
  "queue": {
    "items": [
      {
        "title": "Song title",
        "artist": "Artist name",
        "album": "Album name",
        "uri": "spotify:track:...",
        "duration_ms": 213000,
        "album_image_url": "https://..."
      }
    ],
    "context": "spotify:playlist:..."
  }
}
```

Compatibility rules:

- `queue.items` may be empty and that is not an error.
- The Apple app requests up to 100 queue items with `limit:100`. Home Assistant
  should return up to that many real backend queue items and must not pad the
  response with repeated copies of the current track.
- Home Assistant may return `queue` as either `{ "items": [...] }` or a flat
  array; older/debug responses may return flat `items`. The app accepts all
  three forms.
- Queue context may be returned as `queue.context`, top-level `context_uri`,
  or top-level `contextUri`.
- Album art may be returned as `album_image_url`, `media_image_url`,
  `image_url`, or `entity_picture`.
- Queue row playback sends `command:"play_context_at"` with the item URI and,
  when known, `context_uri`.
- The app includes `offset_uri` only for Spotify contexts that support offsets:
  playlist, album, and show contexts. Artist contexts are sent without
  `offset_uri` because Spotify rejects offsets for artist playback.
- When context is absent, the app keeps the row disabled and asks the user to
  refresh Now Playing and the queue; Home Assistant should return a queue
  context whenever queue row playback is supported.

## Client adres Stability

The app must keep the local Client adres stable across successful pairing.
Home Assistant pairs by calling the URL shown by the app, then continues to use
that same endpoint for app callbacks and status/control flows. The app may
restart the local listener when pairing is reset or the install identity changes,
but not as a side effect of accepting `/api/device/pair`.

Fresh installs should present `http://homeassistant.local:8123` as the default
Home Assistant URL. This is only a UI default; runtime app-to-HA requests must
still use the paired `ha_local_url` returned by Home Assistant after pairing.

## Ask DJ Text

```http
POST /api/djconnect/ask_dj/message
Content-Type: application/json
```

The Apple clients send free-form Ask DJ text to Home Assistant. Home Assistant
owns intent classification, current playback lookup, output-device lookup,
Spotify mutations, DJ response generation, and optional TTS. The app must not
hardcode Ask DJ intent families client-side.

iOS, macOS, and watchOS surface DJ requests through Ask DJ. Now Playing does
not expose a separate `DJ verzoek` block on Apple clients. rbpi does not have a
separate rich DJ request UI, and ESP32 remains outside this Ask DJ rich chat UI
contract.

Minimum payload:

```json
{
  "device_id": "djconnect-ios-8F3A2C91B45D",
  "client_type": "ios",
  "text": "Voeg dit nummer toe aan mijn favorieten",
  "audio_response": "auto",
  "dj_style": "warm_radio_dj",
  "memory_key": "djconnect_ios_djconnect-ios-8F3A2C91B45D",
  "metadata": {
    "trigger": "manual"
  }
}
```

`audio_response` may be `auto`, `always`, or `never`; Apple text chat defaults
to `auto`. Missing `audio_url` is a normal successful response for
informational text answers. Replay UI is shown only when
`assistant_message.audio_url` or top-level `audio_url` is present.

`metadata` is optional and backend-owned. Clients may use it to signal context
triggers without adding client-side intent logic. The planned morning startup
flow sends `metadata.trigger == "morning_startup"` with text such as
`Goedemorgen` or `Good morning` when the app starts in the morning and no active
playback is known. Home Assistant should treat this as a normal Ask DJ request
and may answer with text, media, audio, recommendations, or follow-up actions.
Clients must not automatically start music solely because this trigger is sent.

The Home Assistant integration should support at least these Ask DJ intent
families in addition to general informational questions and playback control:

- `favorite_current_track`: like/save the current track. Dutch examples:
  `Voeg dit nummer toe aan mijn favorieten`, `zet dit nummer bij mijn
  favorieten`, `like dit nummer`, `sla deze track op`, `bewaar dit nummer`.
  English examples: `add this song to my favorites`, `like this track`,
  `save this song`, `add the current track to liked songs`.
- `output_devices_info`: answer questions about known playback outputs without
  changing playback. Dutch examples: `Welke speakers zijn er?`, `Welke
  output devices zijn beschikbaar?`, `Waar kan ik muziek afspelen?`. English
  examples: `which speakers are available?`, `what output devices do I have?`.
- `current_output_info`: answer where music is currently playing without
  changing playback. Dutch examples: `Waarop wordt nu muziek gespeeld?`,
  `Op welke speaker speelt dit?`, `Waar speelt de muziek nu?`. English
  examples: `where is music playing now?`, `which speaker is active?`.
- `personalized_mood_playback`: interpret fuzzy mood/energy requests and start
  or queue music that matches the user's current state and known preferences.
  Dutch examples: `Ik voel me moe en geprikkeld, zet wat rustige muziek op die
  ik fijn vind`, `Doe iets ontspannends, ik ben overprikkeld`, `Zet iets op
  waar ik rustig van word`, `Ik wil even kalme muziek zonder vocals`. English
  examples: `I am tired and overstimulated, play relaxing music I will enjoy`,
  `play something calming that I usually like`, `put on something low energy`.
- `change_music_context`: interpret broad requests to hear something else as a
  playback-changing intent. Dutch examples: `Ik wil wat anders horen`, `Doe
  maar iets anders`, `Zet iets anders op`, `Verras me met iets heel anders`,
  `Ik ben dit zat, draai wat anders`. English examples: `I want to hear
  something else`, `play something different`, `put on something else`,
  `surprise me with something completely different`, `I am tired of this, play
  something else`.
- `personal_music_profile_analysis`: describe the user's listening profile over
  a requested period without changing playback. Dutch examples: `Omschrijf eens
  waar ik zoal naar luisterde de afgelopen maand`, `Wat zegt mijn muziek van de
  laatste twee weken over mijn stemming?`, `Welke genres luister ik de laatste
  tijd veel?`, `Maak een profiel van mijn muzieksmaak dit jaar`. English
  examples: `describe what I have been listening to over the last month`,
  `what does my music from the last two weeks say about my mood?`, `which
  genres have I been listening to lately?`, `make a profile of my music taste
  this year`.
- `personal_music_recommendations`: recommend music from the user's known
  listening profile without changing playback unless the user explicitly asks
  to play, queue, or save something. Dutch examples: `Geef me muziek
  aanbevelingen op basis van mijn luisterprofiel`, `Wat zou ik nu leuk vinden
  om te luisteren?`, `Raad me iets nieuws aan dat past bij mijn smaak`,
  `Welke artiesten of albums moet ik eens proberen?`, `Geef me vijf nummers
  die passen bij wat ik de laatste tijd luister`. English examples:
  `recommend music based on my listening profile`, `what should I listen to
  now?`, `recommend something new that fits my taste`, `which artists or
  albums should I try?`, `give me five tracks that match what I have been
  listening to lately`.
- `dj_announcement_request`: generate a radio-style DJ announcement for the
  current or next track without changing playback. Dutch examples: `Geef me een
  leuke aankondiging voor het volgende nummer`, `Kondig het volgende nummer
  alvast aan`, `Doe een radio intro voor wat er nu speelt`, `Zeg iets leuks
  over dit nummer`. English examples: `give me a fun announcement for the next
  song`, `do a radio-style intro for what is playing now`, `say something fun
  about this track`.
- `track_context_info`: answer rich informational questions about the current
  track, artist, release, genre, trivia, samples, concerts, releases, or musical
  connections without changing playback. Dutch examples: `Vertel iets over dit
  nummer`, `Wanneer kwam dit uit?`, `Waar komt deze artiest vandaan?`, `Welke
  samples hoor ik?`, `Heeft deze artiest binnenkort concerten in Nederland?`,
  `Waarom koos je dit nummer?`, `Wat is de connectie met het vorige nummer?`.
  English examples: `tell me about this song`, `what year was this released?`,
  `where is this artist from?`, `what samples are used?`, `does this artist
  have concerts in the Netherlands?`, `why did you choose this track?`.
- `track_musical_analysis`: answer musicological or production-analysis
  questions about the current track without changing playback. Dutch examples:
  `Analyseer dit nummer muzikaal`, `Welke instrumenten hoor ik?`, `Hoe is dit
  nummer opgebouwd?`, `Wat maakt deze productie zo goed?`, `Welke trucjes
  gebruikt de producer hier?`, `Waarom werkt deze drop zo goed?`, `Leg de
  akkoorden en opbouw uit`. English examples: `analyze this track musically`,
  `what instruments are used here?`, `how is this song structured?`, `what
  production tricks are used?`, `why does this drop work?`.

For `favorite_current_track`, Home Assistant should use the current playback
context if the request uses deictic language such as `dit nummer`, `deze track`,
`this song`, or `current track`. It should return a normal DJ text response
after the mutation succeeds. If no current track exists, return `success:false`
or a clear `dj_text` explaining that nothing is playing.

For output-device information, Home Assistant should return a textual summary
in `dj_text` and may include structured `devices` on the response in the
future, but current Apple clients only require text. Do not treat output-info
questions as playback-transfer commands.

For `personalized_mood_playback`, Home Assistant should combine the user's
described mood, current time/context, playback history, likes/skips, DJ Memory,
and available output device. This intent may start playback or add to the queue.
It should avoid brittle keyword-only routing: phrases such as `moe`,
`geprikkeld`, `overprikkeld`, `rustig`, `ontspannen`, `calming`,
`overstimulated`, and `low energy` should be interpreted semantically. If no
preferred output is active, use the current/preferred DJConnect output or return
a clear DJ response asking the user to choose a speaker.

For `change_music_context`, Home Assistant should treat broad phrases like `Ik
wil wat anders horen` as an explicit request to change playback, not merely as
an informational recommendation question. It should use current playback,
recent listening, skips/likes, DJ Memory, mood, and output context to pick
something meaningfully different while still fitting the user. "Different" may
mean a different artist, genre, era, energy level, playlist, or album context;
avoid simply restarting the same track, replaying the current artist by default,
or making a tiny queue-only change unless that is clearly requested. If no
output is active, use the current/preferred DJConnect output or ask the user to
choose one. Return DJ text explaining the switch and include playback metadata
or `audio_url` when available.

For `personal_music_profile_analysis`, Home Assistant should answer questions
about the user's listening patterns over a user-provided or inferred period
without mutating playback. It should use DJ Memory, stored recent tracks,
likes/skips where available, playlist/queue choices, timestamps, moods, and
current playback context. If the user asks `afgelopen x periode`, parse periods
such as `vandaag`, `deze week`, `afgelopen twee weken`, `afgelopen maand`,
`laatste 90 dagen`, or `dit jaar`; if no period is given, default to a recent
window such as the last 30 days and mention that choice.

Useful response material includes:

- most-listened genres, artists, albums, labels, eras, or track clusters;
- recurring moods and listening contexts such as focus, cooking, late evening,
  workouts, background listening, or high-energy sessions;
- energy profile, such as chill versus party, vocal versus instrumental,
  melodic versus rhythmic, familiar versus exploratory;
- notable changes compared with earlier memory, if enough data exists;
- concrete examples from recent listening, while avoiding an exhaustive dump of
  history;
- a short DJ-style summary of what the user's music taste currently says about
  their vibe.

If there is not enough local DJ Memory or playback history for the requested
period, return an honest DJ response explaining the gap and summarize what is
available. Do not invent listening history. This intent should return text and
may include optional source links or images, but it should not start, queue,
like, skip, transfer, or otherwise change playback.

For `personal_music_recommendations`, Home Assistant should combine DJ Memory,
Spotify recently played, Spotify top artists/tracks, liked tracks, skips,
explicit Ask DJ preferences, mood/energy settings, current playback context,
and time/context signals where available. The result should be concrete,
personalized recommendations rather than only a broad genre label.

Useful response material includes:

- recommended tracks, albums, artists, playlists, labels, or eras;
- why each recommendation fits the user's known profile;
- a balance of familiar picks and discovery picks;
- mood/energy fit such as focus, cooking, chill, party, or late-evening
  listening;
- optional images such as album art and optional source links where available.

This intent is informational by default. It should not start playback, queue
tracks, save tracks, like tracks, transfer output, or alter playback unless the
user explicitly asks for an action, for example `speel deze aanbevelingen`,
`zet de eerste op`, `voeg ze toe aan de wachtrij`, or `maak hier een playlist
van`. If the user asks for immediate playback with a fuzzy recommendation such
as `zet iets op dat bij mijn smaak past`, Home Assistant may route to a
playback-capable recommendation flow and should return the executed action in
the response metadata.

When the response contains concrete playable recommendations, Home Assistant
should also return `playback_actions`. Apple clients render these as explicit
`Play Now` buttons. Tapping such a button sends a follow-up command to Home
Assistant, so recommendations remain informational until the user explicitly
chooses one.

```json
{
  "intent": "personal_music_recommendations",
  "action": "none",
  "dj_text": "Ik denk dat deze drie goed passen bij je recente progressive en melodic house profiel.",
  "playback_actions": [
    {
      "id": "spotify:track:123",
      "title": "Track Title",
      "subtitle": "Artist Name",
      "uri": "spotify:track:123",
      "context_uri": "spotify:album:456",
      "offset_uri": "spotify:track:123",
      "kind": "track",
      "image_url": "/api/djconnect/proxy/image/album-456.jpg",
      "reason": "Past bij je recente voorkeur voor melodische opbouw."
    },
    {
      "id": "spotify:album:789",
      "title": "Album Title",
      "subtitle": "Artist Name",
      "uri": "spotify:album:789",
      "kind": "album"
    }
  ]
}
```

The follow-up command is:

```json
{
  "device_id": "djconnect-ios-8F3A2C91B45D",
  "client_type": "ios",
  "command": "ask_dj_play_recommendation",
  "play": true,
  "value": {
    "title": "Track Title",
    "subtitle": "Artist Name",
    "uri": "spotify:track:123",
    "context_uri": "spotify:album:456",
    "offset_uri": "spotify:track:123",
    "kind": "track",
    "memory_key": "djconnect_ios_djconnect-ios-8F3A2C91B45D"
  }
}
```

Home Assistant owns the final Spotify playback decision. It may start a track,
album, artist, or playlist directly from `uri`, or use `context_uri` plus
`offset_uri` when Spotify requires contextual playback.

Backend follow-up and confirmation questions are also returned as
`playback_actions`. Apple clients render them as buttons and send the selected
action back to Home Assistant; the backend owns pending follow-up state,
validation, and final intent execution. A generic yes/no clarification can use
the same action shape:

```json
{
  "intent": "change_music_context",
  "action": "needs_confirmation",
  "dj_text": "Wil je dat ik nu iets anders opzet?",
  "playback_actions": [
    {
      "id": "yes",
      "title": "Ja",
      "kind": "confirmation",
      "action_style": "confirmation",
      "response_value": "yes",
      "command": "ask_dj_followup_response"
    },
    {
      "id": "no",
      "title": "Nee",
      "kind": "confirmation",
      "action_style": "confirmation",
      "response_value": "no",
      "command": "ask_dj_followup_response"
    }
  ]
}
```

The follow-up command should preserve the returned action object where
possible:

```json
{
  "device_id": "djconnect-ios-8F3A2C91B45D",
  "client_type": "ios",
  "command": "ask_dj_followup_response",
  "value": {
    "id": "yes",
    "title": "Ja",
    "kind": "confirmation",
    "action_style": "confirmation",
    "response_value": "yes"
  }
}
```

For `dj_announcement_request`, Home Assistant should not mutate playback. It
should read current playback and, when available, queue/next-track context,
then generate a short DJ-style announcement using the configured DJ personality.
It may return `audio_url` so Apple clients can play or replay the announcement
from the Ask DJ chat.

For `track_context_info`, Home Assistant should enrich current playback context
without mutating playback. Useful response material includes:

- now-playing metadata: album art, title, artist, release year, genre, album,
  label, producer, and track/album links;
- DJ commentary: a short, personality-rich explanation such as why the track is
  notable, what era it belongs to, or why it fits the current set;
- background information: artist origin, trivia, samples used, related artists,
  producer/label connections, or notable remixes;
- concert and release information: upcoming Netherlands shows, relevant
  festivals, recent or upcoming album/single releases, and authoritative links;
- musical connections: why the track was chosen, relation to the previous track,
  BPM/energy transition, shared producer, shared label, genre lineage, or mood
  continuity.

Home Assistant may return this as a concise `dj_text` plus optional `images`
and `links`. Apple clients already support multiple proxied images, multiple
links, and replayable `audio_url`; current clients do not require a separate
structured metadata object. If external artwork, concert pages, artist pages, or
release pages are included, images should be proxied by Home Assistant and links
should be normal `http`/`https` URLs.

For `track_musical_analysis`, Home Assistant should give a musical/production
commentary based on current playback metadata, known facts, available analysis
sources, Spotify audio features if available, and/or carefully phrased audible
inferences. It should not claim exact stem separation, exact chords, exact
instrument lists, or a full transcription unless a real audio-analysis pipeline
or trusted source is available. Useful response material includes:

- instrumentation and sound palette;
- arrangement and song structure, such as intro, build, verse, chorus, break,
  drop, outro, or gradual layering;
- rhythm, groove, BPM/tempo feel, energy curve, and transition qualities;
- harmony, key, chords, melody, motifs, or tension/release when known or safely
  inferable;
- sound design and production techniques such as filtering, sidechain, reverb,
  delay, automation, sampling, layering, risers, or call-and-response;
- mix/mastering impressions such as stereo width, low-end handling, dynamics,
  vocal placement, or how elements leave space for one another;
- why the composition or production works emotionally or functionally in the
  current DJ set.

The response should distinguish known documented facts from likely audible
interpretation. Prefer language such as `waarschijnlijk`, `hoorbaar`, or `lijkt`
when the backend is inferring from metadata/LLM knowledge rather than analyzing
the audio directly.

Expected successful favorite response:

```json
{
  "success": true,
  "intent": "favorite_current_track",
  "action": "spotify_like_current_track",
  "text": "Ik heb Strobe toegevoegd aan je favorieten.",
  "dj_text": "Ik heb Strobe toegevoegd aan je favorieten."
}
```

Expected successful output-info response:

```json
{
  "success": true,
  "intent": "output_devices_info",
  "action": "none",
  "text": "Je kunt afspelen op Marantz Cinema 60, Keuken en Tuin. Marantz Cinema 60 is nu actief.",
  "dj_text": "Je kunt afspelen op Marantz Cinema 60, Keuken en Tuin. Marantz Cinema 60 is nu actief."
}
```

Expected successful personalized mood response:

```json
{
  "success": true,
  "intent": "personalized_mood_playback",
  "action": "spotify_start_personalized_context",
  "text": "Ik zet iets rustigs op met warme, bekende sounds. Geen harde drops, gewoon even landen.",
  "dj_text": "Ik zet iets rustigs op met warme, bekende sounds. Geen harde drops, gewoon even landen."
}
```

Expected successful DJ announcement response:

```json
{
  "success": true,
  "intent": "dj_announcement_request",
  "action": "none",
  "text": "En daar komt-ie aan: een warme, hypnotische plaat die precies tussen focus en zweven in hangt.",
  "dj_text": "En daar komt-ie aan: een warme, hypnotische plaat die precies tussen focus en zweven in hangt.",
  "audio_url": "http://homeassistant.local:8123/api/djconnect/tts/announcement-123.mp3",
  "audio_type": "mp3"
}
```

Expected successful track context response:

```json
{
  "success": true,
  "intent": "track_context_info",
  "action": "none",
  "text": "Strobe kwam uit in 2009 op het album For Lack of a Better Name. De lange opbouw en warme synthlijn maken het een progressive-house klassieker; ik koos hem omdat hij mooi aansluit op de rustige energie van de vorige track.",
  "dj_text": "Strobe kwam uit in 2009 op het album For Lack of a Better Name. De lange opbouw en warme synthlijn maken het een progressive-house klassieker; ik koos hem omdat hij mooi aansluit op de rustige energie van de vorige track.",
  "images": [
    {
      "url": "http://homeassistant.local:8123/api/djconnect/image_proxy/album/strobe",
      "title": "For Lack of a Better Name",
      "subtitle": "deadmau5",
      "kind": "album_art",
      "source": "spotify"
    }
  ],
  "links": [
    {
      "url": "https://example.com/artist/deadmau5/concerts",
      "title": "Concertdata",
      "subtitle": "Komende shows en festivals",
      "kind": "concerts"
    }
  ]
}
```

Expected successful musical analysis response:

```json
{
  "success": true,
  "intent": "track_musical_analysis",
  "action": "none",
  "text": "Muzikaal werkt dit nummer door de langzame spanningsopbouw: eerst een minimale puls, daarna laag voor laag synthpads, percussie en basdruk. De producer gebruikt filtering, herhaling en subtiele automatisering om de drop onvermijdelijk te laten voelen. Zonder audio-stemanalyse zou ik de exacte akkoorden voorzichtig formuleren, maar de harmonie voelt duidelijk gebouwd rond langdurige spanning en release.",
  "dj_text": "Muzikaal werkt dit nummer door de langzame spanningsopbouw: eerst een minimale puls, daarna laag voor laag synthpads, percussie en basdruk. De producer gebruikt filtering, herhaling en subtiele automatisering om de drop onvermijdelijk te laten voelen. Zonder audio-stemanalyse zou ik de exacte akkoorden voorzichtig formuleren, maar de harmonie voelt duidelijk gebouwd rond langdurige spanning en release."
}
```

## Ask DJ History Sync

```http
GET /api/djconnect/ask_dj/history
POST /api/djconnect/ask_dj/clear
```

iOS, macOS, and watchOS sync Ask DJ chat history from Home Assistant. The
backend is the cross-device source of truth for delivered messages, clear
revisions, ambient/system messages, and retention. Clients may keep a local
cache for performance, but must merge server messages into that cache instead
of replacing the full local list with a bounded response window.

History messages may be normal user/assistant messages or assistant-only system
messages. System messages are rendered as subtle DJ/system bubbles and do not
require a preceding user bubble.

```json
{
  "id": "server-...",
  "role": "assistant",
  "message_kind": "system",
  "origin": "spotify_playback_context",
  "text": "Leuk feitje over OK Computer.",
  "intent": {
    "category": "informational",
    "intent": "ambient_music_fact"
  },
  "action": "none",
  "audio_url": null
}
```

Missing `message_kind` defaults to `assistant`.
`origin: spotify_playback_context` represents backend-generated ambient music facts.
`audio_url` is optional; replay UI appears only when an audio URL is present.

The backend should bound history per Home Assistant user/memory key. When a
history limit is reached, the backend should add an assistant-only system
message and return explicit trim metadata so clients can prune their local
cache without parsing display text:

```json
{
  "success": true,
  "user_id": "peter",
  "history_revision": 42,
  "clear_revision": 0,
  "history_limit": 200,
  "history_trimmed_before": "2026-06-20T12:34:56Z",
  "history_trimmed_count": 12,
  "messages": [
    {
      "id": "server-retention-...",
      "role": "assistant",
      "message_kind": "system",
      "origin": "history_retention",
      "text": "Ask DJ heeft de limiet van 200 berichten bereikt. Oudste berichten worden verwijderd.",
      "intent": {
        "category": "system",
        "intent": "history_limit_reached"
      },
      "action": "none",
      "audio_url": null
    }
  ]
}
```

Clients may remove local cached messages older than `history_trimmed_before`.
`clear_revision` remains the authoritative full-clear signal; if it advances,
clients clear local Ask DJ history before applying returned messages.

Backend or proxy error bodies must never be shown raw in Ask DJ UI. Clients log
technical details for diagnostics, but user-facing Ask DJ errors are limited to
short localized messages such as `Ask DJ niet bereikbaar` or `Home Assistant
gaf geen antwoord`.

## Voice

```http
POST /api/djconnect/voice
Content-Type: audio/wav
```

The app uploads raw mono PCM WAV. Home Assistant owns STT, Assist, playback
action, and TTS.

The app does not parse spoken intent families locally and does not need Spotify
credentials or local Spotify Web API calls for voice commands. Home Assistant
handles canonical `current_track` examples such as `Welk nummer draait er nu?`,
`Wat speelt er?`, and `What song is playing?` by reading current playback state
and returning a DJ response. Home Assistant handles canonical
`playback_control` examples such as `Stop muziek`, `Start muziek`,
`Zet harder`, `Zet zachter`, `Volgende nummer`, `Vorig nummer`, `Stop music`,
`Start music`, `Turn it up`, `Turn it down`, `Next song`, and
`Previous song` by mapping them to backend playback commands.

Home Assistant should route STT results into the same Ask DJ intent families as
text requests, including `favorite_current_track`, `output_devices_info`, and
`current_output_info`, `personalized_mood_playback`, and
`dj_announcement_request`, `track_context_info`, and `track_musical_analysis`.

Expected response:

```json
{
  "success": true,
  "text": "Daar gaan we.",
  "dj_text": "Daar gaan we.",
  "audio_url": "http://homeassistant.local:8123/api/djconnect/tts/token.mp3",
  "audio_type": "mp3"
}
```

## Error Semantics

`backend_unavailable`

Playback backend authorization is expired or unavailable. This is not an app
pairing failure. Keep token and pairing state.

HTTP `426` / `version_mismatch`

The app and Home Assistant integration do not share the same `major.minor`
protocol version. Keep token and pairing state. Show that the Home Assistant
integration must be updated. Disable playback/output/queue/playlist/liked/voice
controls, but keep Settings and pairing reset available.

The app also validates `ha_version` / `ha_major_minor` on successful status and
command responses. App `3.1.x` accepts HA `3.1.x` only (`>=3.1.0`, `<3.2.0`).

HTTP `401`/`403`

Pairing is stale or unauthorized. Keep token until explicit user reset.

During unauthenticated app pairing polls, HTTP `401`/`403` means Home Assistant
rejected the current app code or setup identity. The app must stop polling,
keep the visible app-generated code, and ask the user to enter that same code
again in the Home Assistant setup flow. It must not rotate the code
automatically.

HTTP `404`

Integration route is missing or setup is stale. Keep token until explicit user
reset and show setup recovery.
