# Home Assistant API Contract

This document captures the app-to-Home Assistant DJConnect contract used by
`DJConnectCore`.

## Identity

Every app installation needs a stable `client_id`. During transitional Home
Assistant route compatibility the app also sends the same value as `device_id`,
but app clients should be stored and reasoned about as clients, not ESP
devices.

The app must keep `client_id` stable across pairing reset/retry flows. Resetting
pairing clears only the bearer token and generates a new app code; it must not
change the app client identity.

```json
{
  "client_id": "djconnect-ios-8F3A2C91B45D",
  "client_name": "DJConnect iPhone",
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
X-DJConnect-Client-ID: <client_id>
X-DJConnect-Device-ID: <device_id>
Content-Type: application/json
```

Voice upload:

```http
Authorization: Bearer <device_token>
X-DJConnect-Client-ID: <client_id>
X-DJConnect-Device-ID: <device_id>
Content-Type: audio/wav
```

## Pairing

```http
POST /api/djconnect/pair
Content-Type: application/json
X-DJConnect-Client-ID: <client_id>
X-DJConnect-Device-ID: <device_id>
```

Payload:

```json
{
  "client_id": "djconnect-macos-8F3A2C91B45D",
  "client_name": "DJConnect Mac",
  "device_id": "djconnect-macos-8F3A2C91B45D",
  "device_name": "DJConnect Mac",
  "client_type": "macos",
  "firmware": "3.0.0",
  "app_version": "3.0.0",
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
code until Home Assistant returns a device token.

Expected response:

```json
{
  "success": true,
  "device_token": "<device bearer token>",
  "client_id": "djconnect-macos-8F3A2C91B45D",
  "device_id": "djconnect-macos-8F3A2C91B45D",
  "client_type": "macos"
}
```

The app also accepts `bearer_token` or `token` for compatibility, but
`device_token` is preferred. After successful pairing, the app stores only the
returned DJConnect device bearer token in Keychain and posts status.

The iOS/macOS app does not expose or consume ESP local `/api/device/*` routes.
Those routes are reserved for local ESP hardware.

## Status

```http
POST /api/djconnect/status
```

Minimum payload:

```json
{
  "client_id": "djconnect-ios-8F3A2C91B45D",
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
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"status"}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"devices"}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"queue"}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"playlists"}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"pause"}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"play"}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"next"}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"previous"}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_volume","value":35}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_shuffle","value":true}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_repeat","value":"context"}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"start_liked_proxy","play":true}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"start_playlist","value":"spotify:playlist:...","play":true}
{"client_id":"djconnect-ios-8F3A2C91B45D","device_id":"djconnect-ios-8F3A2C91B45D","client_type":"ios","command":"set_output","value":"iPhone","play":true}
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
