# Actual Apple ActivityKit codec — unadmitted profile input

The real current Attributes is `DJConnectSessionLiveActivityAttributes`, with only random local `presentationID`; ContentState is `DJConnectSessionSurfaceSnapshot`. This handoff does not select a profile, grant export rights, enroll an operator or activate a provider.

An offline arm64 iOS simulator executable imported the actual ActivityKit and compiled DJConnectCore framework and encoded/decoded the real types. No Activity.request, token observation, HTTP, APNs or device operation was performed. `Tools/qualification/surface-push/ActivityStateWireProbe.swift` is the replayable probe. Original executable, native output and source-binding receipt are retained under `/private/tmp/apple-activity-codec-20261023/`.

The framework's relevant source is byte-identical to protected Apple027354f31e1a3e46f726e2bd65ba1099947c9767 and this candidate:

- DJConnectLiveActivities.swift SHA256 ffd7beb500e375df10883f5efa1bafc6ce6c7c217dd8a9d722a416c5237f9a29.
- DJConnectPassiveSession.swift SHA256 1c771bf3970547b0b9baccf4e3e1681f0fb2a30f48dacb26777b3921ba5092bb.
- Native vector SHA256 0f4fba145dbf8b040c83d33665c4a4937b8b4ad46f9582ec631c6577684aa7d7, imported unchanged as `Tests/Fixtures/activity-surface-default-ios-20261023.json`.

## Actual default wire

The default JSONEncoder strategies are used, without a custom date encoder. `observedAt` and `expiresAt` are finite Foundation Date numbers in seconds since2001-01-01. They are NOT ISO strings or Unix seconds. Fractional dates are emitted, including ordinary binary floating-point representation. `theme` is optional and limited to brand/chill/groove/energy/party. The minimal probe emits only observedAt/expiresAt; nil theme and rich are omitted. Explicit null for those optionals also decodes, which does not require an admitted sender profile to allow null. A closed compiled profile must reject unknown fields regardless of the general Swift decoder's permissiveness.

The vectors include minimal, theme update and end-final-state. All retain the same original observation/expiry; an end label in this test does not send an APS end event or renew a lease. API's separate observed_at_ms/expires_at_ms envelope values are safe Unix milliseconds; APS timestamp/stale-date/dismissal-date use Unix seconds. That outer envelope remains distinct from the default-coded nested ContentState. No vector has external_content_admitted=true.

## Rich content is not an admitted server schema

Current optional rich is a locally formed `DJConnectPassiveActivityContent`: bindingID, generation, sequence, receivedAt, **receivedUptime**, expiresAt, optional contribution, optional nowPlaying and optional playbackState. receivedUptime is the receiving Apple process/device's original uptime anchor. HA's uptime, a read timestamp or a new render cannot replace it. Its construction requires an original foreground passive live_activity cache with locked display and local snapshot rights. Current passive contribution/artwork rights expressly deny external_relay. A default-Codable payload with a rich field is therefore not itself a server/content export authorization.

The next true remote profile must be jointly specified by Core/API/Apple, with explicit external-content/locked-display rights, an original Session/target/grant, safe per-field expiry and an original remote-content clock model. Do not inject HA uptime, borrow the foreground DTO or use widget rights. API currently admits no actual compiled profile and denies remote start. Minimal neutral codec interoperability alone does not finish the requested playback-rich Live Activity push.
