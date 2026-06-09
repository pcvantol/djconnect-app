# Home Assistant API Contract

This document captures the app-to-Home Assistant DJConnect contract used by
`DJConnectCore`.

## Identity

Every app installation needs a stable `device_id`.

```json
{
  "device_id": "djconnect-ios-8F3A2C91B45D",
  "device_name": "DJConnect iPhone",
  "client_type": "ios",
  "firmware": "3.0.0",
  "app_version": "3.0.0",
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
Authorization: Bearer <device_token>
X-DJConnect-Device-ID: <device_id>
Content-Type: application/json
```

Voice upload:

```http
Authorization: Bearer <device_token>
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
  "firmware": "3.0.0",
  "app_version": "3.0.0",
  "platform": "macos",
  "pair_code": "123456",
  "pairing_token": "123456"
}
```

The app-generated code is sent as both `pair_code` and `pairing_token` for
compatibility with current Home Assistant integration builds. The user confirms
or enters the same value in the Home Assistant DJConnect setup flow. The app
keeps polling this endpoint with the generated code until Home Assistant returns
a device token.

Expected response:

```json
{
  "success": true,
  "device_token": "<device bearer token>",
  "device_id": "djconnect-macos-8F3A2C91B45D",
  "client_type": "macos"
}
```

The app also accepts `bearer_token` or `token` for compatibility, but
`device_token` is preferred. After successful pairing, the app stores only the
returned DJConnect device bearer token in Keychain and posts status.

## Local Device API

The Apple app exposes a local HTTP API for Home Assistant repair/config flows.
Home Assistant may discover it through Bonjour `_djconnect._tcp` or use the
`local_url` sent by the app during pairing.

```http
GET /api/device/pairing-info
GET /api/device/info
GET /api/device/status
POST /api/device/pair
```

The app also accepts underscore and `/api/djconnect/device/...` aliases for
compatibility with integration builds.

Pairing-info response includes the app-generated code under all supported code
field names:

```json
{
  "success": true,
  "device_id": "djconnect-macos-8F3A2C91B45D",
  "device_name": "DJConnect Mac",
  "client_type": "macos",
  "firmware": "3.0.0",
  "app_version": "3.0.0",
  "platform": "macos",
  "state": "online",
  "status": "online",
  "ha_pairing_status": "pairing",
  "pair_code": "123456",
  "pairing_token": "123456",
  "pairing_code": "123456",
  "code": "123456",
  "local_url": "http://192.168.1.104:64641"
}
```

For `POST /api/device/pair`, the app accepts the code as `pair_code`,
`pairing_token`, `pairing_code`, `code`, or `pin`. The Home Assistant-issued
device token may be sent as `device_token`, `bearer_token`, `token`, or
`access_token`.

If Home Assistant uses the local `POST /api/device/pair` call only to verify the
code and does not include a device token yet, the app returns `success: true`
with `ha_pairing_status: "pairing"` and keeps waiting for the token through the
normal app-to-Home Assistant pairing endpoint or a later local pair call.

## Status

```http
POST /api/djconnect/status
```

Minimum payload:

```json
{
  "device_id": "djconnect-ios-8F3A2C91B45D",
  "client_type": "ios",
  "ha_pairing_status": "paired",
  "firmware": "3.0.0",
  "app_version": "3.0.0",
  "state": "online",
  "status": "online",
  "battery_percent": 85,
  "language": "nl",
  "theme": "dark",
  "log_level": "info"
}
```

## Commands

```http
POST /api/djconnect/command
```

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
{"device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_output","value":"iPhone","play":true}
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

HTTP `404`

Integration route is missing or setup is stale. Keep token until explicit user
reset and show setup recovery.
