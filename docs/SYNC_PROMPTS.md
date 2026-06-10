# Sync Prompts

Use these prompts when handing work between the Home Assistant integration repo
and this Apple app repo.

## Home Assistant Integration

```text
Sync the DJConnect Home Assistant integration with the Apple app client
contract.

Requirements:
- Treat iOS/macOS as app clients, not ESP hardware devices.
- Pair app clients through POST /api/djconnect/pair.
- Accept stable client_id, client_name, client_type, firmware, app_version,
  platform, and temporary device_id/device_name compatibility fields.
- Accept the app-generated code as pair_code, pairing_code, or pairing_token.
- Return a DJConnect bearer token on success. The current compatible field is
  device_token; bearer_token and token may also be returned.
- Keep /api/device/* reserved for ESP/local hardware clients.
- Persist client_type as ios, macos, or esp32. Do not reintroduce device_type.
- Authenticated status/command/voice routes must accept Authorization: Bearer
  plus X-DJConnect-Client-ID and temporary X-DJConnect-Device-ID.
- During app pairing, temporary 401 responses should not require the app to
  regenerate its client_id.
- Create native HA entities for paired app clients when status is received.
```

## Apple App

```text
Sync the DJConnect Apple app with the Home Assistant integration contract.

Requirements:
- Keep one stable client_id per app installation across reset/retry flows.
- Reset Pairing clears only the DJConnect bearer token and app pairing code; it
  must not rotate client_id.
- Pair by polling POST /api/djconnect/pair with pair_code, pairing_code, and
  pairing_token set to the same app-generated code.
- Store only the returned DJConnect bearer token in Keychain.
- Do not expose or call ESP-local /api/device/* routes.
- Send client_id, client_type, firmware, app_version, and temporary device_id on
  status/command payloads.
- Treat backend_unavailable and version_mismatch as recoverable without
  clearing pairing.
- Treat authenticated 401/403/404 as stale/setup recovery while keeping the
  token until explicit user reset.
- Treat temporary 401 during unauthenticated pairing polling as pending setup
  and keep polling.
- Do not log bearer tokens, HA tokens, Spotify secrets, or audio URLs.
```
