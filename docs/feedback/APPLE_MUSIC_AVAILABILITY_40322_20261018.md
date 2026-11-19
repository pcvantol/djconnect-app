# Music availability without HA —40322,18October2026

Owner screenshot: HA unreachable but About shows green Music:Available.
The label used backendAvailable directly, a retained/default backend state; it
was not a separate current Spotify OAuth validation.

About now derives a presentation-only optional status: unknown unless paired,
connected, runtime compatible, not offline and an active HA route exists. An
observed unavailable backend remains unavailable; otherwise an explicit backend
availability observation is required. Unknown shows localized Cannot verify in
secondary grey. Stale/default true no longer produces a green availability claim
while HA is unreachable. No pairing, provider authentication or backend change.

Five translations added. Ordinary signed iOS40322 build including Watch/widgets,
source manifest and localization/diff checks are recorded under
/private/tmp/djc-music-status-40322. No new tests for this bounded presentation
change; no installation, native visual acceptance or Spotify auth proof claimed.
Earlier clean staging reused; older receipts remain historical build-time inputs.
