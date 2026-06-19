# DJConnect App Privacy Notes

DJConnect Apple clients use Home Assistant as the trusted backend for pairing,
Spotify OAuth, playback credentials, Assist/STT/TTS, and DJ response generation.
AI and Assist answers can be incorrect and depend on the user's own Home
Assistant and Assist configuration.

The app must not request, store, export, or log:

- Spotify OAuth client secrets, refresh tokens, or access tokens;
- Home Assistant long-lived access tokens;
- Sonos or playback backend credentials;
- OpenAI or other AI provider credentials;
- WiFi passwords;
- DJConnect bearer tokens;
- temporary TTS or response audio URLs.

The only credential the app may store is its DJConnect device bearer token,
issued by the Home Assistant integration during pairing. iOS, macOS, and
watchOS store that token in app-private storage instead of Keychain so the app
does not trigger platform Keychain access prompts. Resetting pairing clears the
stored token and returns the app to the pairing sheet.

## Diagnostics

Diagnostics exports must redact:

- `Authorization` headers;
- `device_token`;
- fields named `token` or ending in `_token`;
- temporary `audio_url` query strings;
- private Home Assistant URLs when the user chooses anonymized export.

Backend unavailable, stale auth, missing integration routes, and version
mismatch states must not automatically erase the stored token. The user must
explicitly reset pairing before the app clears token state.
