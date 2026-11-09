# DJConnect App Privacy Notes

The Apple apps use a DJConnect device credential issued during pairing to
connect to the user's Home Assistant integration. They keep that credential in
app-private storage and clear it when pairing is reset. Credentials for music,
playback, voice and AI providers are managed by Home Assistant. Apple clients
must never ask users for provider secrets, Home Assistant long-lived access
tokens or Wi-Fi passwords. Keep those values out of storage, exports and logs.
Temporary response audio URLs are used for playback and must stay out of
persistent storage and logs.

Home Assistant manages the DJConnect Profile, music connections and Ask DJ
history. Depending on the user's configuration, their chosen voice and AI
providers may process requests or audio. Music DNA is optional. Music DNA and
Ask DJ history can be cleared separately in Home Assistant.

## Optional Apple notifications

When enabled, the DJConnect notification service processes registration data
and the Apple push token. Apple delivers notifications to the device. The
service uses technical delivery diagnostics to monitor reliability. Users can
turn notifications off in Settings.

## App diagnostics

Users choose whether to share app diagnostics with support or in a GitHub
issue. This is separate from the notification service's delivery diagnostics.

App diagnostic exports redact Authorization headers, device credentials,
pairing codes, tokens, temporary audio URL query strings and raw request bodies.
Anonymized exports also redact private Home Assistant addresses. Exports may
include readiness metadata such as the app version, locale, connection mode,
backend availability and permission status.

[Full privacy statement](https://djconnect.dev/en/privacy) ·
[Nederlandse privacyverklaring](https://djconnect.dev/privacy)
