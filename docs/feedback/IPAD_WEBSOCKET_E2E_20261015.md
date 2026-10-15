# Physical iPad WebSocket E2E — preflight and outstanding flows

Owner requested actual end-to-end testing of the WebSocket route across every
screen/flow. This document does not substitute source or fixture PASS for physical
acceptance. No transport settings, TLS trust, pairing or server state were changed.

## Fresh physical readback

- Ordinary physical Peter-iPadPro, UDID00008027-000211140231002E.
- Existing device log confirms build40068. Screenshot shows the real current
  Session, current album and published DJ contributions behind a crash prompt.
- Sanitized route readback: HomeAssistantURL, HALocalURL and HARemoteURL all point
  to https://victory-curvy-refold.ngrok-free.dev. The old persisted connection-mode
  label says local; the current toolbar globe is consistent with Hybrid remote.
- The coordinator requires qualified local HTTPS for paired action WSS. Its
  local-host predicate rejects the ngrok hostname. Therefore actions on this
  configuration use external HTTPS, not the local action WSS route. A local and
  remote settings slot containing the same public origin does not prove LAN WSS.
- Broadcast WSS is a separate contract and may operate externally. Visible fresh
  content alone does not distinguish Broadcast WSS from HTTP snapshot recovery.
  No actual Broadcast-WSS PASS is claimed from that screenshot.

Raw preferences were copied only for route extraction, then the temporary plist
was deleted. No credentials or pairing codes were emitted. Sanitized evidence:
/private/tmp/djc-ipad-wss-route-readback.json. Existing log:
/private/tmp/djc-ipad-wss-current.log. Screenshot:
/private/tmp/djc-ipad-wss-current.png.

## Physical UI-control limitation

CUA initialization fails because a configured writable root contains a symlink;
no Codex security setting was changed to bypass that validation. One fresh run
of the existing PhysicalProbe XCTest against the ordinary app failed after60s:
Timed out while enabling automation mode. Evidence:
/private/tmp/djc-ipad-wss-ui-read.log and .xcresult. No fixture app or synthetic
pairing was used. The ordinary DJConnect app was brought back to the foreground.
Screenshots and device-log copying work; physical tapping/typing does not.

The owner was asked for an existing trusted local HTTPS HA-dev address. That
answer is pending. A certificate bypass, hostname substitution, private-key
installation or forcing the external origin into local mode is not a test fix.

## Flow matrix — execution not yet qualified

| Screen / flow | Intended transport / acceptance | Current physical result |
| --- | --- | --- |
| DJ-session discovery / start / end / successor | Active read via action WSS; lifecycle via HTTP operation journal; same Profile/session; no duplicate start | NOT RUN on local WSS |
| DJMoments / Broadcast / cursors | Separate paired Broadcast WSS; events, expiry, reconnect, cursor recovery and honest gaps | Current content visible; WSS route unproven |
| Mood / DJ Presence | WSS action, revision/CAS, confirmation and propagation to iPad/Pi | NOT RUN |
| Now Playing play/pause/skip/seek | WSS action, original operation ID, current track guard and confirmed position | NOT RUN |
| Output / volume / shuffle / repeat / favourite | Supported WSS command; confirmation; restore prior test settings | NOT RUN |
| Track Insight automatic / manual / Moment detail | WSS analysis action; detail/source read retains its HTTP contract | NOT RUN |
| Ask DJ text / context / follow-up | WSS action and confirmed reply; no duplicate send after uncertainty | NOT RUN |
| Ask DJ voice / history / search / export / clear | HTTP-only contract; UI should continue working alongside WSS | NOT RUN |
| Discover feed / selections | Existing HTTP contracts; supported playback intents can use WSS | NOT RUN |
| Music DNA / opt-in / import / export | Existing HTTP contracts, no invented WSS result | NOT RUN |
| Queue / playlists / playback | Reads and unsupported playlist commands remain HTTP; supported playback intents WSS | NOT RUN |
| Earlier Sessions / archive / search | HTTP-only, no playback/session mutation from archive navigation | NOT RUN |
| VibeCast handoff / Pi display | HTTP handoff plus separate Broadcast; same Mood/Presence and exact Session | NOT RUN in this attempt |
| Settings / About / connection details / popovers | Route/status truth, automatic mode, no old toggle | Source checked; UI interaction blocked |
| Games / legal / privacy / logs / feedback / More | Screen/sheet presentation; no new WSS operation expected | NOT RUN |
| Quiet connection / lease renewal / concurrent replies | One action reader; heartbeat, bounded requests and lease replacement | NOT RUN physically |
| Foreground/background / offline / LAN-external-LAN | No replay, preserve drafts/selection/scroll, reconnect and re-discover same Session | NOT RUN physically |
| Push receive / tap / bootstrap | APNs plus HTTP registration, separate from WSS; retain pairing during reload | Prior Apple regression fix; real delivery OPEN |

Completion requires both a qualified local HTTPS route and functioning physical
UI control (or a human driving the real UI while evidence is collected). None of
the NOT RUN rows is reported as PASS, and no unit suite was rerun as a substitute.
