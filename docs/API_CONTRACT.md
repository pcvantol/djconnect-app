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
  "firmware": "3.1.2",
  "app_version": "3.1.2",
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
  "firmware": "3.1.2",
  "app_version": "3.1.2",
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
traffic while the app is active/reachable. It advertises Bonjour/mDNS service
`_djconnect._tcp` with TXT fields including `name`, `device_id`, `version`,
`paired`, `api`, `model`, and `client_type`.

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
  "firmware": "3.1.2",
  "app_version": "3.1.2",
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
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"queue"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"playlists"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"pause"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"play"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"next"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"previous"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_volume","value":35}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_shuffle","value":true}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_repeat","value":"context"}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"start_liked_proxy","play":true}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"start_playlist","value":"spotify:playlist:...","play":true}
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_output","value":"Living Room","play":true}
```

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
protocol version. Keep token and pairing state. Show update required.

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
