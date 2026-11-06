# Apple/Core integration closeout — 6 November 2026

This is source and validation status, not an installation or physical acceptance
receipt. The installed Apple release remains 4.0.0 (40493), main502a9255.

## Qualified Core basis

Core main `dacf9cd01a8fbc17827438f228d95657fe62de93` and HA-dev composite
`1e990d979d55b5e54f58f3e90f9a65ec03c92516` preserve the separate #1439 patch.
The Core owner reports 308 product hashes, config check, runtime/capability
readback and unchanged Profile defaults. Foreground passive projection3 and
own `paired_watch_widget_v1` projection1 are available. Background delivery is
false; source/snapshot/grant deadlines still apply.

## Apple source integration

- Explicit v3 negotiation preserves the default v1 request bytes. Original
  progress samples do not renew on reads, mood changes or rendering.
- Track Live Activities omit unrendered DJ prose and keep their own original
  lease when shorter contribution prominence expires. Artwork still joins the
  exact own Activity cache. Research prose requires full source/license credit
  or is omitted when it does not fit.
- Own Watch widget1 travels through the existing closed companion broker with
  the Watch bearer/identity. Profile, Session, pairing and asynchronous image
  results are fenced. A learned denial clears local pixels. Smart Stack shows
  title and whole rounded glass cover, with the confirmed Session palette.
- Watch Settings explicitly selects title/cover display including the locked
  screen. The local choice is scoped to own Watch/pairing/Profile/purpose,
  defaults off and cannot come from legacy placement or phone settings.
- Watch pairing preserves the original receiver correlation separately from
  the HA QR code; stale completions cannot replace credentials.
- Artist Discover playback stays one non-replayed Core item/section request.
  Its queue refresh waits out older reads. The client never reconstructs an
  artist playlist URI or substitutes another playback command.
- Floating Ask DJ and Session composers preserve a full scrolling viewport;
  the last bubble remains reachable above the bar.

## Validation and limits

Local receipts are retained under
`/Volumes/Shared Data/tmp/pcvantol/apple-client-golden-20261106/`.

- `core-close-full-swift-3.log`: 1726 tests / 60 suites passed, 165.670 seconds,
  explicitly nonparallel and without a simultaneous build.
- `core-close-checks/logs-checks/results.json`: all nine contract, translation,
  security, installation and orchestration checks passed.
- `core-close-ios-watch-build-4.log`: joint unsigned iOS/Watch/widget build passed.
- `core-close-final-focused.log`: 16 focused tests passed after the final broker
  pairing/denial fences. The subsequent explicit Watch UI choice has separate
  `watch-consent-final-tests.log` (14 tests passed) and
  `watch-consent-final-build.log` (joint unsigned build passed) receipts.
  `watch-consent-localizations.log` validates all five languages / 1548 keys.
- Original failures remain in `core-close-full-swift.log` (new test identity
  prefix corrected) and `core-close-full-swift-2.log` (existing 0.4-second Moment
  detail test under simultaneous compilation). Its isolated two cases passed;
  neither product leases nor assertions were weakened.

Earlier native Help component coverage includes 56 iPhone NL/EN selections.
iPad catalogue scrolling and Mac harness completion are not qualified. Component
screenshots do not qualify shipping entry/focus, actual Core answers, provider
effects or physical Watch behavior. Expensive native/provider Golden scenarios
remain explicit runs outside per-PR CI.

## Open Core dependencies

1. Spotify granted-scope evidence: Core #1487, head
   `e724b20431e72e51c8fb654a36fbdeb695f7be78`. Requested scopes are not evidence of
   actual grants. DEFAULT's actual grant remains unknown until the repaired
   callback is installed and the authorized same-11-scope PKCE flow completes.
2. Discover artist playback: Core's artist resolver must choose a real,
   exact-artist-qualified This Is playlist and dispatch one queue-replacing
   context start. Missing/ambiguous/provider-limited/output-required failures
   must not report success or write positive DNA feedback. No actual provider
   playlist/queue acceptance is inferred from Apple request tests.
3. Retained latest contribution: separate Core draft #1486, head
   `7c5af1695bc6363d2e39d9e035b218abedea3768`. Widget4 and explicit retained_latest
   consent are separate from current v3. No silent grant migration or activation.
4. Session start mood/output: installed Core fixes have isolated HA evidence;
   intermittent physical start-mood behavior and actual output/playback need
   native/provider readback. They are not closed by a Settings3-only test.
5. Ordinary Watch pairing can be qualified independently of #1439. The new
   background registry still needs its own signer/receiver/epoch custody,
   independent restore authority and physical/APNs correlation. No credential
   or authority tuple may be invented to complete that proof.

No new Apple build from this batch has been installed, and no live OAuth,
provider playback or physical pairing action was performed by these tests.
