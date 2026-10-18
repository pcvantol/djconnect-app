# Session status duplication —40321,18October2026

Direct screenshot request: remove the two standalone outage messages and the
refresh button beneath the existing Session recovery/status card. Removed the
active Session model error label and the standalone history-unavailable block.
The timeline error/retry block is also suppressed for the same active/history-
unavailable state. Separate archive and genuine timeline errors keep their
existing recovery UI. The current status card and toolbar refresh remain.

Ordinary signed iOS40321 build, including Watch/widgets, PASS.276input manifest
matches current source; git diff --check PASS. Build log/manifest:
/private/tmp/djc-session-status-40321. Earlier clean stage reused with this UI
overlay. No new tests for the reversible presentation-only removal. No install,
physical UI acceptance, backend recovery or connection fix claimed.
