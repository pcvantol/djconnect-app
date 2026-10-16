# Apple scanner preparation — 2026-10-17 continuation

Same assignment and sole Apple writer. This is review preparation, not native
implementation/admission or a claim that A's draft is frozen.

## Reproducible offline inspection

From the repository root:

```sh
python3 docs/feedback/scanner-review-20261017/inspect_examples.py
```

The script reads the locally retained, byte-identical Core capture from fixture
commit `0f3d64028eaa456f643d5fb7633f6741846663ca`, producer runtime
`951da5d0d7943aa672d60b93f5dfe1d32489b93c`. These21 examples were produced by
Core's real isolated HA execution; Apple does not reclassify them as its own
runtime proof. All credentials are upstream nonfunctional replacements. Source
provenance and full-file SHA256 are in `inspection-result.json`.

26 offline assertions check captured identity/auth distinctions, route-only owner
context, original claim/generation/session bindings, explicit share consent,
repeat approval identity, one-time collect, dedicated display scope, owner denial,
HTTP/WSS subject equality, compact presentation labels, renew replay/order and
post-revoke/Session-end rejection. The last assertion checks the30 design strings
have nonempty matching keys in en/nl/de/fr/es. It does not verify translation
quality or actual UI accessibility.

Uncaptured cases remain explicitly open: expired/wrong-code claims, absent external
route, pairing/Profile ABA and source withdrawal during awaits, permission/cancel
and QR races. The22 previously committed scanner design cases are expectations,
not test implementations or evidence for those missing cases. No App Attest/JWE
vector or assertion is synthesized here. No network or provider calls occur.

## Native presentation specification

`native-copy.json` is a design catalog, outside shipped Localizable.strings.
It changes no app screen. Fixed error mapping and final interpolation/VoiceOver
copy must be reconciled with the frozen producer schema before implementation.

| State | Visible content / deliberate action | Allowed next state |
| --- | --- | --- |
| Ready/scanning | `scan_title`, camera explanation at first explicit scan; Cancel | Choose installation, denied, unsupported or invalid QR |
| Installation | `choose_ha`, `choose_help`; actual configured installation, explicit selection | Pure current HA validation; no last-used submit |
| Checking | `checking`; cancel available; original QR deadline remains visible | Destination confirmation or actionable error |
| Confirm | `destination_title`, `destination_help`; actual installation and full canonical host, `send`, Cancel | Prepare only after explicit confirmation |
| Prepare/send | `preparing`/`sending`, bounded busy indication; controls prevent double submit | Address sent, uncertain or failure |
| Address sent | `sent`, `sent_help`; TV continues to existing HA six-digit admission | Close / actual separate B workflow |
| Uncertain | `uncertain`; check TV; no unconditional retry-send button | Frozen status-recovery or fresh QR |
| Cancel after possible send | `cancelled_after_send`; Close | Fresh explicit flow; no remote-recall claim |
| Expired/invalid | `expired`/`invalid_qr`, `scan_again` | New explicitly scanned QR |
| Permission denied | `camera_denied`, `open_settings`, Cancel | System Settings or close; no automatic permission change |
| Unsupported | `unsupported`, Close; preserve existing non-A/Cast entry | Supported paired phone workflow |
| Context/route changed | `context_changed`/`route_changed`; invalidate prior confirmation | Explicit new installation/destination confirmation |
| No external route | `no_external_route`; no local-IP fallback | HA network configuration, then new check |
| Offline/proof unavailable | `offline`/`proof_unavailable`; bounded retry only within original expiry | New challenge or explicit fresh scan, never proof downgrade |
| B unavailable/denied | `no_session`/`b_denied`; A remains just address sent | Actual explicit B action only |
| Actual B success | `display_approved` only from genuine B authority | Dedicated read-only display presentation |

Do not put QR values, canonical destination, key handles or proof bodies into
analytics, pasteboard, deep-link query or debug text. Show the destination in
confirmation only for the active flow; clear ephemeral material on withdrawal.
Do not add the newly configured internal HA-dev IP as an A destination.

## Layout and interaction acceptance before runtime GO

- iPhone: scrollable single-column sheet; original installation/host stays above
  the explicit send control. Long French/German/Spanish text wraps. No truncation
  that hides host suffix, destination distinction or uncertainty.
- iPad: presentation measures the actual sheet width, not the screen width;
  safe-area padding and content width stay stable with keyboard and rotation.
  Confirmation controls remain reachable at large Dynamic Type and in split view.
- Mac: no App Attest A scanner submission. Explain use of supported paired iPhone;
  preserve the existing independent Cast and direct-HA routes.
- VoiceOver order: heading, chosen installation, destination, expiry, description,
  primary action, cancel. Host is readable in full. Announce a state transition
  once; avoid repeated countdown announcements. Move focus to error/actionable
  heading after failure, preserve explicit user selection during harmless refresh.
- Min44pt hit areas, visible focus, supported keyboard cancellation and no color-
  only status. Large type/reduced motion/dark and increased-contrast states require
  actual device review. Draft text and unrelated navigation remain intact.
- Successful A does not auto-start a Session, create share consent, claim display,
  alter local autoplay/voice or replace existing OS permission policy.

## Open disposition

Fresh API/Core heads are unchanged from the earlier review. Contract freeze,
independent security/privacy/UX review, finite key/counter state and real native
crypto interoperability remain open. The owner has been asked the concrete
TRUST-1 question: accept app-attested reported route for address transfer, knowing
another genuine paired scanner holding a copied active QR can win, or require
independent intended-owner proof. No response/acceptance is inferred from elapsed
time or from the prior no-extra-code product choice. All dependent runtime work
stays unstarted while that and the other gates are unresolved.
