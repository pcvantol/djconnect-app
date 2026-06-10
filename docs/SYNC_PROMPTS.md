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
- Accept stable device_id, device_name, client_type, firmware, app_version,
  platform.
- Accept the app-generated code as pair_code, pairing_code, or pairing_token.
- Return a DJConnect bearer token on success. The current compatible field is
  device_token; bearer_token and token may also be returned.
- Return ha_local_url, optional ha_remote_url, and language metadata during
  successful app pairing.
- Apple clients host local /api/device/* app endpoints for HA -> app traffic,
  but must not implement ESP-only reboot or OTA routes.
- Persist client_type as ios, macos, or esp32. Do not reintroduce device_type.
- Authenticated status/command/voice routes must accept Authorization: Bearer
  plus X-DJConnect-Device-ID.
- During app pairing, 401/403 code mismatch responses stop polling, keep the
  visible app code, and do not rotate device_id automatically.
- Create native HA entities for paired app clients when status is received.
```

## Apple App

```text
Sync the DJConnect Apple app with the Home Assistant integration contract.

Requirements:
- Keep one stable device_id per app installation across normal launches.
- Reset Pairing clears the DJConnect bearer token, rotates the app pairing
  code, and creates a fresh device_id for a new setup.
- Pair by polling POST /api/djconnect/pair with pair_code, pairing_code, and
  pairing_token set to the same app-generated code.
- Store only the returned DJConnect bearer token in Keychain and persist
  ha_local_url, optional ha_remote_url, device_id, and client_type.
- Expose local /api/device/info, pairing-info, pair, command, dj_response, and
  forget routes for HA -> app traffic; do not expose ESP-only reboot/OTA.
- Send device_id, client_type, firmware, app_version, device_name, and HA URL
  metadata on status payloads. Send device_id and client_type on command
  payloads.
- Treat backend_unavailable and version_mismatch as recoverable without
  clearing pairing.
- Treat authenticated 401/403/404 as stale/setup recovery while keeping the
  token until explicit user reset.
- Treat 401/403 during unauthenticated pairing polling as code/setup mismatch:
  stop polling, keep the visible app code, and ask the user to re-enter it.
- Do not log bearer tokens, HA tokens, Spotify secrets, or audio URLs.
```
