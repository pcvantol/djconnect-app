# DJConnect iOS/macOS/watchOS App Handoff

This handoff is for building native iOS, macOS, and watchOS DJConnect clients
that use the same Home Assistant custom integration backend as the ESP32
firmware.

The app should be functionally comparable to the ESP device at the integration
contract level, but it is not an ESP emulator. Use `client_type` to identify the
client family:

- iOS app: `ios`
- macOS app: `macos`
- watchOS app: `watchos`
- ESP firmware remains: `esp32`

Do not use `device_type` for DJConnect client identity. `device_type` may only
appear as playback-output metadata if returned by the backend.

## Architecture

Home Assistant is the trusted DJConnect backend for:

- pairing;
- bearer-token lifecycle;
- backend playback commands;
- Spotify OAuth and future playback backend credentials;
- Assist/STT/TTS;
- OTA/update offers for device clients where applicable;
- native Home Assistant entities.

The Apple app owns:

- native UI;
- local app state;
- local bonus games and local highscores;
- local audio recording if voice/PTT is implemented;
- local playback of returned DJ response audio, if desired;
- local notifications, menus, or widgets, if desired.

The app must not store or request Spotify OAuth secrets, refresh tokens, client
secrets, Sonos credentials, Home Assistant long-lived access tokens, or playback
backend credentials. The only DJConnect credential owned by the app is its
DJConnect bearer token issued by the integration.

## Technical Design Decisions

Keep [TECHNICAL_DESIGN_DECISIONS.md](TECHNICAL_DESIGN_DECISIONS.md) updated for
every release. It is the reverse-engineered source for code-level design
patterns, coding conventions by language, and the framework/library/license
inventory.

## First-Run Onboarding

The Apple app shows a one-time welcome screen after installation. It must use
DJConnect branding and link setup to:

```text
https://djconnect.dev/start
```

User-facing copy must make two prerequisites clear:

- setup is done in Home Assistant through the DJConnect integration;
- a supported Home Assistant-side music backend is required for playback.

The app must not request Spotify or Music Assistant credentials during
onboarding. Backend credentials belong to the Home Assistant integration.

## Unpaired Runtime UX

When the Apple app has no valid DJConnect bearer token, the main runtime UI is
blocked by a pairing sheet. The sheet must show:

- DJConnect banner/branding.
- Home Assistant setup context.
- Local Home Assistant URL plus pairing code/QR entry on iOS/macOS; Watch
  pairing shows iPhone companion status.
- Copyable app-generated pairing code.
- Pairing progress while Home Assistant calls the client API or while polling
  is active.
- A green success state after pairing, followed by a `Let's Start!` action.

The wakeword activation prompt may be shown after the user leaves the pairing
success sheet, not on top of it.

For App Store review and UI auditing, the pairing sheet may expose Demo Mode.
Demo Mode uses local sample playback, queue, playlist, output, and DJ
announcement state. It must not store a bearer token, create HA entities, or
be treated as backend validation. Demo Mode is session-only: after app restart,
an unpaired client returns to the pairing sheet. Exiting Demo Mode from
Settings must return to the initial unpaired state with Now Playing behind the
pairing sheet. The Demo Mode microphone action may show and play a local sample
DJ announcement. It must remain visibly local demo behavior and must not call
Home Assistant.

If the user resets pairing, the app should clear runtime playback/output/
queue/playlist state, navigate back to Now Playing, and present the pairing
sheet over that initial state.

## Local Games

The Apple app may include the same local bonus games as the ESP client:

- Paddle Rally
- Meteor Run
- Sky Dash
- Maze Chase

Games are local-only UI features. They must not call Home Assistant, create HA
entities, affect pairing state, require Spotify playback, or send DJConnect
status/command payloads. Highscores may be stored in app-local preferences and
may be cleared by app reinstall or local app data reset. Games should remain
available in Demo Mode because they are not backend validation. Games should
lazy start behind a tap-to-play overlay, and leaving the Games page should stop
the local loop and reset every game to its idle overlay. When a game is active,
keyboard arrows and space should be handled by the game surface and should not
trigger sidebar, tab, or page navigation.

## Identity

Use a stable `device_id` per app installation.

Suggested format:

- iOS: `djconnect-ios-<stable-install-id>`
- macOS: `djconnect-macos-<stable-install-id>`

The suffix should be stable across app launches, but should reset if the user
explicitly resets DJConnect pairing in the app. Avoid exposing Apple account,
device serial, hostname, WiFi SSID, or other private identifiers in the id.

Recommended iOS fields:

```json
{
  "device_id": "djconnect-ios-8F3A2C91B45D",
  "device_name": "DJConnect iPhone",
  "client_type": "ios",
  "firmware": "3.2.0",
  "app_version": "3.2.0",
  "platform": "ios"
}
```

Recommended macOS fields:

```json
{
  "device_id": "djconnect-macos-8F3A2C91B45D",
  "device_name": "DJConnect Mac",
  "client_type": "macos",
  "firmware": "3.2.0",
  "app_version": "3.2.0",
  "platform": "macos"
}
```

Recommended watchOS fields:

```json
{
  "device_id": "djconnect-watchos-8F3A2C91B45D",
  "device_name": "DJConnect Watch",
  "client_type": "watchos",
  "firmware": "3.2.0",
  "app_version": "3.2.0",
  "platform": "watchos"
}
```

The watchOS client is companion-only. It keeps its own Watch identity and
compact UI cache, but pairing, DJConnect bearer-token ownership, Home Assistant
transport selection, APNs registration, status refresh, Ask DJ history sync,
playback actions, follow-up actions, idle suggestions, clear history, and voice
upload are mediated by the paired iPhone over WatchConnectivity. The Watch does
not store `ha_remote_url`, does not choose local/remote transport, does not host
a local Web API, does not advertise Bonjour/mDNS, exposes voice through `Ask
DJ`, and keeps wake phrase detection foreground-only. When the iPhone sends a
request to HA on behalf of the Watch it preserves `client_type:"watchos"` and
the Watch `device_id`.

Ask DJ is the single Apple-client DJ interaction surface. iOS, macOS, and
watchOS expose DJ requests through Ask DJ chat/PTT and synced Ask DJ history;
Now Playing should not reintroduce a separate `DJ verzoek` block. rbpi did not
have that separate UI block, and ESP32 remains a firmware/device client without
the Apple Ask DJ rich chat UI.

For `Ask DJ`, the Watch may send mood, DJ style, and a memory key hint, but DJ
Memory itself belongs to the Home Assistant integration. This lets a user ask
for a calmer track on Watch and later ask from Mac why that track was chosen.

Ask DJ history is backend-synchronized and locally cached. Clients must merge
server history into the cache instead of replacing it with a bounded response
window. Backend `clear_revision` clears the local chat; backend
`history_trimmed_before` lets clients prune old cached messages when the
server-side history limit is reached. Assistant-only `message_kind: system`
messages such as ambient music facts and history-retention notices must render
without requiring a preceding user bubble. When the Ask DJ screen opens,
clients should scroll the loaded timeline to the newest message by default,
including after the first async history response.

Ask DJ output-device responses may include output `playback_actions`. Apple
clients render them as vertical speaker rows with the name on the left and an
`Actief`/`Activeer` button on the right. Tapping a row sends the backend-owned
output command and preserves the backend-returned action object where possible;
clients do not infer speaker switching from free text. Ask DJ message and
command payloads include `device_id`, `device_name`, `client_id`, and
`client_type`, with `client_id` currently matching `device_id`.

The Apple clear-history action calls
`POST /api/djconnect/ask_dj/history/clear`. Home Assistant should scope the
clear to the relevant user/client/history namespace, increment
`clear_revision`, and keep returning that revision on later history/message
responses so all Apple clients can clear their local caches deterministically.

Raw backend/proxy/decode bodies, including HTML error pages, must never appear
in the Ask DJ chat UI. Keep the details in diagnostics logs and show only
localized user-facing messages such as `Ask DJ niet bereikbaar` or `Home
Assistant gaf geen antwoord`.

The HA integration currently uses `firmware` as the common client version field
for protocol compatibility checks. App clients may also send `app_version`, but
must keep `firmware` populated unless the backend contract is changed.

## Version Contract

DJConnect clients and the HA integration must share the same `major.minor`
protocol version:

- HA `3.0.z` accepts clients `3.0.z`.
- HA `3.1.z` accepts clients `3.1.z`.
- HA `3.2.z` accepts clients `3.2.z`.
- Patch versions may differ.
- `0.0.0` is reserved as a dev-client escape hatch.

If HA returns HTTP `426` with `error: "version_mismatch"`, the app must not
reset pairing or discard the token. Show an update-required state and pause
command/voice retries until the user updates the app or integration.

The Apple app also validates `ha_version` / `ha_major_minor` fields on normal
status and command responses. App `3.2.x` requires HA integration `3.2.x`
(`>=3.2.0`, `<3.3.0`). If HA is outside that range, the app must show a clear
message to update the Home Assistant integration, disable playback/output/
queue/playlist/liked/voice controls, and keep Settings plus pairing reset
available.

Expected response:

```json
{
  "success": false,
  "error": "version_mismatch",
  "message": "DJConnect Home Assistant integration and device firmware major.minor versions must match.",
  "ha_version": "3.2.0",
  "ha_major_minor": "3.2",
  "firmware": "3.2.0",
  "firmware_major_minor": "3.1"
}
```

## Pairing Flow

The app should pair with the Home Assistant DJConnect integration, not directly
with Spotify or any playback backend.

The app needs:

- Home Assistant local base URL;
- DJConnect pairing code shown by Home Assistant and entered/scanned by the
  app;
- DJConnect bearer token returned/stored by the integration.
- `ha_local_url` returned by the integration after pairing.
- Optional `ha_remote_url` returned by the integration after successful local
  pairing.
- Optional `assist_pipeline_id` returned by the integration for future voice
  flow selection.

Recommended user flow:

1. User starts Apple-client pairing in the Home Assistant DJConnect setup flow.
2. Home Assistant shows a pairing code or QR code.
3. The Apple app is on the same LAN and the user enters or scans that code.
4. The app posts the code and canonical client identity to local
   `/api/djconnect/pair`.
5. Integration creates or returns a DJConnect bearer token for the app runtime.
6. App stores only the DJConnect bearer token, client identity, `ha_local_url`,
   optional `ha_remote_url`, and protocol/backend metadata in app-private
   storage.
7. App starts sending authenticated status and command payloads with
   `device_id` and `client_type`.
8. iOS/macOS use `ha_local_url` first, fall back to `ha_remote_url` after
   successful local pairing when local access is unavailable, and report
   `offline` when neither URL works.

Remote pairing is not allowed. If only the remote URL is reachable during
pairing, the app must tell the user to complete pairing on the same local
network as Home Assistant.

Fresh app installs should default the Home Assistant URL input to:

```text
http://homeassistant.local:8123
```

Users can replace it with an IP-based local URL when mDNS is unavailable.

The iOS/macOS app is an app client, not ESP hardware, and no longer exposes a
Home Assistant-callable local `/api/device/*` Web API or `_djconnect._tcp`
Bonjour/mDNS service. Removed Apple app routes include `/api/device/info`,
`/api/device/pairing-info`, `/api/device/pair`, `/api/device/command`,
`/api/device/dj_response`, and `/api/device/forget`. The Watch itself never
exposes a LAN endpoint, and the active Watch runtime is a WatchConnectivity
proxy rather than an iPhone-hosted Home Assistant callback endpoint.

Implemented initial app contract:

```http
POST /api/djconnect/pair
Content-Type: application/json
X-DJConnect-Device-ID: <device_id>
```

```json
{  "device_id": "djconnect-macos-8F3A2C91B45D",
  "device_name": "DJConnect Mac",
  "client_type": "macos",
  "firmware": "3.2.0",
  "app_version": "3.2.0",
  "platform": "macos",
  "pair_code": "123456",
  "pairing_code": "123456",
  "pairing_token": "123456"
}
```

Expected completion response:

```json
{
  "success": true,
  "device_token": "<djconnect bearer token>"
}
```

While Home Assistant has not accepted the code yet, the app keeps waiting and
does not show a manual Pair button. The app sends the same app-generated code
as `pair_code`, `pairing_code`, and `pairing_token` for compatibility with
current HA builds. HTTP 401/403 during unauthenticated pairing polling means
Home Assistant rejected the current code or setup identity; stop polling, keep
the visible app code, and ask the user to enter that same code again in Home
Assistant. Do not rotate the code automatically.

Bearer token storage:

- iOS: app-private storage scoped to the app container.
- macOS: app-private storage scoped to the app container.
- watchOS: app-private storage scoped to the Watch app container.
- Never log the token.
- Never include the token in diagnostics exports.

## Diagnostics And Crash Reports

The app may detect that the previous session ended uncleanly. On the next
launch it shows a user-mediated crash report prompt. The prompt may:

- copy redacted diagnostics to the clipboard;
- open a prefilled GitHub issue in `pcvantol/djconnect`.

The app must not upload crash logs automatically, embed GitHub credentials, or
send diagnostics without explicit user action. Diagnostics must redact bearer
tokens, Home Assistant tokens, Spotify secrets, temporary audio URLs, and other
token-like fields.

The app may persist a local redacted rolling diagnostic logfile in Application
Support, currently `DJConnect/Logs/djconnect.log`, so logs survive app restarts
and crash investigation. The file must be bounded by retention and size limits,
loaded into the Logs screen on restart, and deleted when the user clears logs.
It must never be uploaded automatically.

## Debug Logging Contract

The app should provide consistent DEBUG-level diagnostics for:

- user actions, such as refresh, transport controls, output changes, queue item
  starts, playlist starts, Demo Mode entry/exit, pairing reset, wakeword prompt
  actions, and voice/PTT actions;
- navigation/recovery flows, such as pairing success dismissal, Demo Mode exit,
  pairing reset returning to Now Playing, and crash recovery prompts;
- Home Assistant API calls, always including the HTTP method/path and status
  code;
- iPhone-mediated Watch proxy actions, without token, prompt, or audio payload
  contents.

Do not log Authorization headers, bearer tokens, pairing codes, Spotify
tokens, Home Assistant long-lived tokens, passwords, or raw request/response
bodies that may contain secrets. Redacted response summaries are acceptable for
diagnostics.

Permission UX:

- Microphone and Speech Recognition can be requested from Settings before
  push-to-talk or foreground wakeword use.
- Because current iOS/macOS beta builds have shown crashes when directly
  invoking `SFSpeechRecognizer.requestAuthorization`, the Apple app should not
  call the Speech Recognition system prompt from the generic Settings
  permission button. If speech access is already granted, accept it; otherwise
  log a non-secret diagnostic line and keep stemactivatie unavailable until the
  user enables speech access in system settings.
- Local Network is declared for LAN/Bonjour access, but Apple does not provide
  a reliable explicit preflight API. The app should not fake a request button;
  iOS/macOS show the system prompt when local network work first occurs.
- iPhone permission rows should remain compact enough to scan without excessive
  vertical whitespace.

## Monkey Test Mode

Apple app Debug builds may support `--monkey-testing`. This mode is explicitly
non-destructive: it starts in local Demo Mode, skips first-run/pairing/crash
blocking sheets, avoids local Client API startup, avoids Home Assistant calls,
and is intended only for random UI navigation/tap stress tests. It must not
reset real pairing, alter locally stored tokens, call Spotify/Home Assistant, or be
treated as backend validation.

Current UI monkey coverage includes iOS and macOS smoke tests for navigation
through Now Playing, Queue, Playlists, Games, Settings, and About. Long repeated
soaks should only be recorded as release verification when they finish without
interruption.

Auth headers for app to HA:

```http
Authorization: Bearer <djconnect_bearer_token>
X-DJConnect-Device-ID: <device_id>
Content-Type: application/json
```

For raw voice audio:

```http
Authorization: Bearer <djconnect_bearer_token>
X-DJConnect-Device-ID: <device_id>
Content-Type: audio/wav
```

## Status Endpoint

Post client status to:

```http
POST /api/djconnect/status
```

Minimum payload:

```json
{
  "device_id": "djconnect-ios-8F3A2C91B45D",
  "client_type": "ios",
  "ha_pairing_status": "paired",
  "firmware": "3.2.0",
  "app_version": "3.2.0",
  "state": "online",
  "status": "online",
  "battery_percent": 85,
  "language": "nl",
  "theme": "dark",
  "log_level": "info",
  "ha_local_url": "http://192.168.1.13:8123"
}
```

Optional app-specific fields:

```json
{
  "platform": "ios",
  "os_version": "18.5",
  "app_build": "30900",
  "local_audio_supported": true,
  "voice_supported": true,
  "screen_state": "on",
  "network_type": "wifi"
}
```

Status responses may include:

```json
{
  "success": true,
  "client_type": "ios",
  "device_language": "nl",
  "language": "nl",
  "backend_available": true,
  "playback": {}
}
```

Use `device_language`/`language` to update app UI language only if the app
supports remote language sync. Otherwise keep it as informational state.

## Playback Commands

Send generic playback commands to:

```http
POST /api/djconnect/command
```

All command payloads must include `device_id` and `client_type`. Keep command payloads focused on playback commands and client identity. Do not
send partial device-status snapshots in `/api/djconnect/command`; use
`/api/djconnect/status` as the authoritative source for client status and
settings mirrored into Home Assistant entities.

Do not expose or send Home Assistant's removed Spotify override settings in
new client UI or setup flows. `spotify_source` / "Spotify source override" and
`liked_proxy_playlist_uri` / "Standaard playlist override" are no longer
client-configurable. Backend playback remains owned by the HA DJConnect
integration; clients continue to send generic playback commands only.

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
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_output","value":"Living Room","play":true}
```

For playback-changing commands, the app refreshes the rich Now Playing snapshot
immediately after the command returns. Home Assistant should continue returning
the same playback shape for the `status` command so play/pause state, album art,
progress, output, and volume can update without waiting for a later user action.

The Apple output selector should contain only a local `Geen`/`None` no-output
choice plus real backend devices from Home Assistant. Do not expose synthetic
`iPhone standaard` or `Mac standaard` output choices: they are not real
playback targets and selecting `Geen` must block playback-start commands until
a real backend device is selected.

Apple app clients may expose current-track seek controls. Use
`command:"seek_relative"` with an integer `value` in milliseconds. Positive
values seek forward and negative values seek backward. Home Assistant should
clamp the resulting position to the current track and return the usual command
response. ESP clients may skip this UI capability.

Queue loading uses `command:"queue"` with `limit:100` and should return:

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

The app accepts `response.queue.items` first and falls back to flat
`response.queue` arrays and `response.items`. Queue context may be returned as
`queue.context`, top-level `context_uri`, or top-level `contextUri`. Queue album
art aliases are `album_image_url`, `media_image_url`, `image_url`, and
`entity_picture`. Empty queue items are not an error. Home Assistant should
return up to 100 real backend queue items and must not pad the queue with
repeated current-track entries. Queue row playback sends
`command:"play_context_at"` with `context_uri` included when known. The app only
adds `offset_uri` for Spotify contexts that support offsets, such as playlists,
albums, and shows; artist contexts are sent without `offset_uri` to avoid
Spotify API offset errors. The app no longer sends unsupported legacy
`play_queue_item` or `play_uri` commands.

The app no longer exposes a Client adres or receives Home Assistant callbacks
on `/api/device/*`. Playback and queue actions always travel from the Apple
client to Home Assistant through `/api/djconnect/command` using the selected
local or remote HA transport.

Expected success shape:

```json
{
  "success": true,
  "playback": {
    "has_playback": true,
    "is_playing": true,
    "track_name": "Song",
    "artist_name": "Artist",
    "album_image_url": "https://...",
    "progress_ms": 12345,
    "duration_ms": 180000,
    "volume_percent": 32,
    "shuffle": false,
    "repeat_state": "off",
    "device": {
      "id": "spotify-device-id",
      "name": "iPhone",
      "type": "Smartphone",
      "active": true,
      "supports_volume": true,
      "volume_percent": 32
    }
  }
}
```

Command responses are transport/command success first and playback-state
second. A response with `success:true` and `playback.has_playback:false` means
the Home Assistant command route worked but Spotify has no active playback; it
is not an app error state. In that case the playback snapshot is valid but
empty, and playback fields may be `null` or empty strings, including
`progress_ms`, `duration_ms`, `volume_percent`, `device.volume_percent`,
`title`, `track_name`, `artist`, `album_name`, `uri`, `context_uri`,
`queue_context`, and artwork URLs. Clients must keep those fields optional and
must not fail decoding because no playback is active.

Backend unavailable is not an auth failure:

```json
{
  "success": false,
  "error": "backend_unavailable",
  "message": "Spotify authorization has expired or was revoked. Reauthorize DJConnect.",
  "backend_available": false,
  "playback": {}
}
```

When backend unavailable:

- keep pairing/token;
- show playback unavailable and point the user to Spotify authorization in
  Home Assistant;
- if the backend later reports healthy/available again, clear recoverable
  Spotify authorization DJ request text and restore the default microphone
  instruction;
- do not send the user through app pairing again;
- throttle retries enough to avoid UI churn.

When HA returns 401/403 on authenticated routes:

- mark pairing stale/unauthorized;
- keep token until the user explicitly resets pairing;
- show setup-again guidance.

During unauthenticated pairing polling, 401/403 responses with pairing-code
messages stop polling and show code-mismatch recovery guidance.

When HA returns 404:

- treat as integration route missing or stale pairing;
- do not erase the locally stored token automatically;
- show integration/setup recovery.

## Voice/PTT

If implementing push-to-talk:

1. App records mono PCM WAV.
2. App uploads raw WAV to HA:

```http
POST /api/djconnect/voice
Content-Type: audio/wav
Authorization: Bearer <djconnect_bearer_token>
X-DJConnect-Device-ID: <device_id>
```

3. HA owns STT, Assist, playback action and TTS.
4. HA returns DJ text and optional audio URL.
5. App displays text and may play returned WAV/MP3 audio locally.

Canonical voice examples live in
`pcvantol/djconnect/examples/voice_intents.json` and
`pcvantol/djconnect/VOICE_INTENT_DATA.md`. Current HA-handled families include:

- `current_track`: `Welk nummer draait er nu?`, `Welk nummer speelt er nu?`,
  `Wat draait er?`, `Wat speelt er?`, `Wat is dit?`, `What song is playing?`,
  `What track is playing now?`, `What's playing?`, `Which song is this?`
- `playback_control`: `Stop muziek`, `Start muziek`, `Zet harder`,
  `Zet zachter`, `Volgende nummer`, `Vorig nummer`, `Stop music`,
  `Start music`, `Turn it up`, `Turn it down`, `Next song`,
  `Previous song`
- `favorite_current_track`: `Voeg dit nummer toe aan mijn favorieten`,
  `zet dit nummer bij mijn favorieten`, `like dit nummer`, `sla deze track op`,
  `bewaar dit nummer`, `add this song to my favorites`, `like this track`,
  `save this song`, `add the current track to liked songs`
- `output_devices_info`: `Welke speakers zijn er?`, `Welke output devices
  zijn beschikbaar?`, `Waar kan ik muziek afspelen?`, `which speakers are
  available?`, `what output devices do I have?`
- `current_output_info`: `Waarop wordt nu muziek gespeeld?`, `Op welke
  speaker speelt dit?`, `Waar speelt de muziek nu?`, `where is music playing
  now?`, `which speaker is active?`
- `personalized_mood_playback`: `Ik voel me moe en geprikkeld, zet wat rustige
  muziek op die ik fijn vind`, `Doe iets ontspannends, ik ben overprikkeld`,
  `Zet iets op waar ik rustig van word`, `Ik wil even kalme muziek zonder
  vocals`, `I am tired and overstimulated, play relaxing music I will enjoy`,
  `play something calming that I usually like`, `put on something low energy`
- `change_music_context`: `Ik wil wat anders horen`, `Doe maar iets anders`,
  `Zet iets anders op`, `Verras me met iets heel anders`, `Ik ben dit zat,
  draai wat anders`, `I want to hear something else`, `play something
  different`, `put on something else`, `surprise me with something completely
  different`
- `personal_music_profile_analysis`: `Omschrijf eens waar ik zoal naar
  luisterde de afgelopen maand`, `Wat zegt mijn muziek van de laatste twee
  weken over mijn stemming?`, `Welke genres luister ik de laatste tijd veel?`,
  `Maak een profiel van mijn muzieksmaak dit jaar`, `describe what I have been
  listening to over the last month`, `what does my music from the last two
  weeks say about my mood?`, `which genres have I been listening to lately?`
- `personal_music_recommendations`: `Geef me muziek aanbevelingen op basis van
  mijn luisterprofiel`, `Wat zou ik nu leuk vinden om te luisteren?`, `Raad me
  iets nieuws aan dat past bij mijn smaak`, `Welke artiesten of albums moet ik
  eens proberen?`, `Geef me vijf nummers die passen bij wat ik de laatste tijd
  luister`, `recommend music based on my listening profile`, `what should I
  listen to now?`, `recommend something new that fits my taste`, `which artists
  or albums should I try?`
- `dj_announcement_request`: `Geef me een leuke aankondiging voor het volgende
  nummer`, `Kondig het volgende nummer alvast aan`, `Doe een radio intro voor
  wat er nu speelt`, `Zeg iets leuks over dit nummer`, `give me a fun
  announcement for the next song`, `do a radio-style intro for what is playing
  now`, `say something fun about this track`
- `track_context_info`: `Vertel iets over dit nummer`, `Wanneer kwam dit uit?`,
  `Waar komt deze artiest vandaan?`, `Welke samples hoor ik?`, `Heeft deze
  artiest binnenkort concerten in Nederland?`, `Waarom koos je dit nummer?`,
  `Wat is de connectie met het vorige nummer?`, `tell me about this song`,
  `what year was this released?`, `where is this artist from?`, `what samples
  are used?`, `does this artist have concerts in the Netherlands?`, `why did
  you choose this track?`
- `technical_track_analysis`: `Geef een technische track analyse van dit
  nummer`, `Analyseer deze track`, `Wat is de bpm en opbouw van deze track?`,
  `Welke instrumenten hoor je hierin?`, `Hoe zit intro, couplet, refrein en
  breakdown in elkaar?`, `Give me a technical analysis of this song`, `What is
  the BPM, key and structure of this track?`, `Why does this track work so
  well?`

The app does not hardcode these intent families or validate spoken text
client-side. It records/uploads voice audio and lets Home Assistant handle STT,
Assist correction, current playback lookup, direct playback controls, Spotify
credentials, output-device lookup, current-speaker lookup, favorite-track
mutations, personalized mood playback, DJ announcement generation, and DJ
response generation.

For `personal_music_profile_analysis`, Home Assistant should summarize the
user's listening profile over the requested or inferred period without changing
playback. It should use DJ Memory, recent tracks, likes/skips where available,
timestamps, mood values, playlist choices, and current playback context to
describe recurring genres, artists, energy, moods, listening situations, and
notable taste shifts. If no period is given, default to a recent window such as
the last 30 days and say so. If memory is too sparse for the requested period,
return an honest DJ response instead of inventing history.

For `personal_music_recommendations`, Home Assistant should recommend concrete
tracks, albums, artists, or playlists from DJ Memory plus Spotify recently
played/top data where available. It should explain why recommendations fit the
user's known taste, mood, energy, and recent listening. This intent is
informational by default: do not change playback unless the user explicitly asks
to play, queue, save, or create something from the recommendations.

For `track_context_info`, Home Assistant should enrich the current playback
context with album art, title, artist, release year, genre, DJ commentary,
artist origin, trivia, samples, related artists, upcoming Netherlands concerts,
festival appearances, new releases, why the track was chosen, relation to the
previous track, BPM/energy transition, and shared producer or label connections
when those details are available.

For `technical_track_analysis`, Home Assistant should explain instrumentation,
arrangement, rhythm/groove, BPM/key/sections when measured or sourced,
harmony/chords when known, sound design, production techniques, mix/mastering
impressions, and why the composition works. This is an informational/read-only
intent for iOS, macOS, watchOS, Raspberry Pi, and Windows Ask DJ clients: never
start, pause, skip, queue, save, like, transfer output, or otherwise mutate
playback from this intent. ESP32 remains outside the Ask DJ chat/history UI.

The response may include `analysis` metadata with `mode`, `confidence`,
`measured`, `inferred`, `limitations`, and `sources`, plus optional compact
`items[]` such as `kind: "technical_metric"` for BPM/key or `kind:
"arrangement"` for structure notes. Clearly separate measured/provider-backed
facts from inferred musical commentary. Unless the backend adds a real
audio-analysis pipeline or uses a trusted source, it must avoid claiming exact
BPM/key, timestamps, stem separation, exact chord transcription, or definitive
instrument lists.

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

Rules:

- Do not connect directly to Home Assistant Assist WebSocket from the app for
  DJConnect PTT unless the backend contract is explicitly changed.
- Do not call OpenAI or Spotify directly from the app for DJConnect commands.
- Do not log temporary `audio_url` tokens.
- If returned audio cannot be played, show text-only response.

## App Settings

The ESP has device settings such as screen brightness, LED and speaker cue
volume. The iOS/macOS/watchOS app should not copy those settings blindly.

Suggested app-owned settings:

- HA URL selection;
- pairing reset;
- language;
- theme;
- voice/PTT enabled;
- local response audio enabled;
- diagnostics export;
- log level.

If app settings should be mirrored into HA entities, post them in status under
clear app-specific keys. Avoid reusing ESP-only settings like
`screen_brightness` unless the app truly implements equivalent behavior.

## Public Releases And What's New

Release tags in the private app repo should publish unsigned macOS and iOS
diagnostic builds to `pcvantol/djconnect-app-releases` through GitHub Actions.
The workflow requires private repo secrets named `PUBLIC_RELEASES_TOKEN` with
write access to that public releases repo and `WEBSITE_RELEASE_NOTES_TOKEN`
with write access to `pcvantol/djconnect-website`.
After publishing, the workflow keeps the newest platform-specific public iOS
release and the newest platform-specific public macOS release, then removes
older public app releases/tags for those platform namespaces.
The workflow runs Swift tests before it publishes either unsigned artifacts or
static What's New files. If that job fails, the source GitHub release can exist
while `djconnect.dev/release-notes/.../vX.Y.Z.json` and the public
`ios/vX.Y.Z` / `macos/vX.Y.Z` releases are still missing.

The Apple apps persist the last seen app version locally. When a newer app
version starts, they fetch platform-specific static release notes from
`djconnect.dev` using the current app language first: iOS reads
`/release-notes/ios/{en|nl}/vX.Y.Z.json`, macOS reads
`/release-notes/macos/{en|nl}/vX.Y.Z.json`. The legacy
`/release-notes/{ios|macos}/vX.Y.Z.json` path and GitHub release metadata
remain fallbacks. The release body is shown once in a native
`Wat is er nieuw` / `What's New` sheet. This request sends no DJConnect token,
Home Assistant URL, Spotify token, diagnostics, or user data.

## Local Client API Postman Collection

The legacy Apple app-hosted `/api/device/*` Postman collection is retained only
as historical reference for older 3.1 clients and must not be used as the 3.2
iOS/macOS contract. Current Apple clients call Home Assistant
`/api/djconnect/*` endpoints directly.

## UI Parity Goals

Functional parity with the ESP device should include:

- pairing/setup state;
- Home Assistant connection state;
- playback now-playing view;
- play/pause, previous-track, next-track;
- volume 0-60;
- shuffle toggle;
- repeat triple state: `off`, `track`, `context`;
- output selector;
- queue view;
- playlists/liked proxy start;
- DJ/voice response view with PTT WAV upload;
- backend unavailable and version mismatch states.
- About screen with a full-width DJConnect app banner, version, identity,
  pairing state, and client API URL details.

iOS/macOS-specific UX may add:

- menu bar control on macOS;
- lock screen/live activity on iOS if appropriate;
- media key integration, if it maps cleanly to DJConnect commands;
- widgets/shortcuts later.

## Security And Privacy

Never log:

- DJConnect bearer token;
- Home Assistant tokens;
- Spotify refresh token;
- OAuth client secret;
- WiFi password;
- temporary TTS/audio URLs.

Diagnostics must redact:

- `Authorization`;
- `device_token` and DJConnect bearer tokens;
- any `token`;
- `audio_url` query strings;
- private HA URLs if the user chooses anonymized export.

## New Repo Suggested Shape

Suggested top-level structure:

```text
DJConnectApple/
  Package.swift or DJConnectApple.xcodeproj
  Sources/
    DJConnectCore/
      DJConnectClient.swift
      DJConnectModels.swift
      DJConnectPairing.swift
      DJConnectKeychain.swift  # token-store abstraction; legacy filename
      DJConnectVoice.swift
    DJConnectIOS/
    DJConnectMac/
  Tests/
    DJConnectCoreTests/
  README.md
  PRIVACY.md
```

Core module responsibilities:

- build authenticated requests;
- serialize status/command/voice payloads;
- parse playback responses;
- classify errors: backend unavailable, auth stale, version mismatch, not
  configured, network;
- store and clear bearer token via an app-storage abstraction.

Do not put SwiftUI view logic into the HTTP client.

## iOS UI Test Fixture

`DJConnectIOSUITests` launches the iOS app with `--uitesting`. In that mode the
app uses isolated `UserDefaults`, an in-memory token store, and
`DJCONNECT_UITEST_HA_URL` for deterministic Home Assistant URL seeding. The
current UI tests cover primary navigation, Settings URL wiring, and the local
Games menu choices. Full pairing, output, queue, playlist, liked proxy,
stale-auth, backend-unavailable, and voice/PTT UI tests should build on this
target with a real or recorded mock Home Assistant server.

## Acceptance Criteria

- App pairs with the existing `djconnect` HA integration.
- App status posts include `client_type` as `ios` or `macos`.
- App command posts include `client_type` as `ios` or `macos`.
- HA backend playback commands work without any Spotify credentials in the app.
- Playback-changing commands trigger an immediate rich Now Playing refresh.
- Successful local pairing stores `ha_local_url` and optional `ha_remote_url`.
- Backend unavailable does not reset pairing.
- HTTP 426 version mismatch shows update-required UI and keeps pairing.
- Authenticated 401/403/404 show stale pairing/setup recovery and keep token
  until user reset.
- 401/403 during unauthenticated pairing polling stops the wait loop and asks
  the user to re-enter the visible app code in Home Assistant.
- Voice/PTT uploads raw WAV to `/api/djconnect/voice`.
- Local Games show Paddle Rally, Meteor Run, Sky Dash, and Maze Chase without
  HA/backend traffic, render the Maze Chase player mouth and ghost eyes, and
  reset to tap-to-play when leaving the screen.
- Bonjour/mDNS advertises only while the app is unpaired/pairable; pairing
  keeps the HTTP API alive but stops unnecessary Bonjour publication.
- Wakeword listening and local progress timers stop when the app leaves the
  foreground and resume only when the app becomes active again.
- Automatic resume/startup refreshes and backend collection refreshes are
  throttled; explicit user refreshes remain immediate.
- Artwork loading reuses the shared 24-hour app cache for Now Playing, queue,
  playlists, and dominant-color sampling.
- Monkey Test Mode can navigate the UI without destructive backend, pairing, or
  token side effects.
- No secrets appear in logs or diagnostics.
- iOS and macOS clients can coexist with ESP32 clients in the same HA backend.
