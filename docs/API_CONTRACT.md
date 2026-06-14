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
  "firmware": "3.1.22",
  "app_version": "3.1.22",
  "platform": "ios"
}
```

Use `client_type` for DJConnect client identity:

- `ios`
- `macos`
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
  "firmware": "3.1.22",
  "app_version": "3.1.22",
  "platform": "macos",
  "pair_code": "123456",
  "pairing_code": "123456",
  "pairing_token": "123456"
}
```

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
bearer token in Keychain and persists `ha_local_url`, `device_id`, and
`client_type`. App-to-HA runtime traffic must always use `ha_local_url`;
cloud/remote URLs are reserved for Home Assistant-owned Spotify OAuth config
flows and are not used for status, command, or voice requests. Do not use legacy
`ha_url`.

## Local App Web API

The iOS/macOS app hosts a small local Web API for Home Assistant -> app
traffic while the app is active/reachable. While the app is pairable, it
advertises Bonjour/mDNS service `_djconnect._tcp` with TXT fields including
`name`, `device_id`, `version`, `paired`, `api`, `model`, and `client_type`.
Once pairing is complete, the app keeps the local HTTP API available while it
is running, but disables Bonjour advertising to reduce network and battery
impact. Explicit pairing reset enables Bonjour advertising again.

User-facing app text calls this endpoint the `Client API url`. The URL shown
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
  "firmware": "3.1.22",
  "app_version": "3.1.22",
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
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"playlists"}
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

## Client API URL Stability

The app must keep the local Client API url stable across successful pairing.
Home Assistant pairs by calling the URL shown by the app, then continues to use
that same endpoint for app callbacks and status/control flows. The app may
restart the local listener when pairing is reset or the install identity changes,
but not as a side effect of accepting `/api/device/pair`.

Fresh installs should present `http://homeassistant.local:8123` as the default
Home Assistant URL. This is only a UI default; runtime app-to-HA requests must
still use the paired `ha_local_url` returned by Home Assistant after pairing.

## Voice

```http
POST /api/djconnect/voice
Content-Type: audio/wav
```

The app uploads raw mono PCM WAV. Home Assistant owns STT, Assist, playback
action, and TTS.

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
